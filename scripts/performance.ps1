# ============================================================
# PERFORMANCE - Tweaks de rendimiento y efectos visuales
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🚀 PERFORMANCE TWEAKS"

$tweaks = 0

# 1. Efectos visuales a mínimo
Write-Step 1 "Reduciendo efectos visuales..."
try {
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Value 2 -ErrorAction Stop
    
    # Desactivar animaciones individuales
    $desktopPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty $desktopPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
    Set-ItemProperty $desktopPath -Name "MenuShowDelay" -Value "0" -ErrorAction SilentlyContinue
    
    # Desactivar transparencias
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name "EnableTransparency" -Value 0 -ErrorAction SilentlyContinue
    
    # Desactivar animaciones de ventana
    Set-ItemProperty "HKCU:\Control Panel\WindowMetrics" -Name "MinAnimate" -Value "0" -ErrorAction SilentlyContinue
    
    Write-Success "Efectos visuales reducidos al mínimo"
    $tweaks++
} catch {
    Write-Error "Error al ajustar efectos visuales: $_"
}

# 2. Plan de energía a Alto Rendimiento
Write-Step 2 "Activando plan de Alto Rendimiento..."
try {
    # Activar el plan de alto rendimiento (oculto por defecto)
    $highPerf = powercfg -list | Select-String "Alto rendimiento" 
    if ($highPerf) {
        $guid = ($highPerf -split '\s+')[3]
        powercfg /setactive $guid 2>&1 | Out-Null
    } else {
        # Crear si no existe
        powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
    }
    Write-Success "Plan de Alto Rendimiento activado"
    $tweaks++
} catch {
    Write-Error "Error al cambiar plan de energía: $_"
}

# 3. Desactivar efectos de sombra
Write-Step 3 "Desactivando sombras y efectos de ventana..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty $path -Name "ListviewAlphaSelect" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path -Name "ListviewShadow" -Value 0 -ErrorAction SilentlyContinue
    
    $deskPath = "HKCU:\Software\Microsoft\Windows\DWM"
    Set-ItemProperty $deskPath -Name "EnableAeroPeek" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $deskPath -Name "AlwaysHibernateThumbnails" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Success "Sombras y efectos desactivados"
    $tweaks++
} catch {
    Write-Error "Error al desactivar sombras: $_"
}

# 4. Prioridad de foreground (apps en uso)
Write-Step 4 "Aumentando prioridad de apps en foreground..."
try {
    $path = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty $path -Name "ForegroundLockTimeout" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path -Name "ForegroundFlashCount" -Value 0 -ErrorAction SilentlyContinue
    
    # Boost foreground apps
    $path2 = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Set-ItemProperty $path2 -Name "Win32PrioritySeparation" -Value 38 -ErrorAction SilentlyContinue
    
    Write-Success "Prioridad de foreground mejorada"
    $tweaks++
} catch {
    Write-Error "Error al ajustar prioridades: $_"
}

# 5. Desactivar telemetría del registro
Write-Step 5 "Desactivando telemetría..."
try {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty $path -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
    
    # Desactivar historial de actividades
    $path2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $path2)) { New-Item -Path $path2 -Force | Out-Null }
    Set-ItemProperty $path2 -Name "EnableActivityFeed" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path2 -Name "PublishUserActivities" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Success "Telemetría desactivada"
    $tweaks++
} catch {
    Write-Error "Error al desactivar telemetría: $_"
}

# 6. Optimizar SSD (si aplica)
Write-Step 6 "Verificando optimización de almacenamiento..."
try {
    $disk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "NVMe" }
    if ($disk) {
        # Desactivar Superfetch para SSD
        Set-Service "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
        
        # Desactivar Prefetch
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        Set-ItemProperty $path -Name "EnablePrefetcher" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty $path -Name "EnableSuperfetch" -Value 0 -ErrorAction SilentlyContinue
        
        Write-Success "SSD detectado - Superfetch y Prefetch desactivados"
    } else {
        Write-Info "No se detectó SSD. Superfetch se mantiene activo."
    }
    $tweaks++
} catch {
    Write-Error "Error al optimizar almacenamiento: $_"
}

# 7. Desactivar tips y sugerencias
Write-Step 7 "Desactivando tips y sugerencias de Windows..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty $path -Name "SoftLandingEnabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path -Name "SubscribedContent-338389Enabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path -Name "SubscribedContent-310093Enabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $path -Name "SystemPaneSuggestionsEnabled" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Success "Tips y sugerencias desactivados"
    $tweaks++
} catch {
    Write-Error "Error al desactivar tips: $_"
}

# 8. Network tweaks
Write-Step 8 "Optimizando red..."
try {
    # Desactivar auto-tuning (puede mejorar throughput en algunos casos)
    netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    
    # Desactivar Nagle's algorithm para menor latencia
    $adapters = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    foreach ($adapter in $adapters) {
        Set-ItemProperty $adapter.PSPath -Name "TcpAckFrequency" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty $adapter.PSPath -Name "TCPNoDelay" -Value 1 -ErrorAction SilentlyContinue
    }
    
    Write-Success "Red optimizada para menor latencia"
    $tweaks++
} catch {
    Write-Error "Error al optimizar red: $_"
}

Write-Host ""
Write-Header "✅ PERFORMANCE COMPLETADO"
Write-Success "$tweaks tweaks aplicados."
Write-Info "Reiniciá para que todos los cambios tomen efecto."
Log "Performance tweaks completados: $tweaks"
