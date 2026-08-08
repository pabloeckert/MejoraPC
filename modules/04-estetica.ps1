[CmdletBinding()]
param([switch]$Auto)

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

$opt = '1'
if (-not $Auto) {
    Write-Host "  [1] Modo Rendimiento (sin animaciones — recomendado 8GB)" -ForegroundColor White
    Write-Host "  [2] Modo Equilibrado (efectos esenciales)" -ForegroundColor White
    Write-Host "  [3] Restaurar valores por defecto" -ForegroundColor White
    Write-Host "  [0] Volver" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Opción: " -NoNewline
    $opt = Read-Host
} else {
    Write-Host "  Modo automático: aplicando Rendimiento (recomendado 8GB)" -ForegroundColor DarkGray
}

$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'

function Set-VisualFX {
    param([int]$Value, [string]$Label)
    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value $Value -Type DWord -ErrorAction Stop
        Write-Status "Efectos visuales" $Label 'OK'
    } catch { Write-Status "Efectos visuales" "error: $_" 'ERROR' }
}

switch ($opt) {
    '1' { Set-VisualFX -Value 2 -Label 'Rendimiento' }
    '2' { Set-VisualFX -Value 3 -Label 'Equilibrado' }
    '3' { Set-VisualFX -Value 0 -Label 'Por defecto' }
}

Write-Host ""
Wait-KeyIfInteractive -Auto:$Auto
