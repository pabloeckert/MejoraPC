[CmdletBinding()]
param(
    [switch]$Yes,
    # Lee el último log de debloat y reintenta SOLO los FAIL con el método correcto.
    [switch]$RetryFailed
)

# ── MejoraPC — modules/02-debloat.ps1 ──────────────────────────────
# Un solo perfil de debloat para el perfil definitivo de Pablo.
# Bloque A: sin confirmación. Bloque B: una sola confirmación global
# tras análisis automático de dependencias de desarrollo.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$dataFile  = "$scriptRoot\data\bloatware.json"
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
    Write-Host "  [x] No se encuentra data/bloatware.json" -ForegroundColor Red
    return
}
$bloat = Get-Content $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json

# ── Desinstalación: Get-Package (PackageManagement) como fuente de verdad ──
# Los IDs de winget casi nunca coinciden con cómo el sistema registra la app
# (ProviderName Programs/msi). Mapeamos cada ID a su nombre real de Get-Package
# y desinstalamos por InputObject / UninstallString del registry. winget queda
# como último recurso; MSIX (Store) sigue por Remove-AppxPackage.
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
function Invoke-RegistryUninstall {
    param([string]$Pattern)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entry = $null
    foreach ($k in $keys) {
        $entry = Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $Pattern -and ($_.UninstallString -or $_.QuietUninstallString) } |
            Select-Object -First 1
        if ($entry) { break }
    }
    if (-not $entry) { return $false }

    $quiet = [bool]$entry.QuietUninstallString
    $cmd   = if ($quiet) { $entry.QuietUninstallString } else { $entry.UninstallString }
    try {
        # msiexec → desinstalación por product code, siempre silenciosa.
        if ($cmd -match 'msiexec' -and $cmd -match '(\{[0-9A-Fa-f\-]+\})') {
            $p = Start-Process 'msiexec.exe' -ArgumentList "/x $($matches[1]) /quiet /norestart" -Wait -PassThru -ErrorAction Stop
            return ($p.ExitCode -in 0, 3010, 1605)
        }
        # exe (entre comillas o no) + argumentos.
        if     ($cmd -match '^\s*"([^"]+)"\s*(.*)$')   { $exe = $matches[1]; $argStr = $matches[2].Trim() }
        elseif ($cmd -match '^\s*(.+?\.exe)\s*(.*)$')  { $exe = $matches[1]; $argStr = $matches[2].Trim() }
        else                                           { $exe = $cmd;        $argStr = '' }
        # Sin QuietUninstallString, agregamos switches silenciosos comunes (NSIS/Inno/etc.).
        if (-not $quiet) {
            foreach ($flag in '/S', '/silent', '/quiet') {
                if ($argStr -notmatch [regex]::Escape($flag)) { $argStr = "$argStr $flag".Trim() }
            }
        }
        $p = if ([string]::IsNullOrWhiteSpace($argStr)) {
            Start-Process -FilePath $exe -Wait -PassThru -ErrorAction Stop
        } else {
            Start-Process -FilePath $exe -ArgumentList $argStr -Wait -PassThru -ErrorAction Stop
        }
        return ($p.ExitCode -in 0, 3010)
    } catch { return $false }
}

# Dispatcher: Get-Package como fuente de verdad; winget como fallback.
function Remove-Package {
    param([string]$Id)

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
    $okR = 0; $failR = 0
    Write-Log "=== REINTENTO FAILs ($($Ids.Count)) ==="
    foreach ($id in $Ids) {
        Write-Host "  Reintentando $id ... " -NoNewline -ForegroundColor Gray
        $res = Remove-Package -Id $id
        if ($res -like 'OK*') {
            Write-Host $res -ForegroundColor Green; Write-Log "RETRY OK    $id  ->  $res"
            Add-Content -Path $removedFile -Value $id -Encoding UTF8; $okR++
        } else {
            Write-Host $res -ForegroundColor DarkYellow; Write-Log "RETRY FAIL  $id"; $failR++
        }
    }
    Write-Log "=== FIN REINTENTO: OK=$okR FAIL=$failR ==="
    Write-Host ""
    Write-Host "  ── RESUMEN REINTENTO ─────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Recuperados OK : $okR" -ForegroundColor Green
    Write-Host "  Siguen fallando: $failR" -ForegroundColor Yellow
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

# ── 1. Mostrar Bloque A agrupado ───────────────────────────────────
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

# ── 2. Análisis automático VS / Build Tools / .NET (rápido, con timeout) ──
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
if (Wait-Job $job -Timeout 10) {
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
    Write-Host "  Sin dependencias dev nativas (timeout 10s — se asume sin dependencias)" -ForegroundColor Green
} else {
    Write-Host "  Sin dependencias dev nativas" -ForegroundColor Green
}
Write-Host ""

# ── 3. Mostrar Bloque B ────────────────────────────────────────────
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

# ── 4. Una confirmación global ─────────────────────────────────────
if (-not $Yes) {
    Write-Host "  ¿Aplicar debloat completo (Bloque A + Bloque B)? [Y/N]: " -NoNewline -ForegroundColor White
    $ans = Read-Host
    if ($ans -notmatch '^[Yy]') {
        Write-Host "`n  Cancelado. No se eliminó nada.`n" -ForegroundColor Yellow
        return
    }
}

# ── 5/7/8. Ejecutar A luego B, loguear ─────────────────────────────
# (las funciones de desinstalación se definen arriba, antes del menú)
$okCount   = 0
$failCount = 0
$failedIds = [System.Collections.ArrayList]@()
"# Debloat $date — paquetes eliminados" | Set-Content -Path $removedFile -Encoding UTF8
Write-Log "=== INICIO DEBLOAT (needsNative=$needsNative) ==="

$all = @($blockAList) + @($blockBList)
Write-Host ""
foreach ($id in $all) {
    Write-Host "  Quitando $id ... " -NoNewline -ForegroundColor Gray
    $res = Remove-Package -Id $id
    if ($res -like 'OK*') {
        Write-Host $res -ForegroundColor Green
        Write-Log "OK    $id  ->  $res"
        Add-Content -Path $removedFile -Value $id -Encoding UTF8
        $okCount++
    } else {
        Write-Host $res -ForegroundColor DarkYellow
        Write-Log "FAIL  $id"
        $null = $failedIds.Add($id)
        $failCount++
    }
}
Write-Log "=== FIN: OK=$okCount FAIL=$failCount ==="

# ── 9. Resumen ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ── RESUMEN ───────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Eliminados OK : $okCount" -ForegroundColor Green
Write-Host "  Fallidos      : $failCount" -ForegroundColor Yellow
Write-Host "  Log           : $logFile" -ForegroundColor DarkGray
Write-Host "  Backup IDs    : $removedFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  RAM/espacio estimado liberado: depende de los paquetes activos." -ForegroundColor DarkGray
Write-Host ""

# ── 10. Ofrecer reintento inmediato de los FAIL de esta corrida ─────
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
