[CmdletBinding()]
param([switch]$Auto)

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

$opt = '4'
if (-not $Auto) {
    Write-Host "  [1] Deshabilitar telemetría de Windows" -ForegroundColor White
    Write-Host "  [2] Deshabilitar publicidad personalizada" -ForegroundColor White
    Write-Host "  [3] Deshabilitar seguimiento de actividad" -ForegroundColor White
    Write-Host "  [4] Aplicar todo" -ForegroundColor White
    Write-Host "  [0] Volver" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Opción: " -NoNewline
    $opt = Read-Host
} else {
    Write-Host "  Modo automático: aplicando todo (telemetría + ads + actividad)" -ForegroundColor DarkGray
}

function Disable-Telemetry {
    try {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $p -Name 'AllowTelemetry' -Value 0 -Type DWord -Force -ErrorAction Stop
        Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
        Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Status "Telemetría" "deshabilitada" 'OK'
    } catch { Write-Status "Telemetría" "error: $_" 'ERROR' }
}
function Disable-Ads {
    try {
        $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
        if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $p -Name 'Enabled' -Value 0 -Type DWord -ErrorAction Stop
        Write-Status "Publicidad personalizada" "deshabilitada" 'OK'
    } catch { Write-Status "Publicidad personalizada" "error: $_" 'ERROR' }
}
function Disable-Activity {
    try {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $p -Name 'EnableActivityFeed' -Value 0 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $p -Name 'PublishUserActivities' -Value 0 -Type DWord -ErrorAction Stop
        Write-Status "Seguimiento de actividad" "deshabilitado" 'OK'
    } catch { Write-Status "Seguimiento de actividad" "error: $_" 'ERROR' }
}

switch ($opt) {
    '1' { Disable-Telemetry }
    '2' { Disable-Ads }
    '3' { Disable-Activity }
    '4' { Disable-Telemetry; Disable-Ads; Disable-Activity }
}

Write-Host ""
Wait-KeyIfInteractive -Auto:$Auto
