#Requires -RunAsAdministrator
[CmdletBinding()]
param([object]$AutoApply = $null)

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         03 - AJUSTES VISUALES                   ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Modo Rendimiento (deshabilita animaciones y efectos)" -ForegroundColor White
Write-Host "  [2] Modo Equilibrado (solo efectos esenciales)" -ForegroundColor White
Write-Host "  [3] Restaurar valores por defecto" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

switch ($opt) {
    '1' {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 2
        SystemPropertiesPerformance | Out-Null
        Write-Host "  [OK] Efectos visuales configurados en Rendimiento" -ForegroundColor Green
    }
    '2' {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 3
        Write-Host "  [OK] Efectos visuales en modo Equilibrado" -ForegroundColor Green
    }
    '3' {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'VisualFXSetting' -Value 0
        Write-Host "  [OK] Efectos visuales restaurados al valor por defecto" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
