[CmdletBinding()]
param()

# ── MejoraPC — modules/04-estetica.ps1 ─────────────────────────────
# Ajustes visuales / animaciones. Perfil de 8GB: prioriza rendimiento.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         04 - ESTÉTICA / EFECTOS VISUALES         ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Modo Rendimiento (sin animaciones — recomendado 8GB)" -ForegroundColor White
Write-Host "  [2] Modo Equilibrado (efectos esenciales)" -ForegroundColor White
Write-Host "  [3] Restaurar valores por defecto" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

switch ($opt) {
    '1' {
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 2
        Write-Status "Efectos visuales" "Rendimiento" 'OK'
    }
    '2' {
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 3
        Write-Status "Efectos visuales" "Equilibrado" 'OK'
    }
    '3' {
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 0
        Write-Status "Efectos visuales" "Por defecto" 'OK'
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
