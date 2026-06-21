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

# ── 2. Análisis automático VS / Build Tools / .NET ─────────────────
Write-Host "  Analizando dependencias de desarrollo en C:\Github\ ..." -ForegroundColor DarkGray
$scanRoot   = $bloat.blockB.dev_scan.scan_root
$needsNative = $false
$reasons     = [System.Collections.ArrayList]@()
if (Test-Path $scanRoot) {
    $nodeNative = Get-ChildItem -Path $scanRoot -Recurse -Filter '*.node' -ErrorAction SilentlyContinue -Force | Select-Object -First 1
    if ($nodeNative) { $needsNative = $true; $null = $reasons.Add("Módulos nativos Node (.node): $($nodeNative.FullName)") }

    $electron = Get-ChildItem -Path $scanRoot -Recurse -Filter 'package.json' -ErrorAction SilentlyContinue -Force |
        Where-Object { $_.FullName -notmatch 'node_modules' } |
        Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '"electron"' } |
        Select-Object -First 1
    if ($electron) { $needsNative = $true; $null = $reasons.Add("Electron en: $($electron.FullName)") }

    $pyExt = Get-ChildItem -Path $scanRoot -Recurse -Include 'pyproject.toml','setup.py' -ErrorAction SilentlyContinue -Force |
        Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'ext_modules|Extension\(|\[build-system\]' } |
        Select-Object -First 1
    if ($pyExt) { $needsNative = $true; $null = $reasons.Add("Extensión C Python en: $($pyExt.FullName)") }

    $csproj = Get-ChildItem -Path $scanRoot -Recurse -Filter '*.csproj' -ErrorAction SilentlyContinue -Force | Select-Object -First 1
    if ($csproj) { $needsNative = $true; $null = $reasons.Add("Proyecto .NET (.csproj): $($csproj.FullName)") }
} else {
    $null = $reasons.Add("$scanRoot no existe — no se detectaron dependencias")
}

Write-Host ""
Write-Host "  ── RESULTADO DEL ANÁLISIS DE DESARROLLO" -ForegroundColor DarkCyan
if ($needsNative) {
    Write-Host "  [!] Se detectaron dependencias de toolchain nativo:" -ForegroundColor Yellow
    foreach ($r in $reasons) { Write-Host "       - $r" -ForegroundColor Gray }
    Write-Host "  -> Conservar la versión mínima de VS Build Tools necesaria." -ForegroundColor Yellow
} else {
    Write-Host "  [+] No se detectaron dependencias de compilación nativa." -ForegroundColor Green
    Write-Host "  -> Se puede eliminar todo VS Community + Build Tools 2022/2026." -ForegroundColor Green
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
