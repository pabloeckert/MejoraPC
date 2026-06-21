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

# ── Desinstalación: detectar el método correcto ANTES de intentar ──
# La mayoría de los IDs son apps winget (no MSIX/Appx). Aplicar
# Remove-AppxPackage a ciegas falla; primero clasificamos el ID.
function Get-UninstallMethod {
    param([string]$Id)
    if ($Id -match '^MSIX\\')  { return 'appx' }         # MSIX\... ruta completa de paquete
    if ($Id -match '^ARP\\')   { return 'winget-name' }  # ARP\User\X64\Opera GX → por nombre
    # Microsoft.* / MicrosoftCorporationII.* SOLO si hay un Appx instalado real.
    if (($Id -like 'Microsoft.*' -or $Id -like 'MicrosoftCorporationII.*' -or $Id -like 'MicrosoftWindows.*') -and
        (Get-AppxPackage -Name "*$Id*" -ErrorAction SilentlyContinue)) {
        return 'appx'
    }
    if ($Id -match '^[^\s\\]+\.[^\s\\]+$') { return 'winget-id' }  # Publisher.Package (Ollama.Ollama)
    return 'winget-name'                                          # nombre visible con espacios
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

# Dispatcher: clasifica el ID y delega al ejecutor correcto.
function Remove-Package {
    param([string]$Id)
    switch (Get-UninstallMethod -Id $Id) {
        'appx'        { return (Remove-AppxById -Id $Id) }
        'winget-id'   { return (Invoke-WingetUninstall -Id $Id) }
        'winget-name' { return (Invoke-WingetUninstall -Id $Id -ByName) }
        default       { return (Invoke-WingetUninstall -Id $Id -ByName) }
    }
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
