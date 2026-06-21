[CmdletBinding()]
param([switch]$Restore)

# ── MejoraPC — modules/12-workflow-optimizer.ps1 ───────────────────
# Modo único: DESARROLLO. Ejecutar manualmente antes de una sesión.
# -Restore re-habilita Windows Update.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

function Get-FreeRamGB { [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2) }

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         12 - WORKFLOW OPTIMIZER (sesión dev)     ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Restore) {
    Write-Host "  Restaurando Windows Update..." -ForegroundColor DarkGray
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Host "  [OK] Windows Update re-habilitado." -ForegroundColor Green
    Write-Host ""
    if ($Host.Name -eq 'ConsoleHost') { Write-Host "  ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host }
    return
}

$ramBefore = Get-FreeRamGB
Write-Status "RAM libre (antes)" "$ramBefore GB" 'INFO'
Write-Host ""

# ── Limpiar %TEMP% (>7 días) ───────────────────────────────────────
Write-Host "  ── Limpiando %TEMP% (>7 días)" -ForegroundColor DarkCyan
$cut = (Get-Date).AddDays(-7)
$freed = 0
foreach ($tmp in @($env:TEMP, "$env:WINDIR\Temp")) {
    if (Test-Path $tmp) {
        Get-ChildItem $tmp -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cut } | ForEach-Object {
            try { $freed += $_.Length; Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch { }
        }
    }
}
Write-Status "TEMP liberado" (ConvertTo-HumanReadable $freed) 'OK'

# ── Prefetch (si admin) ────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    try {
        Remove-Item "$env:WINDIR\Prefetch\*" -Force -ErrorAction SilentlyContinue
        Write-Status "Prefetch" "limpiado" 'OK'
    } catch { Write-Status "Prefetch" "error" 'WARN' }
} else {
    Write-Status "Prefetch" "requiere admin — omitido" 'WARN'
}

# ── Pausar Windows Update durante la sesión ────────────────────────
Write-Host ""
Write-Host "  ── Windows Update (pausado durante la sesión)" -ForegroundColor DarkCyan
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Status "wuauserv" "deshabilitado (usar -Restore para revertir)" 'OK'
} catch { Write-Status "wuauserv" "error: $_" 'WARN' }

# ── Matar update checkers ──────────────────────────────────────────
Write-Host ""
Write-Host "  ── Matando update checkers" -ForegroundColor DarkCyan
$killed = 0
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match 'CorelUpdateHelper' -or
    ($_.ProcessName -match 'Update' -and $_.ProcessName -notmatch 'svchost|wuauclt')
} | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop; Write-Status $_.ProcessName "terminado" 'OK'; $killed++ } catch { }
}
if ($killed -eq 0) { Write-Status "Update checkers" "ninguno corriendo" 'INFO' }

# ── Verificar pagefile fijo ────────────────────────────────────────
Write-Host ""
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.AutomaticManagedPagefile) {
    Write-Status "Pagefile" "AUTO — ejecutá módulo 3 para fijarlo" 'WARN'
} else {
    Write-Status "Pagefile" "fijo (OK)" 'OK'
}

# ── Activar Ultimate Performance ───────────────────────────────────
try {
    $plans = powercfg /list 2>&1 | Out-String
    $m = [regex]::Match($plans, '([0-9a-f-]{36})\s+\((Ultimate Performance|Rendimiento máximo)')
    if ($m.Success) { powercfg /setactive $m.Groups[1].Value 2>&1 | Out-Null; Write-Status "Power plan" "Ultimate Performance activo" 'OK' }
    else { Write-Status "Power plan" "no existe — ejecutá módulo 3" 'WARN' }
} catch { }

# ── RAM después ────────────────────────────────────────────────────
Start-Sleep -Milliseconds 500
$ramAfter = Get-FreeRamGB
Write-Host ""
Write-Host "  ── RESULTADO ─────────────────────────────────────" -ForegroundColor Cyan
Write-Status "RAM libre (antes)"   "$ramBefore GB" 'INFO'
Write-Status "RAM libre (después)" "$ramAfter GB"  'OK'
$delta = [math]::Round($ramAfter - $ramBefore, 2)
Write-Host "  Δ RAM: $delta GB" -ForegroundColor White
Write-Host ""
Write-Host "  Recordá: al terminar la sesión corré con -Restore para reactivar Windows Update." -ForegroundColor DarkGray
Write-Host ""
if ($Host.Name -eq 'ConsoleHost') { Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray; $null = Read-Host }
