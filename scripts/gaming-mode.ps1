# ============================================================
# GAMING MODE - Optimización para jugar
# ============================================================
# Diferente a Turbo Boost: este mantiene servicios de audio/red
# activos, prioriza GPU y reduce latencia de input.
# ============================================================

param(
    [ValidateSet("activate", "revert", "status")]
    [string]$Action = "activate"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

$GamingStateFile = Join-Path $RescueDir "gaming_state.json"

function Get-GamingStatus {
    if (Test-Path $GamingStateFile) {
        $state = Get-Content $GamingStateFile -Raw | ConvertFrom-Json
        return $state
    }
    return $null
}

function Save-GamingState {
    param($OriginalPlan, $ServicesStopped, $ProcessesKilled)
    @{
        Active = $true
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        OriginalPlan = $OriginalPlan
        ServicesStopped = $ServicesStopped
        ProcessesKilled = $ProcessesKilled
    } | ConvertTo-Json -Depth 5 | Out-File $GamingStateFile -Encoding UTF8
}

# ============================================================
# ACTIVAR GAMING MODE
# ============================================================
function Activate-Gaming {
    Write-Header "🎮 GAMING MODE — OPTIMIZADO PARA JUGAR"
    Write-Host ""
    Write-Host "  Esto va a:" -ForegroundColor White
    Write-Host "    • Desactivar Game DVR (mayor killer de FPS)" -ForegroundColor Gray
    Write-Host "    • GPU prioridad máxima" -ForegroundColor Gray
    Write-Host "    • Red optimizada para baja latencia" -ForegroundColor Gray
    Write-Host "    • Detener servicios de fondo (mantiene audio/chat)" -ForegroundColor Gray
    Write-Host "    • Reducir efectos visuales" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ✅ Se mantiene: Spotify, Discord, audio, red" -ForegroundColor Green
    Write-Host ""
    Write-Warn "⚠️  Todo es reversible con 'revert' o con [9] EMERGENCIA."
    Write-Host ""
    $confirm = Read-Host "  Escribí SI para activar Gaming Mode"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    Write-Host ""
    
    # Auto rescue point
    Write-Info "Creando rescue point de seguridad..."
    & "$PSScriptRoot\rescue.ps1" -Action create -Name "pre-gaming" | Out-Null
    Write-Host ""
    
    $servicesStopped = @()
    $processesKilled = @()
    $null = (powercfg /getactivescheme) -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
    $originalPlan = if ($Matches[1]) { $Matches[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }
    
    # 1. PLAN DE ENERGÍA - Alto Rendimiento (no Ultimate, consume menos)
    Write-Step 1 "Configurando plan de energía..."
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
        # CPU mínimo 5% en idle, 100% en carga (balance gaming/battery)
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 5 2>&1 | Out-Null
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 2>&1 | Out-Null
        powercfg /setactive scheme_current 2>&1 | Out-Null
        Write-Success "Plan Alto Rendimiento activo"
    } catch {
        Write-Warn "No se pudo configurar plan de energía"
    }
    
    # 2. DESACTIVAR GAME DVR (el mayor killer de FPS en Windows 11)
    Write-Step 2 "Desactivando Game DVR..."
    try {
        $dvrPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        Set-RegProperty $dvrPath -Name "AppCaptureEnabled" -Value 0
        
        $gameBarPath = "HKCU:\Software\Microsoft\GameBar"
        Set-RegProperty $gameBarPath -Name "AutoGameModeEnabled" -Value 1
        Set-RegProperty $gameBarPath -Name "AllowAutoGameMode" -Value 1
        Set-RegProperty $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0
        
        # Desactivar a nivel de sistema
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        if (!$Global:DryRun -and !(Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
        Set-RegProperty $policyPath -Name "AllowGameDVR" -Value 0
        
        Write-Success "Game DVR desactivado"
    } catch {
        Write-Warn "Error al desactivar Game DVR: $_"
    }
    
    # 3. PRIORIDAD GPU PARA JUEGOS
    Write-Step 3 "Configurando prioridad GPU..."
    try {
        # Preferencia de GPU de alto rendimiento
        $gpuPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
        Set-RegProperty $gpuPath -Name "DirectXUserGlobalSettings" -Value "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"
        
        # Hardware-accelerated GPU scheduling (reduce latencia)
        $hwsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        Set-RegProperty $hwsPath -Name "HwSchMode" -Value 2
        
        Write-Success "GPU prioridad máxima configurada"
    } catch {
        Write-Warn "Error al configurar GPU: $_"
    }
    
    # 4. RED - Optimizar para gaming (baja latencia)
    Write-Step 4 "Optimizando red para gaming..."
    try {
        # Desactivar Nagle's algorithm (reduce latencia en juegos)
        $adapters = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            Set-RegProperty $adapter.PSPath -Name "TcpAckFrequency" -Value 1
            Set-RegProperty $adapter.PSPath -Name "TCPNoDelay" -Value 1
            Set-RegProperty $adapter.PSPath -Name "TcpDelAckTicks" -Value 0
        }
        
        # DNS flush
        if (!$Global:DryRun) { ipconfig /flushdns 2>&1 | Out-Null }
        
        Write-Success "Red optimizada para baja latencia"
    } catch {
        Write-Warn "Error al optimizar red: $_"
    }
    
    # 5. DESACTIVAR EFECTOS VISUALES (pero mantener los que importan para gaming)
    Write-Step 5 "Ajustando efectos visuales..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 2
        Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" -Value 0
        
        Write-Success "Efectos visuales reducidos (mantiene funcionalidad)"
    } catch {
        Write-Warn "Error al ajustar efectos visuales: $_"
    }
    
    # 6. DETENER SERVICIOS NO ESENCIALES (pero mantener audio/red)
    Write-Step 6 "Deteniendo servicios de fondo..."
    $gamingServices = @(
        "DiagTrack", "SysMain", "WSearch",
        "MapsBroker", "lfsvc", "WerSvc",
        "XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc",
        "PhoneSvc", "MessagingService", "PimIndexMaintenanceSvc",
        "wisvc", "dmwappushservice", "RetailDemo",
        "AdobeARMservice", "brave", "edgeupdate", "gupdate",
        "CapCutServiceLS", "DFWSIDService", "DSAService", "DSAUpdateService",
        "BcastDVRUserService"
    )
    
    foreach ($svcName in $gamingServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            try {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                $servicesStopped += $svcName
            } catch {}
        }
    }
    Write-Success "$($servicesStopped.Count) servicios detenidos"
    
    # 7. CERRAR PROCESOS QUE INTERFIEREN (pero NO audio/red)
    Write-Step 7 "Cerrando procesos innecesarios..."
    # Usar lista centralizada de config.ps1, excluyendo audio/red
    $keepAlive = @("Spotify", "Discord")  # Mantener si están corriendo (audio/chat)
    $gamingProcesses = $Global:TurboProcesses | Where-Object { $_ -notin $keepAlive }
    
    foreach ($procPattern in $gamingProcesses) {
        Get-Process -Name $procPattern -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                $processesKilled += $_.Name
            } catch {}
        }
    }
    Write-Success "$($processesKilled.Count) procesos cerrados"
    
    # 8. PRIORIDAD CPU PARA FOREGROUND (input priority)
    Write-Step 8 "Configurando prioridad de input..."
    try {
        Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
            -Name "Win32PrioritySeparation" -Value 38
        Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "ForegroundLockTimeout" -Value 0
        
        Write-Success "Prioridad de input configurada"
    } catch {
        Write-Warn "Error al configurar prioridades: $_"
    }
    
    # 9. DESACTIVAR BACKGROUND TASKS
    Write-Step 9 "Desactivando tareas de fondo..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
            -Name "GlobalUserDisabled" -Value 1
        Write-Success "Background tasks desactivadas"
    } catch {
        Write-Warn "Error al desactivar background tasks: $_"
    }
    
    # Guardar estado
    Save-GamingState -OriginalPlan $originalPlan -ServicesStopped $servicesStopped -ProcessesKilled $processesKilled
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║     🎮 GAMING MODE ACTIVO 🎮                 ║" -ForegroundColor Green
    Write-Host "  ║                                               ║" -ForegroundColor Green
    Write-Host "  ║  Game DVR: Off | GPU: Máxima prioridad        ║" -ForegroundColor Yellow
    Write-Host "  ║  Red: Baja latencia | Audio: Activo           ║" -ForegroundColor Yellow
    Write-Host "  ║  Servicios: Mínimos | Input: Prioritario      ║" -ForegroundColor Yellow
    Write-Host "  ║                                               ║" -ForegroundColor Green
    Write-Host "  ║  Para revertir: .\gaming-mode.ps1 revert      ║" -ForegroundColor White
    Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Log "GAMING MODE activado: $($servicesStopped.Count) servicios, $($processesKilled.Count) procesos"
    Send-Notification -Title "🎮 Gaming Mode" -Message "Optimizado para gaming" -Icon "game"
}

# ============================================================
# REVERTIR GAMING MODE
# ============================================================
function Revert-Gaming {
    $state = Get-GamingStatus
    if (!$state -or !$state.Active) {
        Write-Info "Gaming Mode no está activo."
        return
    }
    
    Write-Header "🔄 REVIRTIENDO GAMING MODE"
    Write-Host "  Activado desde: $($state.Timestamp)" -ForegroundColor Gray
    Write-Host ""
    
    # 1. Restaurar plan de energía
    Write-Step 1 "Restaurando plan de energía..."
    if ($state.OriginalPlan) {
        powercfg /setactive $state.OriginalPlan 2>&1 | Out-Null
        Write-Success "Plan restaurado"
    } else {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
        Write-Success "Plan equilibrado activado"
    }
    
    # 2. Reactivar Game DVR
    Write-Step 2 "Reactivando Game DVR..."
    try {
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue
        Remove-ItemProperty "HKCU:\Software\Microsoft\GameBar" `
            -Name "UseNexusForGameBarEnabled" -ErrorAction SilentlyContinue
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        if (Test-Path $policyPath) {
            Remove-ItemProperty $policyPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue
        }
        Write-Success "Game DVR reactivado"
    } catch {
        Write-Warn "Error al reactivar Game DVR: $_"
    }
    
    # 3. Reactivar servicios
    Write-Step 3 "Reactivando servicios..."
    $restarted = 0
    foreach ($svcName in $state.ServicesStopped) {
        try {
            Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
            $restarted++
        } catch {}
    }
    Write-Success "$restarted servicios reactivados"
    
    # 4. Reactivar background apps
    Write-Step 4 "Reactivando apps en segundo plano..."
    try {
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
            -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
        Write-Success "Background apps reactivadas"
    } catch {
        Write-Warn "Error al reactivar background apps: $_"
    }
    
    # 5. Restaurar efectos visuales
    Write-Step 5 "Restaurando efectos visuales..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 0
        Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400"
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" -Value 1
        Write-Success "Efectos visuales restaurados"
    } catch {
        Write-Warn "Error al restaurar efectos visuales: $_"
    }
    
    # 6. Restaurar prioridades
    Write-Step 6 "Restaurando prioridades CPU..."
    Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
        -Name "Win32PrioritySeparation" -Value 2
    
    # Eliminar estado
    Remove-Item $GamingStateFile -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Success "Gaming Mode revertido. Sistema en modo normal."
    Log "GAMING MODE revertido"
}

# ============================================================
# STATUS
# ============================================================
function Show-GamingStatus {
    Write-Header "📊 GAMING MODE STATUS"
    
    $state = Get-GamingStatus
    if ($state -and $state.Active) {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🎮 ACTIVO" -ForegroundColor Green
        Write-Host "  Activado: $($state.Timestamp)" -ForegroundColor Gray
        Write-Host "  Servicios detenidos: $($state.ServicesStopped.Count)" -ForegroundColor Yellow
        Write-Host "  Procesos cerrados: $($state.ProcessesKilled.Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Para revertir: .\gaming-mode.ps1 revert" -ForegroundColor Cyan
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "✅ NORMAL" -ForegroundColor Green
        Write-Host "  Gaming Mode no está activo." -ForegroundColor Gray
    }
    
    # Estado actual
    Write-Host ""
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor).LoadPercentage
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    
    Write-Host "  CPU: $cpu%" -ForegroundColor $(if ($cpu -gt 80) { "Red" } else { "Green" })
    Write-Host "  RAM: ${freeRAM}/${totalRAM} GB libre" -ForegroundColor $(if ($freeRAM -lt 2) { "Red" } else { "Green" })
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "activate" { Activate-Gaming }
    "revert"   { Revert-Gaming }
    "status"   { Show-GamingStatus }
}
