# ============================================================
# PERFORMANCE - Tweaks de rendimiento y efectos visuales
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🚀 PERFORMANCE TWEAKS"

# Auto rescue point
Write-Info "Creando rescue point de seguridad..."
& "$PSScriptRoot\rescue.ps1" -Action create -Name "pre-performance" | Out-Null
Write-Host ""

$tweaks = 0
$errors = 0

# 1. Efectos visuales a mínimo
Write-Step 1 "Reduciendo efectos visuales..."
try {
    Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Value 2
    
    $desktopPath = "HKCU:\Control Panel\Desktop"
    Set-RegProperty $desktopPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))
    Set-RegProperty $desktopPath -Name "MenuShowDelay" -Value "0"
    
    Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name "EnableTransparency" -Value 0
    
    Set-RegProperty "HKCU:\Control Panel\WindowMetrics" -Name "MinAnimate" -Value "0"
    
    # Validar
    if (!$Global:DryRun -and (Confirm-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2)) {
        Write-Success "Efectos visuales reducidos al mínimo"
    } elseif ($Global:DryRun) {
        Write-Success "Efectos visuales (dry-run)"
    } else {
        Write-Warn "Efectos visuales: algunos valores no se aplicaron"
    }
    $tweaks++
} catch {
    Write-Error "Error al ajustar efectos visuales: $_"
    $errors++
}

# 2. Plan de energía a Alto Rendimiento
Write-Step 2 "Activando plan de Alto Rendimiento..."
try {
    if (!$Global:DryRun) {
        $highPerf = powercfg -list | Select-String "Alto rendimiento"
        if ($highPerf) {
            $guid = ($highPerf -split '\s+')[3]
            powercfg /setactive $guid 2>&1 | Out-Null
        } else {
            powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
        }
        Write-Success "Plan de Alto Rendimiento activado"
    } else {
        Write-Info "[DRY-RUN] Activar plan Alto Rendimiento"
    }
    $tweaks++
} catch {
    Write-Error "Error al cambiar plan de energía: $_"
    $errors++
}

# 3. Desactivar efectos de sombra
Write-Step 3 "Desactivando sombras y efectos de ventana..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-RegProperty $path -Name "ListviewAlphaSelect" -Value 0
    Set-RegProperty $path -Name "ListviewShadow" -Value 0
    
    $deskPath = "HKCU:\Software\Microsoft\Windows\DWM"
    Set-RegProperty $deskPath -Name "EnableAeroPeek" -Value 0
    Set-RegProperty $deskPath -Name "AlwaysHibernateThumbnails" -Value 0
    
    Write-Success "Sombras y efectos desactivados"
    $tweaks++
} catch {
    Write-Error "Error al desactivar sombras: $_"
    $errors++
}

# 4. Prioridad de foreground (apps en uso)
Write-Step 4 "Aumentando prioridad de apps en foreground..."
try {
    $path = "HKCU:\Control Panel\Desktop"
    Set-RegProperty $path -Name "ForegroundLockTimeout" -Value 0
    Set-RegProperty $path -Name "ForegroundFlashCount" -Value 0
    
    $path2 = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Set-RegProperty $path2 -Name "Win32PrioritySeparation" -Value 38
    
    Write-Success "Prioridad de foreground mejorada"
    $tweaks++
} catch {
    Write-Error "Error al ajustar prioridades: $_"
    $errors++
}

# 5. Desactivar telemetría del registro
Write-Step 5 "Desactivando telemetría..."
try {
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!$Global:DryRun) {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    }
    Set-RegProperty $path -Name "AllowTelemetry" -Value 0
    
    $path2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!$Global:DryRun) {
        if (!(Test-Path $path2)) { New-Item -Path $path2 -Force | Out-Null }
    }
    Set-RegProperty $path2 -Name "EnableActivityFeed" -Value 0
    Set-RegProperty $path2 -Name "PublishUserActivities" -Value 0
    
    Write-Success "Telemetría desactivada"
    $tweaks++
} catch {
    Write-Error "Error al desactivar telemetría: $_"
    $errors++
}

# 6. Optimizar SSD (si aplica)
Write-Step 6 "Verificando optimización de almacenamiento..."
try {
    if ($Global:IsSSD) {
        Set-ServiceState -Name "SysMain" -StartupType Disabled -Stop $true
        Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 0
        Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Value 0
        Write-Success "SSD detectado — Superfetch y Prefetch desactivados"
    } else {
        Write-Info "HDD detectado. Superfetch se mantiene activo."
    }
    $tweaks++
} catch {
    Write-Error "Error al optimizar almacenamiento: $_"
    $errors++
}

# 7. Desactivar tips y sugerencias
Write-Step 7 "Desactivando tips y sugerencias de Windows..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegProperty $path -Name "SoftLandingEnabled" -Value 0
    Set-RegProperty $path -Name "SubscribedContent-338389Enabled" -Value 0
    Set-RegProperty $path -Name "SubscribedContent-310093Enabled" -Value 0
    Set-RegProperty $path -Name "SystemPaneSuggestionsEnabled" -Value 0
    
    Write-Success "Tips y sugerencias desactivados"
    $tweaks++
} catch {
    Write-Error "Error al desactivar tips: $_"
    $errors++
}

# 8. Network tweaks
Write-Step 8 "Optimizando red..."
try {
    if (!$Global:DryRun) {
        netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    }
    
    $adapters = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
    foreach ($adapter in $adapters) {
        Set-RegProperty $adapter.PSPath -Name "TcpAckFrequency" -Value 1
        Set-RegProperty $adapter.PSPath -Name "TCPNoDelay" -Value 1
    }
    
    Write-Success "Red optimizada para menor latencia"
    $tweaks++
} catch {
    Write-Error "Error al optimizar red: $_"
    $errors++
}

Write-Host ""
Write-Header "✅ PERFORMANCE COMPLETADO"
Write-Success "$tweaks tweaks aplicados."
if ($errors -gt 0) { Write-Warn "Errores: $errors" }
Write-Info "Reiniciá para que todos los cambios tomen efecto."
Show-LogPath
Log "Performance tweaks completados: $tweaks exitosos, $errors errores"
