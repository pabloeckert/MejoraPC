# ============================================================
# EMERGENCIA - Restaurar todo al estado original
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🚨 MODO EMERGENCIA - RESTAURAR TODO"

Write-Host "  Este script va a:" -ForegroundColor White
Write-Host "    1. Restaurar el plan de energía equilibrado" -ForegroundColor Gray
Write-Host "    2. Reactivar todos los servicios desactivados" -ForegroundColor Gray
Write-Host "    3. Restaurar efectos visuales" -ForegroundColor Gray
Write-Host "    4. Reactivar apps en segundo plano" -ForegroundColor Gray
Write-Host "    5. Reactivar telemetría (necesario para updates)" -ForegroundColor Gray
Write-Host "    6. Reactivar actualizaciones automáticas" -ForegroundColor Gray
Write-Host ""
Write-Warn "Esto va a deshacer TODAS las optimizaciones."
Write-Host ""
$confirm = Read-Host "  Escribí SI para confirmar restauración total"

if ($confirm -ne "SI") {
    Write-Info "Cancelado."
    exit 0
}

Log "EMERGENCIA: Iniciando restauración total"

# 1. Plan de energía equilibrado
Write-Step 1 "Restaurando plan equilibrado..."
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
Write-Success "Plan equilibrado activado"

# 2. Reactivar servicios
Write-Step 2 "Reactivando servicios..."
$servicesToRestore = @(
    "DiagTrack", "SysMain", "WSearch", "BITS", "DoSvc",
    "MapsBroker", "lfsvc", "WerSvc", "XblAuthManager",
    "XblGameSave", "XboxGipSvc", "XboxNetApiSvc",
    "PhoneSvc", "MessagingService", "PimIndexMaintenanceSvc",
    "BcastDVRUserService", "wisvc", "dmwappushservice",
    "RetailDemo", "AdobeARMservice", "brave", "edgeupdate",
    "gupdate", "CapCutServiceLS", "DFWSIDService",
    "DSAService", "DSAUpdateService", "AeLookupSvc",
    "WpcMonSvc", "SCardSvr", "ScDeviceEnum", "SharedAccess",
    "RemoteRegistry", "TrkWks", "WMPNetworkSvc"
)

$restored = 0
foreach ($svcName in $servicesToRestore) {
    try {
        Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
        $restored++
    } catch {}
}
Write-Success "$restored servicios reactivados"

# 3. Restaurar efectos visuales
Write-Step 3 "Restaurando efectos visuales..."
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
    -Name "VisualFXSetting" -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -ErrorAction SilentlyContinue
Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "1" -ErrorAction SilentlyContinue
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "EnableTransparency" -Value 1 -ErrorAction SilentlyContinue
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" `
    -Name "EnableAeroPeek" -Value 1 -ErrorAction SilentlyContinue
Write-Success "Efectos visuales restaurados"

# 4. Reactivar background apps
Write-Step 4 "Reactivando apps en segundo plano..."
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
    -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
Write-Success "Background apps reactivadas"

# 5. Reactivar telemetría
Write-Step 5 "Reactivando telemetría (necesario para Windows Update)..."
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $regPath) {
    Remove-ItemProperty $regPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
}
$regPath2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (Test-Path $regPath2) {
    Remove-ItemProperty $regPath2 -Name "EnableActivityFeed" -ErrorAction SilentlyContinue
    Remove-ItemProperty $regPath2 -Name "PublishUserActivities" -ErrorAction SilentlyContinue
}
Write-Success "Telemetría reactivada"

# 6. Reactivar Windows Update
Write-Step 6 "Reactivando Windows Update..."
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (Test-Path $wuPath) {
    Remove-ItemProperty $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
}
Write-Success "Windows Update reactivado"

# 7. Restaurar prioridades CPU
Write-Step 7 "Restaurando prioridades CPU..."
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
    -Name "Win32PrioritySeparation" -Value 2 -ErrorAction SilentlyContinue
Write-Success "Prioridades CPU restauradas"

# 8. Reactivar Superfetch (si no es SSD)
Write-Step 8 "Verificando Superfetch..."
$disk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "NVMe" }
if (!$disk) {
    Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service "SysMain" -ErrorAction SilentlyContinue
    Write-Success "Superfetch reactivado (HDD detectado)"
} else {
    Write-Info "SSD detectado. Superfetch se mantiene desactivado (recomendado)."
}

# 9. Reactivar tips
Write-Step 9 "Reactivando tips de Windows..."
$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty $path -Name "SoftLandingEnabled" -Value 1 -ErrorAction SilentlyContinue
Set-ItemProperty $path -Name "SystemPaneSuggestionsEnabled" -Value 1 -ErrorAction SilentlyContinue
Write-Success "Tips reactivados"

# 10. Eliminar estado turbo
Write-Step 10 "Limpiando estado turbo..."
Remove-Item (Join-Path $RescueDir "turbo_state.json") -Force -ErrorAction SilentlyContinue
Write-Success "Estado turbo limpiado"

Write-Host ""
Write-Header "✅ RESTAURACIÓN COMPLETADA"
Write-Success "Sistema restaurado al estado original."
Write-Info "Se recomienda reiniciar para aplicar todos los cambios."
Write-Host ""
Write-Host "  ¿Reiniciar ahora? [S/N]" -ForegroundColor Yellow
$reboot = Read-Host "  Opción"
if ($reboot -eq "S" -or $reboot -eq "s") {
    Log "EMERGENCIA: Restauración completada, reiniciando..."
    Restart-Computer -Force
} else {
    Log "EMERGENCIA: Restauración completada, reinicio pendiente"
    Write-Info "Recordá reiniciar más tarde."
}
