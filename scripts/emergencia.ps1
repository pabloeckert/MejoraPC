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

$totalSteps = 12
$completed = 0
$errors = 0

# 1. Plan de energía equilibrado
Write-Step 1 "Restaurando plan equilibrado..."
try {
    $null = powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1
    # Validar
    $activePlan = powercfg /getactivescheme 2>&1
    if ($activePlan -match "381b4222") {
        Write-Success "Plan equilibrado activado"
        $completed++
    } else {
        Write-Warn "Plan equilibrado: no se pudo confirmar el cambio"
        $errors++
    }
} catch {
    Write-Error "Error al restaurar plan de energía: $_"
    $errors++
}

# 2. Reactivar servicios
Write-Step 2 "Reactivando servicios..."
try {
    $servicesToRestore = ($Global:ServicesToManual | ForEach-Object { $_.Name }) + 
                         ($Global:ServicesToDisable | ForEach-Object { $_.Name })
    
    # Servicios que siempre van a Manual (nunca Automatic)
    $manualServices = @("SysMain", "WSearch")
    
    $restored = 0
    $svcErrors = 0
    foreach ($svcName in $servicesToRestore) {
        $targetStartType = if ($svcName -in $manualServices) { "Manual" } else { "Automatic" }
        try {
            Set-Service -Name $svcName -StartupType $targetStartType -ErrorAction Stop
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
            $restored++
        } catch {
            $svcErrors++
            Log "WARN: No se pudo restaurar servicio $svcName : $_"
        }
    }
    Write-Success "$restored servicios reactivados"
    if ($svcErrors -gt 0) { Write-Warn "$svcErrors servicios no se pudieron restaurar" }
    $completed++
} catch {
    Write-Error "Error al reactivar servicios: $_"
    $errors++
}

# 3. Restaurar efectos visuales
Write-Step 3 "Restaurando efectos visuales..."
try {
    Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Value 0
    Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400"
    Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "1"
    Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name "EnableTransparency" -Value 1
    Set-RegProperty "HKCU:\Software\Microsoft\Windows\DWM" `
        -Name "EnableAeroPeek" -Value 1
    Write-Success "Efectos visuales restaurados"
    $completed++
} catch {
    Write-Error "Error al restaurar efectos visuales: $_"
    $errors++
}

# 4. Reactivar background apps
Write-Step 4 "Reactivando apps en segundo plano..."
try {
    Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
        -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
    Write-Success "Background apps reactivadas"
    $completed++
} catch {
    Write-Error "Error al reactivar background apps: $_"
    $errors++
}

# 5. Reactivar telemetría
Write-Step 5 "Reactivando telemetría (necesario para Windows Update)..."
try {
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
    $completed++
} catch {
    Write-Error "Error al reactivar telemetría: $_"
    $errors++
}

# 6. Reactivar Windows Update
Write-Step 6 "Reactivando Windows Update..."
try {
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (Test-Path $wuPath) {
        Remove-ItemProperty $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
    }
    Write-Success "Windows Update reactivado"
    $completed++
} catch {
    Write-Error "Error al reactivar Windows Update: $_"
    $errors++
}

# 7. Restaurar prioridades CPU
Write-Step 7 "Restaurando prioridades CPU..."
try {
    Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
        -Name "Win32PrioritySeparation" -Value 2
    Write-Success "Prioridades CPU restauradas"
    $completed++
} catch {
    Write-Error "Error al restaurar prioridades CPU: $_"
    $errors++
}

# 8. Reactivar Superfetch (si no es SSD)
Write-Step 8 "Verificando Superfetch..."
try {
    if (!$Global:IsSSD) {
        Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service "SysMain" -ErrorAction SilentlyContinue
        Write-Success "Superfetch reactivado (HDD detectado)"
    } else {
        Write-Info "SSD detectado. Superfetch se mantiene desactivado (recomendado)."
    }
    $completed++
} catch {
    Write-Error "Error al verificar Superfetch: $_"
    $errors++
}

# 9. Reactivar tips
Write-Step 9 "Reactivando tips de Windows..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegProperty $path -Name "SoftLandingEnabled" -Value 1
    Set-RegProperty $path -Name "SystemPaneSuggestionsEnabled" -Value 1
    Write-Success "Tips reactivados"
    $completed++
} catch {
    Write-Error "Error al reactivar tips: $_"
    $errors++
}

# 10. Eliminar estado turbo
Write-Step 10 "Limpiando estado turbo..."
try {
    Remove-Item (Join-Path $RescueDir "turbo_state.json") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $RescueDir "gaming_state.json") -Force -ErrorAction SilentlyContinue
    Write-Success "Estados turbo/gaming limpiados"
    $completed++
} catch {
    Write-Error "Error al limpiar estados: $_"
    $errors++
}

# 11. Restaurar red
Write-Step 11 "Restaurando configuración de red..."
try {
    # Restaurar TCP global
    netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    netsh int tcp set global chimney=disabled 2>&1 | Out-Null
    netsh int tcp set global congestionprovider=default 2>&1 | Out-Null
    # Restaurar parámetros TCP
    $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Remove-ItemProperty $tcpParams -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "TCPNoDelay" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "DefaultTTL" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "MaxFreeTcbs" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "MaxUserPort" -ErrorAction SilentlyContinue
    Remove-ItemProperty $tcpParams -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue
    # Restaurar DNS
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
    }
    # Restaurar throttling
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-RegProperty $mmPath -Name "NetworkThrottlingIndex" -Value 10
    Set-RegProperty $mmPath -Name "SystemResponsiveness" -Value 20
    # Limpiar estado
    Remove-Item (Join-Path $RescueDir "network_state.json") -Force -ErrorAction SilentlyContinue
    Write-Success "Configuración de red restaurada"
    $completed++
} catch {
    Write-Error "Error al restaurar red: $_"
    $errors++
}

# 12. Desbloquear Windows Update
Write-Step 12 "Desbloqueando Windows Update..."
try {
    Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (Test-Path $wuPath) {
        Remove-ItemProperty $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
        Remove-ItemProperty $wuPath -Name "AUOptions" -ErrorAction SilentlyContinue
        Remove-ItemProperty $wuPath -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
        Remove-ItemProperty $wuPath -Name "AUPowerManagement" -ErrorAction SilentlyContinue
    }
    $wuPath2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path $wuPath2) {
        Remove-ItemProperty $wuPath2 -Name "DoNotConnectToWindowsUpdateInternetLocations" -ErrorAction SilentlyContinue
        Remove-ItemProperty $wuPath2 -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
    }
    Remove-Item (Join-Path $RescueDir "wu_blocker_state.json") -Force -ErrorAction SilentlyContinue
    Write-Success "Windows Update desbloqueado"
    $completed++
} catch {
    Write-Error "Error al desbloquear WU: $_"
    $errors++
}

# Resumen
Write-Host ""
if ($errors -eq 0) {
    Write-Header "✅ RESTAURACIÓN COMPLETADA ($completed/$totalSteps)"
    Write-Success "Sistema restaurado al estado original."
} else {
    Write-Header "⚠️ RESTAURACIÓN PARCIAL ($completed/$totalSteps, $errors errores)"
    Write-Warn "Algunos pasos no se completaron. Revisá el log."
}
Write-Info "Se recomienda reiniciar para aplicar todos los cambios."
Show-LogPath
Write-Host ""
Write-Host "  ¿Reiniciar ahora? [S/N]" -ForegroundColor Yellow
$reboot = Read-Host "  Opción"
if ($reboot -eq "S" -or $reboot -eq "s") {
    Log "EMERGENCIA: Restauración completada ($completed/$totalSteps), reiniciando..."
    Restart-Computer -Force
} else {
    Log "EMERGENCIA: Restauración completada ($completed/$totalSteps), reinicio pendiente"
    Write-Info "Recordá reiniciar más tarde."
}
