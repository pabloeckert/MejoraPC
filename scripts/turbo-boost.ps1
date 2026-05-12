# ============================================================
# TURBO BOOST - Modo máximo rendimiento para trabajo intenso
# ============================================================
# ⚠️  Este script es AGRESIVO. Solo usalo cuando necesitás
#     máximo rendimiento (edición de video, compilación, etc.)
#     Usá "revert" para volver a la normalidad.
# ============================================================

param(
    [ValidateSet("activate", "revert", "status")]
    [string]$Action = "activate"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

$TurboStateFile = Join-Path $RescueDir "turbo_state.json"

function Get-TurboStatus {
    if (Test-Path $TurboStateFile) {
        $state = Get-Content $TurboStateFile -Raw | ConvertFrom-Json
        return $state
    }
    return $null
}

function Save-TurboState {
    param($ServicesStopped, $ProcessesKilled, $OriginalPlan)
    
    @{
        Active = $true
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ServicesStopped = $ServicesStopped
        ProcessesKilled = $ProcessesKilled
        OriginalPlan = $OriginalPlan
    } | ConvertTo-Json -Depth 5 | Out-File $TurboStateFile -Encoding UTF8
}

# ============================================================
# ACTIVAR TURBO BOOST
# ============================================================
function Activate-Turbo {
    Write-Header "🔥🔥🔥 TURBO BOOST — MÁXIMO RENDIMIENTO 🔥🔥🔥"
    Write-Host ""
    Write-Host "  ⚡ Modo máximo rendimiento para trabajo intenso" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Esto va a:" -ForegroundColor White
    Write-Host "    • CPU al 100% siempre" -ForegroundColor Gray
    Write-Host "    • Detener +40 servicios no esenciales" -ForegroundColor Gray
    Write-Host "    • Cerrar +20 procesos en segundo plano" -ForegroundColor Gray
    Write-Host "    • Desactivar TODOS los efectos visuales" -ForegroundColor Gray
    Write-Host "    • Desactivar tareas en segundo plano" -ForegroundColor Gray
    Write-Host ""
    Write-Warn "⚠️  Todo es reversible con 'revert' o con [9] EMERGENCIA."
    Write-Host ""
    $confirm = Read-Host "  Escribí SI para activar Turbo Boost"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    Write-Host ""
    
    # Auto rescue point
    Write-Info "Creando rescue point de seguridad..."
    & "$PSScriptRoot\rescue.ps1" -Action create -Name "pre-turbo" | Out-Null
    Write-Host ""
    
    $servicesStopped = @()
    $processesKilled = @()
    $null = (powercfg /getactivescheme) -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
    $originalPlan = if ($Matches[1]) { $Matches[1] } else { "381b4222-f694-41f0-9685-ff5bb260df2e" }
    
    # 1. PLAN DE ENERGÍA MÁXIMO
    Write-Step 1 "Activando plan de energía ULTIMATE PERFORMANCE..."
    try {
        # Intentar activar Ultimate Performance
        $ultimate = powercfg -list | Select-String "Rendimiento máximo"
        if ($ultimate) {
            $guid = ($ultimate -split '\s+')[3]
            powercfg /setactive $guid 2>&1 | Out-Null
        } else {
            # Crear Ultimate Performance si no existe
            powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
            powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
        }
        
        # CPU al máximo siempre
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>&1 | Out-Null
        powercfg /setactive scheme_current 2>&1 | Out-Null
        
        Write-Success "CPU configurado al 100% siempre"
    } catch {
        Write-Warn "No se pudo activar Ultimate Performance, usando Alto Rendimiento"
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
    }
    
    # 2. DESACTIVAR SERVICIOS NO ESENCIALES
    Write-Step 2 "Deteniendo servicios no esenciales..."
    # Combinar listas centralizadas de config.ps1
    $turboServices = ($Global:ServicesToManual | ForEach-Object { $_.Name }) + 
                     ($Global:ServicesToDisable | ForEach-Object { $_.Name }) + 
                     $Global:TurboExtraServices
    
    foreach ($svcName in $turboServices) {
        Write-Progress -Activity "Turbo Boost — Deteniendo servicios" -Status "$($servicesStopped.Count) detenidos — $svcName" -PercentComplete ([math]::Min(($servicesStopped.Count / $turboServices.Count) * 100, 100))
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            try {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                $servicesStopped += $svcName
            } catch {}
        }
    }
    Write-Progress -Activity "Turbo Boost — Deteniendo servicios" -Completed
    Write-Success "$($servicesStopped.Count) servicios detenidos"
    
    # 3. MATAR PROCESOS NO ESENCIALES
    Write-Step 3 "Cerrando procesos no esenciales..."
    
    foreach ($procPattern in $Global:TurboProcesses) {
        Get-Process -Name $procPattern -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                $processesKilled += $_.Name
            } catch {}
        }
    }
    Write-Success "$($processesKilled.Count) procesos cerrados"
    
    # 4. DESACTIVAR EFECTOS VISUALES COMPLETAMENTE
    Write-Step 4 "Desactivando TODOS los efectos visuales..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue
        
        $deskPath = "HKCU:\Control Panel\Desktop"
        Set-RegProperty $deskPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
        Set-RegProperty $deskPath -Name "MenuShowDelay" -Value "0" -ErrorAction SilentlyContinue
        Set-RegProperty $deskPath -Name "DragFullWindows" -Value "0" -ErrorAction SilentlyContinue
        
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" -Value 0 -ErrorAction SilentlyContinue
        
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\DWM" `
            -Name "EnableAeroPeek" -Value 0 -ErrorAction SilentlyContinue
        
        Write-Success "Todos los efectos visuales desactivados"
    } catch {
        Write-Warn "Algunos efectos no se pudieron desactivar"
    }
    
    # 5. PRIORIDAD CPU MÁXIMA PARA FOREGROUND
    Write-Step 5 "Configurando prioridad CPU para foreground..."
    try {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Set-RegProperty $path -Name "Win32PrioritySeparation" -Value 38 -ErrorAction SilentlyContinue
        
        # Desactivar core parking (todos los núcleos activos)
        $path2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
        if (Test-Path $path2) {
            Set-RegProperty $path2 -Name "Attributes" -Value 0 -ErrorAction SilentlyContinue
        }
        
        Write-Success "CPU configurado para máximo rendimiento"
    } catch {
        Write-Warn "Algunos ajustes de CPU no se aplicaron"
    }
    
    # 6. DESACTIVAR BACKGROUND TASKS
    Write-Step 6 "Desactivando tareas en segundo plano..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
            -Name "GlobalUserDisabled" -Value 1 -ErrorAction SilentlyContinue
        
        # Desactivar actualizaciones automáticas temporalmente
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
        Set-RegProperty $wuPath -Name "NoAutoUpdate" -Value 1 -ErrorAction SilentlyContinue
        
        Write-Success "Background tasks desactivados"
    } catch {
        Write-Warn "No se pudieron desactivar todas las background tasks"
    }
    
    # 7. LIMPIAR MEMORIA AGRESIVAMENTE
    Write-Step 7 "Limpiando memoria..."
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        # Flush standby lists
        $signature = @"
        using System;
        using System.Runtime.InteropServices;
        public class MemFlush {
            [DllImport("ntdll.dll")]
            public static extern int NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
        }
"@
        Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
        
        ipconfig /flushdns 2>&1 | Out-Null
        
        $newFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
        Write-Success "Memoria libre: ${newFree} GB"
    } catch {
        Write-Warn "Limpieza de memoria parcial"
    }
    
    # Guardar estado
    Save-TurboState -ServicesStopped $servicesStopped -ProcessesKilled $processesKilled -OriginalPlan $originalPlan
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║     🔥 TURBO BOOST ACTIVADO 🔥               ║" -ForegroundColor Red
    Write-Host "  ║                                               ║" -ForegroundColor Red
    Write-Host "  ║  CPU: 100% | Servicios: Mínimos              ║" -ForegroundColor Yellow
    Write-Host "  ║  Efectos: Off | Background: Off               ║" -ForegroundColor Yellow
    Write-Host "  ║                                               ║" -ForegroundColor Red
    Write-Host "  ║  Para revertir: .\turbo-boost.ps1 revert      ║" -ForegroundColor White
    Write-Host "  ╚═══════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    Log "TURBO BOOST activado: $($servicesStopped.Count) servicios, $($processesKilled.Count) procesos"
    Send-Notification -Title "🔥 Turbo Boost" -Message "Modo máximo rendimiento activado" -Icon "fire"
}

# ============================================================
# REVERTIR TURBO BOOST
# ============================================================
function Revert-Turbo {
    $state = Get-TurboStatus
    if (!$state -or !$state.Active) {
        Write-Info "Turbo Boost no está activo."
        return
    }
    
    Write-Header "🔄 REVIRTIENDO TURBO BOOST"
    Write-Host "  Activado desde: $($state.Timestamp)" -ForegroundColor Gray
    Write-Host ""
    
    # 1. Restaurar plan de energía
    Write-Step 1 "Restaurando plan de energía..."
    if ($state.OriginalPlan) {
        powercfg /setactive $state.OriginalPlan 2>&1 | Out-Null
        Write-Success "Plan restaurado"
    } else {
        # Plan equilibrado por defecto
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
        Write-Success "Plan equilibrado activado"
    }
    
    # 2. Reactivar servicios
    Write-Step 2 "Reactivando servicios..."
    $restarted = 0
    foreach ($svcName in $state.ServicesStopped) {
        try {
            Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
            $restarted++
        } catch {}
    }
    Write-Success "$restarted servicios reactivados"
    
    # 3. Reactivar background apps
    Write-Step 3 "Reactivando apps en segundo plano..."
    try {
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
            -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
        
        # Reactivar actualizaciones automáticas
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $wuPath) {
            Remove-ItemProperty $wuPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
        }
        
        Write-Success "Background apps reactivadas"
    } catch {
        Write-Warn "Algunas background apps no se pudieron reactivar"
    }
    
    # 4. Restaurar efectos visuales (modo equilibrado)
    Write-Step 4 "Restaurando efectos visuales..."
    try {
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 0 -ErrorAction SilentlyContinue
        Set-RegProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -ErrorAction SilentlyContinue
        Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" -Value 1 -ErrorAction SilentlyContinue
        Write-Success "Efectos visuales restaurados"
    } catch {
        Write-Warn "Algunos efectos no se pudieron restaurar"
    }
    
    # Eliminar estado
    Remove-Item $TurboStateFile -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Success "Turbo Boost revertido. Sistema en modo normal."
    Log "TURBO BOOST revertido"
}

# ============================================================
# STATUS
# ============================================================
function Show-Status {
    Write-Header "📊 TURBO BOOST STATUS"
    
    $state = Get-TurboStatus
    if ($state -and $state.Active) {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🔥 ACTIVO" -ForegroundColor Red
        Write-Host "  Activado: $($state.Timestamp)" -ForegroundColor Gray
        Write-Host "  Servicios detenidos: $($state.ServicesStopped.Count)" -ForegroundColor Yellow
        Write-Host "  Procesos cerrados: $($state.ProcessesKilled.Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Para revertir: .\turbo-boost.ps1 revert" -ForegroundColor Cyan
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "✅ NORMAL" -ForegroundColor Green
        Write-Host "  Turbo Boost no está activo." -ForegroundColor Gray
    }
    
    # Mostrar estado actual del sistema
    Write-Host ""
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor).LoadPercentage
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $powerPlan = powercfg /getactivescheme
    
    Write-Host "  CPU: $cpu%" -ForegroundColor $(if ($cpu -gt 80) { "Red" } else { "Green" })
    Write-Host "  RAM: ${freeRAM}/${totalRAM} GB libre" -ForegroundColor $(if ($freeRAM -lt 2) { "Red" } else { "Green" })
    Write-Host "  Plan: $powerPlan" -ForegroundColor Gray
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "activate" { Activate-Turbo }
    "revert"   { Revert-Turbo }
    "status"   { Show-Status }
}
