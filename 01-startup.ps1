#Requires -RunAsAdministrator
[CmdletBinding()]
param([object]$AutoApply = $null)

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         01 - GESTIÓN DE STARTUP                 ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$startupItems = Get-CimInstance -ClassName Win32_StartupCommand | Sort-Object Name

if ($startupItems.Count -eq 0) {
    Write-Host "  No se encontraron programas de inicio." -ForegroundColor Yellow
} else {
    Write-Host "  Programas que inician con Windows:" -ForegroundColor Gray
    Write-Host ""
    $i = 1
    foreach ($item in $startupItems) {
        Write-Host "  [$i] $($item.Name.PadRight(30)) — $($item.Location)" -ForegroundColor White
        $i++
    }
}

Write-Host ""
Write-Host "  [!] Gestión avanzada de startup disponible en:" -ForegroundColor DarkGray
Write-Host "      Task Manager → Inicio  o  msconfig → Inicio" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
