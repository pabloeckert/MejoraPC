[CmdletBinding()]
param()

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         05 - PRIVACIDAD Y TELEMETRÍA            ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Deshabilitar telemetría de Windows" -ForegroundColor White
Write-Host "  [2] Deshabilitar publicidad personalizada" -ForegroundColor White
Write-Host "  [3] Deshabilitar seguimiento de actividad" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

switch ($opt) {
    '1' {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
        Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  [OK] Telemetría deshabilitada" -ForegroundColor Green
    }
    '2' {
        $adPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
        if (-not (Test-Path $adPath)) { New-Item -Path $adPath -Force | Out-Null }
        Set-ItemProperty -Path $adPath -Name 'Enabled' -Value 0 -Type DWord
        Write-Host "  [OK] Publicidad personalizada deshabilitada" -ForegroundColor Green
    }
    '3' {
        $actPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        if (-not (Test-Path $actPath)) { New-Item -Path $actPath -Force | Out-Null }
        Set-ItemProperty -Path $actPath -Name 'EnableActivityFeed' -Value 0 -Type DWord
        Set-ItemProperty -Path $actPath -Name 'PublishUserActivities' -Value 0 -Type DWord
        Write-Host "  [OK] Seguimiento de actividad deshabilitado" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
