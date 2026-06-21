[CmdletBinding()]
param()

# ── MejoraPC — modules/06-seguridad.ps1 ────────────────────────────
# Privacidad y telemetría.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         06 - SEGURIDAD / PRIVACIDAD              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Deshabilitar telemetría de Windows" -ForegroundColor White
Write-Host "  [2] Deshabilitar publicidad personalizada" -ForegroundColor White
Write-Host "  [3] Deshabilitar seguimiento de actividad" -ForegroundColor White
Write-Host "  [4] Aplicar todo" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

function Disable-Telemetry {
    $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name 'AllowTelemetry' -Value 0 -Type DWord -Force
    Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
    Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Status "Telemetría" "deshabilitada" 'OK'
}
function Disable-Ads {
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name 'Enabled' -Value 0 -Type DWord
    Write-Status "Publicidad personalizada" "deshabilitada" 'OK'
}
function Disable-Activity {
    $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name 'EnableActivityFeed' -Value 0 -Type DWord
    Set-ItemProperty -Path $p -Name 'PublishUserActivities' -Value 0 -Type DWord
    Write-Status "Seguimiento de actividad" "deshabilitado" 'OK'
}

switch ($opt) {
    '1' { Disable-Telemetry }
    '2' { Disable-Ads }
    '3' { Disable-Activity }
    '4' { Disable-Telemetry; Disable-Ads; Disable-Activity }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
