[CmdletBinding()]
param()

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         06 - MODO GAMING                        ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Activar modo juego de Windows" -ForegroundColor White
Write-Host "  [2] Activar plan de energía Alto Rendimiento" -ForegroundColor White
Write-Host "  [3] Deshabilitar Game DVR (grabación en segundo plano)" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

switch ($opt) {
    '1' {
        $gamePath = 'HKCU:\Software\Microsoft\GameBar'
        if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
        Set-ItemProperty -Path $gamePath -Name 'AllowAutoGameMode' -Value 1 -Type DWord
        Set-ItemProperty -Path $gamePath -Name 'AutoGameModeEnabled' -Value 1 -Type DWord
        Write-Host "  [OK] Modo juego activado" -ForegroundColor Green
    }
    '2' {
        $guid = powercfg -list | Select-String 'Alto rendimiento|High performance' | ForEach-Object { ($_ -split '\s+')[3] } | Select-Object -First 1
        if (-not $guid) { $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
        powercfg -setactive $guid
        Write-Host "  [OK] Plan de energía: Alto Rendimiento activado" -ForegroundColor Green
    }
    '3' {
        $dvrPath = 'HKCU:\System\GameConfigStore'
        if (-not (Test-Path $dvrPath)) { New-Item -Path $dvrPath -Force | Out-Null }
        Set-ItemProperty -Path $dvrPath -Name 'GameDVR_Enabled' -Value 0 -Type DWord
        $dvrPath2 = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
        if (-not (Test-Path $dvrPath2)) { New-Item -Path $dvrPath2 -Force | Out-Null }
        Set-ItemProperty -Path $dvrPath2 -Name 'AllowGameDVR' -Value 0 -Type DWord
        Write-Host "  [OK] Game DVR deshabilitado" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
