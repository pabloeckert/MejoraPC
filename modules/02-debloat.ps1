[CmdletBinding()]
param(
    [switch]$Yes,
    # Lee el último log de debloat y reintenta SOLO los FAIL con el método correcto.
    [switch]$RetryFailed
)

# ── MejoraPC — modules/02-debloat.ps1 ──────────────────────────────
# Debloat de dos capas para el perfil definitivo de Pablo.
#
#   CAPA 1 — POLÍTICA PERMANENTE (HKLM\...\RemoveDefaultMicrosoftStorePackages):
#            Windows elimina la app en cada login y BLOQUEA la reinstalación.
#            Sobrevive updates y reboots. Reemplaza al viejo Remove-AppxPackage
#            que Windows 11 revertía silenciosamente.
#   CAPA 2 — REMOCIÓN INMEDIATA (Appx) para que el cambio se vea en la sesión
#            actual. Si falla, la CAPA 1 lo elimina en el próximo login.
#   CAPA 3 — APPS NO-MSIX (winget / Programs / MSI): UninstallString del
#            registry y winget como último recurso. Mantiene el flujo
#            Bloque A (sin confirmar) / Bloque B (una confirmación tras
#            análisis automático de dependencias de desarrollo).

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$dataFile  = "$scriptRoot\data\universal-bloatware.json"
$logDir    = "$scriptRoot\logs"
$backupDir = "$scriptRoot\backups"
foreach ($d in @($logDir, $backupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null } }

$date       = (Get-Date).ToString('yyyy-MM-dd')
$logFile    = Join-Path $logDir    "debloat-$date.log"
$removedFile= Join-Path $backupDir "debloat-removed-$date.txt"

function Write-Log {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'HH:mm:ss')  $Msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

if (-not (Test-Path $dataFile)) {
    Write-Host "  [x] No se encuentra data/universal-bloatware.json" -ForegroundColor Red
    return
}
$bloat = Get-MergedBloatCatalog -ScriptRoot $scriptRoot

# ═══════════════════════════════════════════════════════════════════
# CAPA 1 + CAPA 2 — política permanente y remoción inmediata (MSIX)
# ═══════════════════════════════════════════════════════════════════

# CAPA 1: escribe la política que Windows lee nativamente. Para cada
# PackageFamilyName crea una subkey con RemovedPackage=1.
function Set-RemovePolicy {
    param([string]$PolicyBase, [string[]]$Pfns)
    try {
        if (-not (Test-Path $PolicyBase)) { New-Item -Path $PolicyBase -Force -ErrorAction Stop | Out-Null }
        # La clave maestra habilita el mecanismo de remoción por política.
        # -ErrorAction Stop en los Set-ItemProperty: sin esto, "acceso denegado"
        # (ej. sin admin) es un error NO terminante y esta función devuelve $true
        # igual, aunque no se haya escrito nada — falso positivo en el mecanismo
        # central del debloat permanente.
        Set-ItemProperty -Path $PolicyBase -Name 'Enabled' -Value 1 -Type DWord -Force -ErrorAction Stop
        foreach ($pfn in $Pfns) {
            $subkey = Join-Path $PolicyBase $pfn
            if (-not (Test-Path $subkey)) { New-Item -Path $subkey -Force -ErrorAction Stop | Out-Null }
            Set-ItemProperty -Path $subkey -Name 'RemovedPackage' -Value 1 -Type DWord -Force -ErrorAction Stop
        }
        return $true
    } catch {
        Write-Log "POLICY FAIL  $PolicyBase  ->  $_"
        return $false
    }
}

# CAPA 2: fuerza la remoción inmediata del Appx para el usuario actual,
# todos los usuarios y la imagen provisionada (evita reinstall a perfiles nuevos).
# El nombre de paquete es la parte previa al primer '_' del PackageFamilyName.
# Devuelve OK (se quitó ahora) | AUSENTE (ya no estaba) | PARCIAL (no se pudo,
# queda para que la política lo elimine en el próximo login).
function Remove-AppxByFamilyName {
    param([string]$Pfn)
    $name    = ($Pfn -split '_')[0]
    $removed = $false
    try {
        foreach ($p in (Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)) {
            Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue; $removed = $true
        }
        foreach ($p in (Get-AppxPackage -AllUsers -Name $name -ErrorAction SilentlyContinue)) {
            Remove-AppxPackage -AllUsers -Package $p.PackageFullName -ErrorAction SilentlyContinue; $removed = $true
        }
    } catch { }
    try {
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.PackageName -like "$name`_*" -or $_.DisplayName -eq $name } |
            ForEach-Object { $null = Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue; $removed = $true }
    } catch { }
    # Verificación real en vez de confiar en el exit code.
    if (Get-AppxPackage -Name $name -ErrorAction SilentlyContinue) { return 'PARCIAL' }
    if ($removed) { return 'OK' }
    return 'AUSENTE'
}

# ═══════════════════════════════════════════════════════════════════
# CAPA 3 — desinstalación de apps NO-MSIX (winget / Programs / MSI)
# ═══════════════════════════════════════════════════════════════════
# Los IDs de winget casi nunca coinciden con cómo el sistema registra la app
# (ProviderName Programs/msi). Mapeamos cada ID a su nombre real de Get-Package
# y desinstalamos por InputObject / UninstallString del registry. winget queda
# como último recurso.
$pkgNameMap = @{
    'BlueStack.BlueStacks'               = 'BlueStacks*'
    'LDPlayer9'                          = 'LDPlayer*'
    'Ollama.Ollama'                      = '*Ollama*'
    'TheBrowserCompany.Arc'              = '*Arc*'
    'Waterfox.Waterfox'                  = 'Waterfox*'
    'KDE.Kdenlive'                       = 'kdenlive*'
    'OBSProject.OBSStudio'               = 'OBS Studio*'
    'SmartSoft.SmartFTP'                 = 'SmartFTP Client*'
    'OpenMedia.4KVideoDownloaderPlus'    = '4K Video Downloader*'
    'Insecure.Nmap'                      = 'Nmap*'
    'Famatech.AdvancedIPScanner'         = 'Advanced IP Scanner*'
    'PuTTY.PuTTY'                        = 'PuTTY*'
    'RevoUninstaller.RevoUninstallerPro' = 'Revo Uninstaller Pro*'
    'WinDirStat.WinDirStat'              = 'WinDirStat*'
    'Stremio'                            = 'Stremio*'
    'Alibaba.Qwen'                       = 'Qwen*'
    'Flywheel.Local'                     = 'Local*'
    'Google.Antigravity'                 = 'Antigravity*'
    'ARP AnyEnhancer'                    = 'AnyEnhancer*'
    'UltraBot'                           = 'UltraBot*'
    'RaiDrive Mount'                     = 'RaiDrive*'
    'WhatsApp Beta'                      = '*WhatsApp*'
    'Microsoft.VCRedist.2012'            = 'Microsoft Visual C++ 2012*'
    'Microsoft.VCRedist.2013'            = 'Microsoft Visual C++ 2013*'
    'BusinessFollowssrl.FileZillaPro'    = 'FileZilla Pro*'
    'Npcap'                              = 'Npcap*'
    'OpenAI.Codex'                       = 'Codex*'
}

# Devuelve el patrón de nombre para Get-Package: del mapa o derivado del ID.
function Resolve-PackageName {
    param([string]$Id)
    if ($pkgNameMap.ContainsKey($Id)) { return $pkgNameMap[$Id] }
    $name = $Id
    if ($name -match '\\') { $name = ($name -split '\\')[-1] }              # ARP\..\X → X
    if ($name -match '^[^\s\\]+\.[^\s\\]+$') { $name = ($name -split '\.')[-1] }  # Pub.Pkg → Pkg
    return "*$name*"
}

# ¿Es realmente un MSIX/Appx instalado? (Store apps, Microsoft.*).
function Test-IsMsix {
    param([string]$Id)
    if ($Id -match '^MSIX\\') { return $true }
    if (($Id -like 'Microsoft.*' -or $Id -like 'MicrosoftCorporationII.*' -or $Id -like 'MicrosoftWindows.*') -and
        (Get-AppxPackage -Name "*$Id*" -ErrorAction SilentlyContinue)) { return $true }
    return $false
}

# ¿El paquete está REALMENTE instalado? La mayoría de los FAIL del log son apps
# que ya no están: verificamos antes de intentar desinstalar para no ensuciar el
# log. Devuelve $true si CUALQUIER método lo encuentra (corta apenas hay un hit).
function Test-PackageInstalled {
    param([string]$Id)

    # MSIX/Appx (Store).
    if (Test-IsMsix -Id $Id) {
        $name = $Id
        if ($name -match '^MSIX\\') { $name = ($name -split '\\')[-1] }
        if (Get-AppxPackage -Name "*$name*" -ErrorAction SilentlyContinue) { return $true }
        if (Get-AppxPackage -AllUsers -Name "*$name*" -ErrorAction SilentlyContinue) { return $true }
        return $false
    }

    $pattern = Resolve-PackageName -Id $Id

    # Programs / MSI (Get-Package).
    if (Get-Package -Name $pattern -ErrorAction SilentlyContinue) { return $true }

    # Registry: DisplayName en las claves Uninstall.
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $keys) {
        if (Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern }) { return $true }
    }

    # winget por --id exacto: exit 0 = instalado (último porque es el más lento).
    winget list --id $Id --exact 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }

    return $false
}

# Desinstala vía winget eligiendo --id (exacto) o --name (nombre visible/ARP).
function Invoke-WingetUninstall {
    param([string]$Id, [switch]$ByName)
    $wargs = @('uninstall','--silent','--accept-source-agreements','--disable-interactivity','--force')
    if ($ByName) {
        $name = $Id
        if ($name -match '^ARP\\') { $name = ($name -split '\\')[-1] }  # último segmento = nombre real
        $wargs += @('--name', $name)
    } else {
        $wargs += @('--id', $Id, '--exact')
    }
    try {
        $out  = & winget @wargs 2>&1 | Out-String
        $code = $LASTEXITCODE
    } catch { return 'FAIL' }
    if ($code -eq 0 -or $out -match 'Successfully uninstalled|desinstalad')  { return 'OK (winget)' }
    if ($out -match 'No installed package found|No se encontró|0x8a15002b')  { return 'OK (no instalado)' }
    return 'FAIL'
}

# Quita un MSIX/Appx para el usuario actual, todos los usuarios y provisioned.
function Remove-AppxById {
    param([string]$Id)
    $name = $Id
    if ($name -match '^MSIX\\') { $name = ($name -split '\\')[-1] }
    $done = $false
    try {
        foreach ($p in (Get-AppxPackage -Name "*$name*" -ErrorAction SilentlyContinue)) {
            Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue; $done = $true
        }
        foreach ($p in (Get-AppxPackage -AllUsers -Name "*$name*" -ErrorAction SilentlyContinue)) {
            Remove-AppxPackage -AllUsers -Package $p.PackageFullName -ErrorAction SilentlyContinue; $done = $true
        }
    } catch { }
    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$name*" }
        foreach ($pp in $prov) { $null = Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction SilentlyContinue; $done = $true }
    } catch { }
    if ($done) { return 'OK (Appx)' }
    return (Invoke-WingetUninstall -Id $Id)   # no era MSIX real → último intento con winget
}

# Busca la entrada de Uninstall en el registry por DisplayName y la ejecuta en silencio.
# Devuelve $true SOLO si tras correr ya no queda ninguna entrada que matchee el patrón
# (no confiamos en el exit code: muchos uninstallers mienten o forkean).
function Invoke-RegistryUninstall {
    param([string]$Pattern)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $cands = @(foreach ($k in $keys) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $Pattern -and ($_.UninstallString -or $_.QuietUninstallString) }
    })
    if (-not $cands) { return $false }

    # Preferir el desinstalador del bundle: 1) QuietUninstallString, 2) exe que no sea msiexec
    # (en VCRedist el wrapper vcredist_x64.exe /uninstall borra TODOS los sub-componentes),
    # 3) lo que haya. Así evitamos quitar un solo runtime y dejar el resto.
    $entry =  $cands | Where-Object QuietUninstallString | Select-Object -First 1
    if (-not $entry) { $entry = $cands | Where-Object { $_.UninstallString -notmatch '(?i)^\s*"?\s*msiexec' } | Select-Object -First 1 }
    if (-not $entry) { $entry = $cands[0] }

    $quiet = [bool]$entry.QuietUninstallString
    $cmd   = if ($quiet) { $entry.QuietUninstallString } else { $entry.UninstallString }
    try {
        # msiexec real: el comando ES msiexec y el GUID va tras /X o /I (no un GUID suelto en un path).
        if ($cmd -match '(?i)msiexec.*?/[xi]\s*(\{[0-9A-Fa-f-]+\})') {
            Start-Process 'msiexec.exe' -ArgumentList "/x $($matches[1]) /quiet /norestart" -Wait -ErrorAction Stop | Out-Null
        } else {
            # exe (entre comillas o no) + argumentos.
            if     ($cmd -match '^\s*"([^"]+)"\s*(.*)$')   { $exe = $matches[1]; $argStr = $matches[2].Trim() }
            elseif ($cmd -match '^\s*(.+?\.exe)\s*(.*)$')  { $exe = $matches[1]; $argStr = $matches[2].Trim() }
            else                                           { $exe = $cmd;        $argStr = '' }
            # Sin QuietUninstallString, agregamos switches silenciosos comunes (NSIS/Inno/vcredist/etc.).
            if (-not $quiet) {
                foreach ($flag in '/S', '/silent', '/quiet') {
                    if ($argStr -notmatch [regex]::Escape($flag)) { $argStr = "$argStr $flag".Trim() }
                }
            }
            if ([string]::IsNullOrWhiteSpace($argStr)) {
                Start-Process -FilePath $exe -Wait -ErrorAction Stop | Out-Null
            } else {
                Start-Process -FilePath $exe -ArgumentList $argStr -Wait -ErrorAction Stop | Out-Null
            }
        }
    } catch { return $false }

    # Verificación real: ya no debe quedar ninguna entrada que matchee el patrón.
    Start-Sleep -Milliseconds 500
    $remain = @(foreach ($k in $keys) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object DisplayName -like $Pattern
    })
    return ($remain.Count -eq 0)
}

# Dispatcher: Get-Package como fuente de verdad; winget como fallback.
function Remove-Package {
    param([string]$Id)

    # Verificación previa: si ya no está instalado, no intentamos nada y lo
    # marcamos SKIP (no instalado) — no es un fallo real.
    if (-not (Test-PackageInstalled -Id $Id)) { return 'SKIP (no instalado)' }

    # MSIX/Store primero — no aparece en Get-Package como desinstalable normal.
    if (Test-IsMsix -Id $Id) { return (Remove-AppxById -Id $Id) }

    $pattern = Resolve-PackageName -Id $Id
    $pkg     = Get-Package -Name $pattern -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($pkg) {
        try {
            if ($pkg.ProviderName -eq 'msi') {
                Uninstall-Package -InputObject $pkg -Force -AdditionalArguments '/quiet /norestart' -ErrorAction Stop | Out-Null
                if (-not (Get-Package -Name $pattern -ErrorAction SilentlyContinue)) { return 'OK (msi)' }
            } else {
                Uninstall-Package -InputObject $pkg -Force -ErrorAction Stop | Out-Null
                if (-not (Get-Package -Name $pattern -ErrorAction SilentlyContinue)) { return 'OK (Programs)' }
            }
        } catch { }
    }

    # Get-Package no pudo (o no lo lista): UninstallString del registry.
    if (Invoke-RegistryUninstall -Pattern $pattern) { return 'OK (registry)' }

    # Último recurso: winget por --id (Publisher.Package) o --name (ARP/espacios).
    $byName = ($Id -match '\\') -or ($Id -notmatch '^[^\s\\]+\.[^\s\\]+$')
    return (Invoke-WingetUninstall -Id $Id -ByName:$byName)
}

# Lee el último debloat-*.log y devuelve los IDs marcados FAIL en su última corrida.
function Get-LastFailedPackages {
    $log = Get-ChildItem -Path $logDir -Filter 'debloat-*.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $log) { return @() }
    $lines  = @(Get-Content $log.FullName)
    $starts = @($lines | Select-String -SimpleMatch '=== INICIO DEBLOAT')
    $from   = if ($starts) { $starts[-1].LineNumber - 1 } else { 0 }
    $block  = $lines[$from..($lines.Count - 1)]
    $fails  = foreach ($l in $block) { if ($l -match '\bFAIL\s+(.+?)\s*$') { $matches[1].Trim() } }
    @($fails | Where-Object { $_ } | Select-Object -Unique)
}

# Reintenta una lista de IDs con el método correcto; loguea y devuelve conteos.
function Invoke-RetryList {
    param([string[]]$Ids)
    $okR = 0; $failR = 0; $skipR = 0
    Write-Log "=== REINTENTO FAILs ($($Ids.Count)) ==="
    foreach ($id in $Ids) {
        Write-Host "  Reintentando $id ... " -NoNewline -ForegroundColor Gray
        $res = Remove-Package -Id $id
        if ($res -like 'OK*') {
            Write-Host $res -ForegroundColor Green; Write-Log "RETRY OK    $id  ->  $res"
            Add-Content -Path $removedFile -Value $id -Encoding UTF8; $okR++
        } elseif ($res -like 'SKIP*') {
            Write-Host $res -ForegroundColor DarkGray; Write-Log "RETRY SKIP  $id  ->  $res"; $skipR++
        } else {
            Write-Host $res -ForegroundColor Red; Write-Log "RETRY FAIL  $id"; $failR++
        }
    }
    Write-Log "=== FIN REINTENTO: OK=$okR SKIP=$skipR FAIL=$failR ==="
    Write-Host ""
    Write-Host "  ── RESUMEN REINTENTO ─────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Recuperados OK : $okR" -ForegroundColor Green
    Write-Host "  No instalados  : $skipR" -ForegroundColor DarkGray
    Write-Host "  Siguen fallando: $failR" -ForegroundColor Red
    Write-Host ""
}

# ── Modo reintento standalone: lee el log y reprocesa solo los FAIL ─
if ($RetryFailed) {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║     02 - REINTENTO DE FALLIDOS (último debloat)   ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    $failed = Get-LastFailedPackages
    if (-not $failed -or $failed.Count -eq 0) {
        Write-Host "  No hay paquetes FAIL en el último log de debloat." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "  Reintentando $($failed.Count) paquete(s) con el método correcto:" -ForegroundColor Yellow
        Write-Host ""
        Invoke-RetryList -Ids $failed
    }
    if ($Host.Name -eq 'ConsoleHost' -and -not $Yes) {
        Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host
    }
    return
}

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         02 - DEBLOAT (perfil definitivo)         ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  [!] No sos administrador: la política (CAPA 1) y varias remociones fallarán." -ForegroundColor Yellow
    Write-Host "      Cerrá y abrí PowerShell como Administrador para el debloat completo." -ForegroundColor DarkGray
    Write-Host ""
}

"# Debloat $date — paquetes eliminados" | Set-Content -Path $removedFile -Encoding UTF8
Write-Log "=== INICIO DEBLOAT ==="

# ═══════════════════════════════════════════════════════════════════
# CAPA 1 — POLÍTICA PERMANENTE (sin confirmación: MS bloat de bajo riesgo)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  CAPA 1 — política permanente (sobrevive updates y reboots)" -ForegroundColor Yellow
Write-Host ""
$policyBase = $bloat.policy_msix.policy_base
$pfns       = @($bloat.policy_msix.package_family_names)
if (Set-RemovePolicy -PolicyBase $policyBase -Pfns $pfns) {
    Write-Status "RemoveDefaultMicrosoftStorePackages" "$($pfns.Count) paquetes en la política" 'OK'
    Write-Log "POLICY OK  $($pfns.Count) PFNs en $policyBase"
} else {
    Write-Status "RemoveDefaultMicrosoftStorePackages" "no se pudo escribir (requiere admin)" 'ERROR'
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
# CAPA 2 — REMOCIÓN INMEDIATA (Appx) de los mismos PackageFamilyNames
# ═══════════════════════════════════════════════════════════════════
Write-Host "  CAPA 2 — remoción inmediata para la sesión actual" -ForegroundColor Yellow
Write-Host ""
$capa2Ok = 0; $capa2Ausente = 0; $capa2Parcial = 0
foreach ($pfn in $pfns) {
    $r = Remove-AppxByFamilyName -Pfn $pfn
    switch ($r) {
        'OK'      { Write-Status $pfn "eliminado ahora" 'OK';   Write-Log "APPX OK       $pfn"; $capa2Ok++ }
        'AUSENTE' { Write-Status $pfn "ya no estaba — la política lo bloquea" 'INFO'; Write-Log "APPX AUSENTE  $pfn"; $capa2Ausente++ }
        'PARCIAL' { Write-Status $pfn "no removible ahora — se elimina en el próximo login" 'WARN'; Write-Log "APPX PARCIAL  $pfn"; $capa2Parcial++ }
    }
}
Write-Host ""
Write-Host "  CAPA 2: $capa2Ok eliminados ahora · $capa2Ausente ya ausentes · $capa2Parcial pendientes de login" -ForegroundColor DarkGray
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
# CAPA 3 — apps NO-MSIX. Bloque A sin confirmar, Bloque B con una confirmación.
# ═══════════════════════════════════════════════════════════════════
Write-Host "  CAPA 3 — apps no-MSIX (winget / Programs / MSI)" -ForegroundColor Yellow
Write-Host ""

# ── Bloque A agrupado ──────────────────────────────────────────────
Write-Host "  BLOQUE A — se elimina sin confirmación:" -ForegroundColor Yellow
Write-Host ""
$blockAList = [System.Collections.ArrayList]@()
foreach ($prop in $bloat.blockA.groups.PSObject.Properties) {
    $title = ($prop.Name -replace '_', ' ').ToUpper()
    Write-Host "  ── $title" -ForegroundColor DarkCyan
    foreach ($id in $prop.Value) {
        Write-Host "       $id" -ForegroundColor Gray
        $null = $blockAList.Add($id)
    }
}
Write-Host ""
Write-Host "  Total Bloque A: $($blockAList.Count) paquetes" -ForegroundColor White
Write-Host ""

# ── Análisis automático VS / Build Tools / .NET (rápido, con timeout) ──
Write-Host "  Analizando dependencias de desarrollo en C:\Github\ ..." -ForegroundColor DarkGray
$scanRoot    = $bloat.blockB.dev_scan.scan_root
$needsNative = $false
$reasons     = [System.Collections.ArrayList]@()
$timedOut    = $false

# Todo el análisis corre en un job con corte duro a los 10s: aunque un
# Get-ChildItem se cuelgue dentro, el Wait-Job -Timeout garantiza continuar.
$scanBlock = {
    param($root)
    $found = @()
    if (Test-Path $root) {
        foreach ($proj in (Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue)) {
            # package.json (raíz del proyecto) — "electron" → conservar Build Tools
            $pkg = Join-Path $proj.FullName 'package.json'
            if (Test-Path $pkg) {
                if ((Get-Content $pkg -Raw -ErrorAction SilentlyContinue) -match '"electron"') {
                    $found += "Electron (package.json) en $($proj.Name)"
                }
            }
            # requirements.txt (raíz) — "pythonnet"/"clr" → conservar .NET
            $req = Join-Path $proj.FullName 'requirements.txt'
            if (Test-Path $req) {
                if ((Get-Content $req -Raw -ErrorAction SilentlyContinue) -match 'pythonnet|clr') {
                    $found += "pythonnet/.NET (requirements.txt) en $($proj.Name)"
                }
            }
            # pyproject.toml (raíz) — "pythonnet"/"clr" → conservar .NET
            $pyproj = Join-Path $proj.FullName 'pyproject.toml'
            if (Test-Path $pyproj) {
                if ((Get-Content $pyproj -Raw -ErrorAction SilentlyContinue) -match 'pythonnet|clr') {
                    $found += "pythonnet/.NET (pyproject.toml) en $($proj.Name)"
                }
            }
            # node_modules — extensión .node → conservar Build Tools
            $nm = Join-Path $proj.FullName 'node_modules'
            if (Test-Path $nm) {
                $nodeNative = Get-ChildItem -Path $nm -Recurse -Filter '*.node' -ErrorAction SilentlyContinue -Force | Select-Object -First 1
                if ($nodeNative) { $found += "Módulos nativos Node (.node) en $($proj.Name)" }
            }
        }
    }
    ,$found
}

$job = Start-Job -ScriptBlock $scanBlock -ArgumentList $scanRoot
if (Wait-Job $job -Timeout 25) {
    foreach ($r in (Receive-Job $job)) { $needsNative = $true; $null = $reasons.Add($r) }
} else {
    $timedOut = $true
    Stop-Job $job -ErrorAction SilentlyContinue
}
Remove-Job $job -Force -ErrorAction SilentlyContinue

# ── Resultado en 1 línea ───────────────────────────────────────────
Write-Host ""
if ($needsNative) {
    Write-Host ("  Dependencias detectadas: " + ($reasons -join '; ')) -ForegroundColor Yellow
} elseif ($timedOut) {
    Write-Host "  Sin dependencias dev nativas (timeout 25s — se asume sin dependencias)" -ForegroundColor Green
} else {
    Write-Host "  Sin dependencias dev nativas" -ForegroundColor Green
}
Write-Host ""

# ── Bloque B ───────────────────────────────────────────────────────
Write-Host "  BLOQUE B — riesgo medio (solo si confirmás):" -ForegroundColor Yellow
$blockBList = [System.Collections.ArrayList]@()
if (-not $needsNative) {
    foreach ($vs in $bloat.blockB.candidates.visual_studio) {
        Write-Host "       $vs" -ForegroundColor Gray; $null = $blockBList.Add($vs)
    }
}
foreach ($vc in $bloat.blockB.candidates.vcredist.remove) {
    Write-Host "       $vc" -ForegroundColor Gray; $null = $blockBList.Add($vc)
}
Write-Host "       (VCRedist 2015+ x64/x86 SE CONSERVAN siempre)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Total Bloque B: $($blockBList.Count) paquetes" -ForegroundColor White
Write-Host ""

# ── Ejecutar Bloque A SIEMPRE (sin confirmar, según perfil definitivo) ─
$okCount   = 0
$failCount = 0
$skipCount = 0
$failedIds = [System.Collections.ArrayList]@()

function Invoke-RemovalList {
    param([System.Collections.ArrayList]$Ids)
    foreach ($id in $Ids) {
        Write-Host "  Quitando $id ... " -NoNewline -ForegroundColor Gray
        $res = Remove-Package -Id $id
        if ($res -like 'OK*') {
            Write-Host $res -ForegroundColor Green
            Write-Log "OK    $id  ->  $res"
            Add-Content -Path $removedFile -Value $id -Encoding UTF8
            $script:okCount++
        } elseif ($res -like 'SKIP*') {
            Write-Host $res -ForegroundColor DarkGray
            Write-Log "SKIP  $id  ->  $res"
            $script:skipCount++
        } else {
            Write-Host $res -ForegroundColor Red
            Write-Log "FAIL  $id"
            $null = $script:failedIds.Add($id)
            $script:failCount++
        }
    }
}

Write-Host ""
Write-Host "  Ejecutando Bloque A ..." -ForegroundColor DarkCyan
Invoke-RemovalList -Ids $blockAList

# ── Bloque B: una sola confirmación global ─────────────────────────
$doBlockB = $Yes
if (-not $Yes -and $blockBList.Count -gt 0) {
    Write-Host ""
    Write-Host "  ¿Aplicar también Bloque B ($($blockBList.Count) paquetes de riesgo medio)? [Y/N]: " -NoNewline -ForegroundColor White
    $doBlockB = (Read-Host) -match '^[Yy]'
}
if ($doBlockB -and $blockBList.Count -gt 0) {
    Write-Host ""
    Write-Host "  Ejecutando Bloque B ..." -ForegroundColor DarkCyan
    Invoke-RemovalList -Ids $blockBList
} elseif ($blockBList.Count -gt 0) {
    Write-Host "`n  Bloque B omitido." -ForegroundColor Yellow
}

Write-Log "=== FIN: OK=$okCount SKIP=$skipCount FAIL=$failCount (CAPA2 ok=$capa2Ok ausente=$capa2Ausente parcial=$capa2Parcial) ==="

# ── Resumen ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ── RESUMEN ───────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  CAPA 1 política  : $($pfns.Count) PackageFamilyNames bloqueados (permanente)" -ForegroundColor Green
Write-Host "  CAPA 2 inmediata : $capa2Ok eliminados · $capa2Parcial al próximo login" -ForegroundColor Green
Write-Host "  CAPA 3 no-MSIX   :" -ForegroundColor White
Write-Host "    Eliminados OK  : $okCount" -ForegroundColor Green
Write-Host "    No instalados  : $skipCount  (ya no estaban — normal)" -ForegroundColor DarkGray
Write-Host "    Fallidos reales: $failCount  (estaban pero no se pudieron eliminar)" -ForegroundColor Red
Write-Host "  Log              : $logFile" -ForegroundColor DarkGray
Write-Host "  Backup IDs       : $removedFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Verificá el resultado real en disco con la opción [13] del menú." -ForegroundColor DarkGray
Write-Host ""

# ── Ofrecer reintento inmediato de los FAIL de esta corrida ────────
if ($failedIds.Count -gt 0) {
    $doRetry = $Yes
    if (-not $Yes) {
        Write-Host "  ¿Reintentar los $($failedIds.Count) fallidos con el método correcto ahora? [Y/N]: " -NoNewline -ForegroundColor White
        $doRetry = (Read-Host) -match '^[Yy]'
    }
    if ($doRetry) {
        Write-Host ""
        Invoke-RetryList -Ids @($failedIds)
    }
}

if ($Host.Name -eq 'ConsoleHost' -and -not $Yes) {
    Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
    $null = Read-Host
}
