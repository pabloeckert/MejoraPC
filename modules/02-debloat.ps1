[CmdletBinding()]
param([switch]$Yes)

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

# ── 6. Función de desinstalación multi-método ──────────────────────
function Remove-Package {
    param([string]$Id)
    # a. Remove-AppxPackage (MSIX por nombre)
    try {
        $pkgs = Get-AppxPackage -Name "*$Id*" -ErrorAction SilentlyContinue
        if ($pkgs) {
            foreach ($p in $pkgs) { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
            return 'OK (Appx)'
        }
    } catch { }
    # b. winget uninstall
    try {
        $out = winget uninstall --id $Id --silent --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        if ($out -match 'Successfully uninstalled|desinstalad') { return 'OK (winget)' }
    } catch { }
    # c. Provisioned package (para todos los usuarios)
    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$Id*" }
        if ($prov) {
            foreach ($pp in $prov) { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null }
            return 'OK (Provisioned)'
        }
    } catch { }
    return 'FAIL'
}

# ── 5/7/8. Ejecutar A luego B, loguear ─────────────────────────────
$okCount   = 0
$failCount = 0
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
if ($Host.Name -eq 'ConsoleHost' -and -not $Yes) {
    Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
    $null = Read-Host
}
