[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"
Ensure-DataDirectory -ScriptRoot $scriptRoot

# Advertir si no es admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n  [!] No sos administrador. Varios módulos requieren elevación." -ForegroundColor Yellow
    Write-Host "  Abrí PowerShell como Administrador para funcionalidad completa.`n" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}

# Resolver intérprete Python (python o py)
$script:PyCmd = $null
foreach ($c in @('python', 'py')) {
    if (Get-Command $c -ErrorAction SilentlyContinue) { $script:PyCmd = $c; break }
}

function Invoke-Py {
    param([string]$Script, [string[]]$Args = @())
    if (-not $script:PyCmd) {
        Write-Host "`n  [x] Python no está en PATH. Instalalo o agregalo al PATH.`n" -ForegroundColor Red
        Start-Sleep -Seconds 2; return
    }
    & $script:PyCmd (Join-Path $scriptRoot $Script) @Args
}

function Get-PendingRecs {
    $db = "$scriptRoot\data\mejorapc.db"
    if (-not (Test-Path $db) -or -not $script:PyCmd) { return 0 }
    try {
        $py = "import sqlite3,sys`ntry:`n c=sqlite3.connect(r'$db');print(c.execute('select count(*) from smart_recommendations where applied=0').fetchone()[0])`nexcept Exception:`n print(0)"
        $out = $py | & $script:PyCmd - 2>$null
        return [int]($out | Select-Object -Last 1)
    } catch { return 0 }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "   __  __      _                 ____   ____ " -ForegroundColor Cyan
    Write-Host "  |  \/  | ___(_) ___  _ __ __ _|  _ \ / ___|" -ForegroundColor Cyan
    Write-Host "  | |\/| |/ _ \ |/ _ \| '__/ _\` | |_) | |    " -ForegroundColor Cyan
    Write-Host "  | |  | |  __/ | (_) | | | (_| |  __/| |___ " -ForegroundColor Cyan
    Write-Host "  |_|  |_|\___|_|\___/|_|  \__,_|_|    \____|" -ForegroundColor Cyan
    Write-Host "                        perfil definitivo · 8GB" -ForegroundColor DarkGray
    Write-Host ""

    # Estado desde data/status.json
    $statusPath = "$scriptRoot\data\status.json"
    $ramFree = $null
    if (Test-Path $statusPath) {
        try {
            $st = Get-Content $statusPath -Raw | ConvertFrom-Json
            $ramFree = $st.ram_free_gb
            $total   = if ($st.ram_total_gb) { $st.ram_total_gb } else { 8 }
            $score   = if ($st.score) { $st.score } else { '--' }
            $sc      = if ($score -is [int] -and $score -ge 70) { 'Green' } elseif ($score -is [int] -and $score -ge 40) { 'Yellow' } else { 'Red' }
            Write-Host "  RAM: " -NoNewline -ForegroundColor DarkGray
            $rc = if ($ramFree -lt 2.5) { 'Red' } elseif ($ramFree -lt 3.5) { 'Yellow' } else { 'Green' }
            Write-Host "$($ramFree)GB libre / $($total)GB" -NoNewline -ForegroundColor $rc
            Write-Host "  |  Score: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$score/100" -NoNewline -ForegroundColor $sc
            Write-Host "  |  Último scan: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($st.last_scan)" -ForegroundColor White
        } catch { }
    } else {
        Write-Host "  (sin datos — ejecutá [7] Scan hardware)" -ForegroundColor DarkGray
    }
    Write-Host ""

    if ($ramFree -ne $null -and $ramFree -lt 2.5) {
        Write-Host "  ⚠ MEMORIA CRÍTICA — ejecutá [11] Workflow optimizer primero" -ForegroundColor Red
        Write-Host ""
    }

    $pending = Get-PendingRecs
    if ($pending -gt 0) {
        Write-Host "  💡 $pending recomendación(es) pendiente(s) — opción [9]" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Show-Menu {
    Write-Host "  ── OPTIMIZACIÓN ────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   1  Backup" -ForegroundColor White
    Write-Host "   2  Debloat" -ForegroundColor White
    Write-Host "  2r  Reintentar fallidos del último debloat" -ForegroundColor White
    Write-Host "   3  Performance + tweaks" -ForegroundColor White
    Write-Host "   4  Estética" -ForegroundColor White
    Write-Host "   5  Rescate / Restaurar" -ForegroundColor White
    Write-Host "   6  Seguridad" -ForegroundColor White
    Write-Host ""
    Write-Host "  ── MONITOREO ───────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   7  Scan hardware" -ForegroundColor Cyan
    Write-Host "   8  Dashboard" -ForegroundColor Cyan
    Write-Host "   9  Análisis inteligente" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ── DESARROLLO ──────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  10  Python cleanup" -ForegroundColor White
    Write-Host "  11  Workflow optimizer (sesión dev)" -ForegroundColor White
    Write-Host "  12  Instalar monitor background" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "   0  Salir" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Elegí una opción: " -NoNewline -ForegroundColor White
}

function Invoke-Module {
    param([string]$Path)
    $full = Join-Path $scriptRoot $Path
    if (Test-Path $full) { & $full }
    else { Write-Host "`n  Módulo no encontrado: $Path" -ForegroundColor Red; Start-Sleep -Seconds 2 }
}

do {
    Show-Banner
    Show-Menu
    $choice = Read-Host

    switch ($choice) {
        '1'  { Invoke-Module "modules\01-backup.ps1" }
        '2'  { Invoke-Module "modules\02-debloat.ps1" }
        '2r' { & (Join-Path $scriptRoot "modules\02-debloat.ps1") -RetryFailed }
        '3'  { Invoke-Module "modules\03-performance.ps1" }
        '4'  { Invoke-Module "modules\04-estetica.ps1" }
        '5'  { Invoke-Module "modules\05-rescate.ps1" }
        '6'  { Invoke-Module "modules\06-seguridad.ps1" }
        '7'  { Invoke-Py "monitor\scan.py";    Write-Host "  ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host }
        '8'  { Invoke-Py "monitor\report.py";  Write-Host "  ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host }
        '9'  { Invoke-Py "monitor\analyze.py" @('--run'); Write-Host "  ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host }
        '10' { Invoke-Module "modules\10-python-cleanup.ps1" }
        '11' { Invoke-Module "modules\12-workflow-optimizer.ps1" }
        '12' {
            Invoke-Py "monitor\monitor.py" @('--install')
            Invoke-Py "monitor\analyze.py" @('--install')
            Write-Host "  ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host
        }
        '0'  { Write-Host "`n  Hasta luego.`n" -ForegroundColor Cyan; break }
        default { Write-Host "`n  Opción no válida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne '0')
