# ============================================================
# UNINSTALL TOOL - Desinstalador completo de MejoraNotebook
# ============================================================
# Restaura todo al estado original y opcionalmente elimina
# el programa del sistema.
# ============================================================

. "$PSScriptRoot\config.ps1"
Assert-Admin

$ToolDir = Split-Path -Parent $PSScriptRoot

Write-Header "🗑️ DESINSTALADOR DE MEJORANOTEBOOK"

Write-Host "  Este asistente va a:" -ForegroundColor White
Write-Host "    1. Restaurar TODOS los servicios a su estado original" -ForegroundColor Gray
Write-Host "    2. Restaurar efectos visuales y plan de energía" -ForegroundColor Gray
Write-Host "    3. Reactivar telemetría y Windows Update" -ForegroundColor Gray
Write-Host "    4. Reactivar apps en segundo plano" -ForegroundColor Gray
Write-Host "    5. Limpiar archivos de estado del programa" -ForegroundColor Gray
Write-Host "    6. (Opcional) Eliminar la carpeta del programa" -ForegroundColor Gray
Write-Host ""
Write-Warn "Esto va a deshacer TODAS las optimizaciones realizadas."
Write-Host ""

# Verificar si hay rescue points
$rescueDirs = Get-ChildItem $RescueDir -Directory -ErrorAction SilentlyContinue
if ($rescueDirs.Count -gt 0) {
    Write-Host "  📁 Rescue points encontrados: $($rescueDirs.Count)" -ForegroundColor Cyan
    Write-Host "  ¿Restaurar desde el más reciente antes de desinstalar?" -ForegroundColor White
    Write-Host ""
    Write-Host "    [1] Sí, restaurar y desinstalar" -ForegroundColor Green
    Write-Host "    [2] No, solo desinstalar (dejar cambios)" -ForegroundColor Yellow
    Write-Host "    [0] Cancelar" -ForegroundColor Red
    Write-Host ""
    $restoreChoice = Read-Host "  Opción"
    
    if ($restoreChoice -eq "0") {
        Write-Info "Cancelado."
        exit 0
    }
    
    if ($restoreChoice -eq "1") {
        # Restaurar desde rescue point más reciente
        $latest = $rescueDirs | Sort-Object Name -Descending | Select-Object -First 1
        Write-Host ""
        Write-Header "🔄 RESTAURANDO DESDE: $($latest.Name)"
        
        $servicesFile = Join-Path $latest.FullName "services.csv"
        if (Test-Path $servicesFile) {
            Write-Step 1 "Restaurando servicios..."
            $savedServices = Import-Csv $servicesFile
            $svcCount = 0
            foreach ($svc in $savedServices) {
                $current = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
                if ($current) {
                    if ($current.StartType.ToString() -ne $svc.StartType) {
                        Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction SilentlyContinue
                    }
                    if ($svc.Status -eq "Running" -and $current.Status -ne "Running") {
                        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
                    }
                    $svcCount++
                }
            }
            Write-Success "$svcCount servicios restaurados"
        }
        
        # Restaurar plan de energía
        $powerFile = Join-Path $latest.FullName "powerplan.txt"
        if (Test-Path $powerFile) {
            Write-Step 2 "Restaurando plan de energía..."
            $savedPlan = Get-Content $powerFile
            if ($savedPlan -match "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})") {
                powercfg /setactive $Matches[1] 2>&1 | Out-Null
            }
            Write-Success "Plan de energía restaurado"
        }
        
        # Restaurar efectos visuales
        $visualFile = Join-Path $latest.FullName "visual.json"
        if (Test-Path $visualFile) {
            Write-Step 3 "Restaurando efectos visuales..."
            $savedVisual = Get-Content $visualFile -Raw | ConvertFrom-Json
            if ($savedVisual.VisualEffects) {
                Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
                    -Name "VisualFXSetting" -Value $savedVisual.VisualEffects.VisualFXSetting -ErrorAction SilentlyContinue
            }
            Write-Success "Efectos visuales restaurados"
        }
        
        Write-Success "Restauración completada"
    }
} else {
    Write-Info "No hay rescue points. Se restaurarán valores por defecto de Windows."
    Write-Host ""
    $confirm = Read-Host "  ¿Continuar? (SI para confirmar)"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        exit 0
    }
}

# Restaurar valores por defecto de Windows
Write-Host ""
Write-Header "🔄 RESTAURANDO VALORES POR DEFECTO"

# 1. Servicios a Manual (los que el script puso en Manual)
Write-Step 1 "Restaurando servicios..."
$svcRestored = 0
foreach ($svcInfo in $Global:ServicesToManual) {
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -eq "Manual") {
        try {
            Set-Service -Name $svcInfo.Name -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
            $svcRestored++
        } catch {}
    }
}
# SysMain y WSearch van a Manual (no Automatic) — son los que el script desactivó
foreach ($svcInfo in $Global:ServicesToDisable) {
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -eq "Disabled") {
        try {
            Set-Service -Name $svcInfo.Name -StartupType Manual -ErrorAction Stop
            Start-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
            $svcRestored++
        } catch {}
    }
}
Write-Success "$svcRestored servicios restaurados"

# 2. Plan de energía equilibrado
Write-Step 2 "Restaurando plan de energía..."
try {
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
    Write-Success "Plan equilibrado activado"
} catch {
    Write-Warn "No se pudo restaurar plan de energía"
}

# 3. Efectos visuales
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
} catch {
    Write-Warn "No se pudieron restaurar todos los efectos"
}

# 4. Reactivar telemetría
Write-Step 4 "Reactivando telemetría..."
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
} catch {
    Write-Warn "No se pudo reactivar telemetría"
}

# 5. Reactivar Windows Update
Write-Step 5 "Reactivando Windows Update..."
try {
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
    # Reactivar servicios WU
    Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Set-Service UsoSvc -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service UsoSvc -ErrorAction SilentlyContinue
    Write-Success "Windows Update reactivado"
} catch {
    Write-Warn "No se pudo reactivar Windows Update completamente"
}

# 6. Reactivar background apps
Write-Step 6 "Reactivando apps en segundo plano..."
try {
    Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
        -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
    Write-Success "Background apps reactivadas"
} catch {
    Write-Warn "No se pudo reactivar background apps"
}

# 7. Restaurar prioridades CPU
Write-Step 7 "Restaurando prioridades CPU..."
try {
    Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
        -Name "Win32PrioritySeparation" -Value 2
    Write-Success "Prioridades CPU restauradas"
} catch {
    Write-Warn "No se pudieron restaurar prioridades"
}

# 8. Restaurar tips de Windows
Write-Step 8 "Restaurando tips de Windows..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegProperty $path -Name "SoftLandingEnabled" -Value 1
    Set-RegProperty $path -Name "SystemPaneSuggestionsEnabled" -Value 1
    Write-Success "Tips restaurados"
} catch {
    Write-Warn "No se pudieron restaurar tips"
}

# 9. Reactivar Game DVR
Write-Step 9 "Reactivando Game DVR..."
try {
    Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (Test-Path $policyPath) {
        Remove-ItemProperty $policyPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue
    }
    Write-Success "Game DVR reactivado"
} catch {
    Write-Warn "No se pudo reactivar Game DVR"
}

# 10. Reactivar Superfetch (si no es SSD)
Write-Step 10 "Verificando Superfetch..."
try {
    if (!$Global:IsSSD) {
        Set-Service "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service "SysMain" -ErrorAction SilentlyContinue
        Write-Success "Superfetch reactivado (HDD detectado)"
    } else {
        Write-Info "SSD detectado. Superfetch se mantiene desactivado (recomendado)."
    }
} catch {
    Write-Warn "No se pudo verificar Superfetch"
}

# Limpiar archivos de estado
Write-Host ""
Write-Header "🧹 LIMPIANDO ARCHIVOS DEL PROGRAMA"

$cleaned = 0

# Eliminar archivos de estado
$stateFiles = @(
    (Join-Path $RescueDir "turbo_state.json"),
    (Join-Path $RescueDir "gaming_state.json"),
    (Join-Path $RescueDir "wu_blocker_state.json")
)
foreach ($f in $stateFiles) {
    if (Test-Path $f) {
        Remove-Item $f -Force -ErrorAction SilentlyContinue
        $cleaned++
    }
}

# Eliminar logs
if (Test-Path $LogDir) {
    $logCount = (Get-ChildItem $LogDir -File -ErrorAction SilentlyContinue).Count
    Remove-Item $LogDir -Recurse -Force -ErrorAction SilentlyContinue
    $cleaned += $logCount
    Write-Success "Logs eliminados ($logCount archivos)"
}

# Eliminar scheduled task
$taskName = "MejoraNotebook_WeeklyBenchmark"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Success "Tarea programada eliminada"
    $cleaned++
}

Write-Success "Archivos de estado limpiados: $cleaned"

# Preguntar si eliminar la carpeta completa
Write-Host ""
Write-Header "❓ ELIMINAR PROGRAMA"
Write-Host "  ¿Eliminar la carpeta completa del programa?" -ForegroundColor White
Write-Host "  Esto va a borrar: $ToolDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "    [1] Sí, eliminar todo" -ForegroundColor Red
Write-Host "    [2] No, dejar los archivos (por las dudas)" -ForegroundColor Green
Write-Host ""
$deleteChoice = Read-Host "  Opción"

if ($deleteChoice -eq "1") {
    Write-Host ""
    Write-Warn "Esto va a eliminar permanentemente la carpeta del programa."
    $confirm = Read-Host "  Escribí SI para confirmar eliminación"
    if ($confirm -eq "SI") {
        # Crear script batch que se auto-elimina (no podemos borrar mientras se ejecuta)
        $batContent = @"
@echo off
timeout /t 3 /nobreak >nul
rmdir /s /q "$ToolDir"
del "%~f0"
"@
        $batPath = Join-Path $env:TEMP "mejoranotebook_cleanup.bat"
        $batContent | Out-File $batPath -Encoding ASCII
        
        Write-Host ""
        Write-Header "✅ DESINSTALACIÓN COMPLETADA"
        Write-Success "El programa se eliminará automáticamente al cerrar esta ventana."
        Write-Info "Carpeta: $ToolDir"
        Write-Host ""
        Write-Host "  ¡Gracias por usar MejoraNotebook! 👋" -ForegroundColor Cyan
        Write-Host ""
        
        Log "Desinstalación completada. Auto-eliminación programada."
        
        # Ejecutar batch y cerrar
        Start-Process $batPath -WindowStyle Hidden
        exit 0
    } else {
        Write-Info "Eliminación cancelada. Los archivos se mantienen."
    }
} else {
    Write-Info "Archivos mantenidos en: $ToolDir"
}

Write-Host ""
Write-Header "✅ DESINSTALACIÓN COMPLETADA"
Write-Success "Todas las optimizaciones fueron revertidas."
Write-Info "Se recomienda REINICIAR para aplicar todos los cambios."
Write-Host ""
Write-Host "  ¿Reiniciar ahora? [S/N]" -ForegroundColor Yellow
$reboot = Read-Host "  Opción"
if ($reboot -eq "S" -or $reboot -eq "s") {
    Log "Desinstalación completada, reiniciando..."
    Restart-Computer -Force
} else {
    Log "Desinstalación completada, reinicio pendiente"
    Write-Info "Recordá reiniciar más tarde."
    Write-Host ""
    Write-Host "  ¡Chau! 👋" -ForegroundColor Cyan
}
