# ============================================================
# DAEMON - Monitoreo silencioso y optimización automática
# ============================================================
# Se ejecuta en segundo plano, aprende de tu uso y optimiza
# automáticamente. Cierra procesos pesados, libera RAM,
# ajusta servicios y mantiene el sistema óptimo.
#
# Uso:
#   .\daemon.ps1 -Action start    # Iniciar daemon
#   .\daemon.ps1 -Action stop     # Detener daemon
#   .\daemon.ps1 -Action status   # Ver estado
#   .\daemon.ps1 -Action config   # Ver/editar configuración
#   .\daemon.ps1 -Action log      # Ver historial de acciones
# ============================================================

param(
    [ValidateSet("start", "stop", "status", "config", "log", "learn")]
    [string]$Action = "status",
    [int]$Interval = 60
)

. "$PSScriptRoot\config.ps1"

$DaemonDir = Join-Path $ScriptRoot "daemon"
$DaemonStateFile = Join-Path $DaemonDir "state.json"
$DaemonConfigFile = Join-Path $DaemonDir "config.json"
$DaemonLogFile = Join-Path $DaemonDir "daemon.log"
$DaemonLearnFile = Join-Path $DaemonDir "learned.json"
$DaemonPIDFile = Join-Path $DaemonDir "daemon.pid"

# Crear directorio si no existe
if (!(Test-Path $DaemonDir)) { New-Item -ItemType Directory -Path $DaemonDir -Force | Out-Null }

# ============================================================
# CONFIGURACIÓN POR DEFECTO
# ============================================================
function Get-DefaultConfig {
    return @{
        # Intervalos
        MonitorIntervalSec = 60          # Cada cuánto monitorea (segundos)
        LearnIntervalMin = 30            # Cada cuánto aprende (minutos)
        
        # Umbrales de alerta
        RAM_Warn = 75                    # % RAM para alertar
        RAM_Critical = 90               # % RAM para acción automática
        CPU_Warn = 70                    # % CPU para alertar
        CPU_Critical = 90               # % CPU para acción automática
        Disk_Warn = 85                   # % Disco para alertar
        
        # Acciones automáticas
        AutoKill_RAM = 92               # % RAM para matar procesos automáticamente
        AutoKill_CPU = 95               # % CPU para matar procesos pesados
        AutoClean_RAM = 85              # % RAM para limpiar memoria automáticamente
        
        # Protecciones (NO matar estos procesos)
        ProtectedProcesses = @(
            "explorer", "dwm", "csrss", "winlogon", "services", "lsass",
            "svchost", "System", "Idle", "smss", "wininit",
            "WindowsTerminal", "powershell", "cmd",
            "chrome", "firefox", "msedge",  # Navegadores (el usuario puede estar usando)
            "Code", "code", "devenv",       # IDEs
            "Spotify", "Discord",           # Comunicación
            "Teams", "MSTeams", "slack",
            "Zoom", "zoom", "GoogleMeet"
        )
        
        # Procesos que siempre se pueden cerrar (aprendidos o conocidos)
        SafeToKill = @(
            "OneDrive", "FileSyncHelper",
            "Widgets", "WidgetService",
            "YourPhone", "PhoneExperienceHost",
            "Cortana", "SearchApp", "SearchUI",
            "SecurityHealthSystray",
            "Copilot", "WindowsCopilot",
            "TabTip", "tabtip32",
            "AdobeARM", "AdobeUpdate",
            "GoogleUpdate", "BraveUpdate",
            "CCXProcess", "AGSService"
        )
        
        # Notificaciones
        NotifyOnAction = $true           # Notificar cuando toma acción
        NotifyOnAlert = $true            # Notificar en alertas
        SilentMode = $false              # Modo silencioso (sin notificaciones)
        
        # Aprendizaje
        LearningEnabled = $true          # Habilitar aprendizaje
        AutoApplyLearned = $false        # Aplicar automáticamente lo aprendido (requiere revisión)
    }
}

# ============================================================
# CARGAR/GUARDAR CONFIGURACIÓN
# ============================================================
function Get-DaemonConfig {
    if (Test-Path $DaemonConfigFile) {
        return Get-Content $DaemonConfigFile -Raw | ConvertFrom-Json
    }
    $config = Get-DefaultConfig
    $config | ConvertTo-Json -Depth 5 | Out-File $DaemonConfigFile -Encoding UTF8
    return $config
}

function Save-DaemonConfig {
    param($Config)
    $Config | ConvertTo-Json -Depth 5 | Out-File $DaemonConfigFile -Encoding UTF8
}

# ============================================================
# LOGGING
# ============================================================
function Write-DaemonLog {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $DaemonLogFile -Value $entry -ErrorAction SilentlyContinue
}

function Show-DaemonLog {
    param([int]$Lines = 50)
    if (Test-Path $DaemonLogFile) {
        Get-Content $DaemonLogFile -Tail $Lines
    } else {
        Write-Info "No hay logs del daemon."
    }
}

# ============================================================
# APRENDIZAJE
# ============================================================
function Get-LearnedData {
    if (Test-Path $DaemonLearnFile) {
        return Get-Content $DaemonLearnFile -Raw | ConvertFrom-Json
    }
    return @{
        ProcessHistory = @{}       # proceso → { avgRAM, avgCPU, timesSeen, lastSeen, userClosed }
        PeakHours = @{}            # hora → { avgRAM, avgCPU, count }
        UserPatterns = @{
            ActiveHours = @()      # Horas en que el usuario está activo
            IdleHours = @()        # Horas de inactividad
            FrequentApps = @()     # Apps que el usuario usa frecuentemente
            NeverUsed = @()        # Apps que nunca se usan
        }
        LastLearned = $null
        TotalSamples = 0
    }
}

function Save-LearnedData {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Out-File $DaemonLearnFile -Encoding UTF8
}

function Learn-Pattern {
    $config = Get-DaemonConfig
    if (!$config.LearningEnabled) { return }
    
    $learned = Get-LearnedData
    $hour = (Get-Date).Hour
    
    # Recopilar datos actuales
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $pctRAM = [math]::Round((($totalRAM - $freeRAM) / $totalRAM) * 100, 1)
    $cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
    
    # Actualizar peak hours
    $hourKey = "h$hour"
    if (!$learned.PeakHours.$hourKey) {
        $learned.PeakHours | Add-Member -NotePropertyName $hourKey -NotePropertyValue @{ avgRAM = $pctRAM; avgCPU = $cpuLoad; count = 1 } -Force
    } else {
        $ph = $learned.PeakHours.$hourKey
        $ph.avgRAM = [math]::Round(($ph.avgRAM * $ph.count + $pctRAM) / ($ph.count + 1), 1)
        $ph.avgCPU = [math]::Round(($ph.avgCPU * $ph.count + $cpuLoad) / ($ph.count + 1), 1)
        $ph.count++
    }
    
    # Aprender procesos
    $processes = Get-Process | Where-Object { $_.WorkingSet64 -gt 10MB }
    foreach ($proc in $processes) {
        $name = $proc.Name
        if (!$learned.ProcessHistory.$name) {
            $learned.ProcessHistory | Add-Member -NotePropertyName $name -NotePropertyValue @{
                avgRAM = [math]::Round($proc.WorkingSet64 / 1MB, 0)
                avgCPU = 0
                timesSeen = 1
                lastSeen = (Get-Date -Format "yyyy-MM-dd HH:mm")
                totalRAM = [math]::Round($proc.WorkingSet64 / 1MB, 0)
            } -Force
        } else {
            $ph = $learned.ProcessHistory.$name
            $ph.timesSeen++
            $ph.totalRAM += [math]::Round($proc.WorkingSet64 / 1MB, 0)
            $ph.avgRAM = [math]::Round($ph.totalRAM / $ph.timesSeen, 0)
            $ph.lastSeen = (Get-Date -Format "yyyy-MM-dd HH:mm")
        }
    }
    
    # Detectar horas activas/inactivas
    $activeProcs = (Get-Process | Where-Object { $_.CPU -gt 100 }).Count
    if ($activeProcs -gt 5) {
        if ($hour -notin $learned.UserPatterns.ActiveHours) {
            $learned.UserPatterns.ActiveHours += $hour
        }
    } else {
        if ($hour -notin $learned.UserPatterns.IdleHours) {
            $learned.UserPatterns.IdleHours += $hour
        }
    }
    
    # Detectar apps frecuentemente usadas
    $topApps = Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.Name -notin @("System", "Idle", "svchost", "dwm", "csrss") } |
        Sort-Object CPU -Descending | Select-Object -First 10 Name
    foreach ($app in $topApps) {
        if ($app.Name -notin $learned.UserPatterns.FrequentApps) {
            $learned.UserPatterns.FrequentApps += $app.Name
        }
    }
    
    $learned.TotalSamples++
    $learned.LastLearned = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    Save-LearnedData $learned
    Write-DaemonLog "Aprendizaje completado. Muestras: $($learned.TotalSamples)"
}

# ============================================================
# MONITOREO
# ============================================================
function Start-Monitoring {
    $config = Get-DaemonConfig
    $learned = Get-LearnedData
    
    # Recopilar métricas
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $pctRAM = [math]::Round((($totalRAM - $freeRAM) / $totalRAM) * 100, 1)
    $cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
    
    $actions = @()
    
    # ============================================================
    # ACCIÓN 1: RAM crítica → matar procesos seguros
    # ============================================================
    if ($pctRAM -ge $config.AutoKill_RAM) {
        Write-DaemonLog "RAM CRÍTICA ($pctRAM%) — Cerrando procesos seguros" "WARN"
        
        $safeProcs = $config.SafeToKill
        foreach ($procName in $safeProcs) {
            $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                try {
                    $ramMB = [math]::Round($p.WorkingSet64 / 1MB, 0)
                    $p | Stop-Process -Force -ErrorAction Stop
                    $actions += "Cerrado: $procName (${ramMB}MB)"
                    Write-DaemonLog "Cerrado: $procName (${ramMB}MB)" "ACTION"
                } catch {}
            }
        }
        
        # Si sigue alta, cerrar procesos aprendidos que son seguros
        if ($pctRAM -ge ($config.AutoKill_RAM + 2)) {
            foreach ($procName in $learned.ProcessHistory.PSObject.Properties.Name) {
                if ($procName -notin $config.ProtectedProcesses -and 
                    $procName -notin $config.SafeToKill -and
                    $learned.ProcessHistory.$procName.timesSeen -gt 10) {
                    
                    $isIdle = (Get-Date).Hour -in $learned.UserPatterns.IdleHours
                    if ($isIdle) {
                        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
                        foreach ($p in $procs) {
                            $ramMB = [math]::Round($p.WorkingSet64 / 1MB, 0)
                            if ($ramMB -gt 100) {
                                try {
                                    $p | Stop-Process -Force -ErrorAction Stop
                                    $actions += "Cerrado (idle): $procName (${ramMB}MB)"
                                    Write-DaemonLog "Cerrado (idle): $procName (${ramMB}MB)" "ACTION"
                                } catch {}
                            }
                        }
                    }
                }
            }
        }
    }
    
    # ============================================================
    # ACCIÓN 2: RAM alta → limpiar memoria
    # ============================================================
    elseif ($pctRAM -ge $config.AutoClean_RAM) {
        Write-DaemonLog "RAM alta ($pctRAM%) — Limpiando memoria" "INFO"
        
        try {
            # GC.Collect
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            # EmptyWorkingSet
            $signature = @"
using System;
using System.Runtime.InteropServices;
public class Memory {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr hwProc);
}
"@
            Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
            Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.Name -notin $config.ProtectedProcesses } | ForEach-Object {
                try { [Memory]::EmptyWorkingSet($_.Handle) | Out-Null } catch {}
            }
            
            $newFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
            $freed = [math]::Round($newFree - $freeRAM, 2)
            if ($freed -gt 0.1) {
                $actions += "Memoria liberada: ${freed}GB"
                Write-DaemonLog "Memoria liberada: ${freed}GB" "ACTION"
            }
        } catch {}
    }
    
    # ============================================================
    # ACCIÓN 3: CPU crítica → matar proceso más pesado
    # ============================================================
    if ($cpuLoad -ge $config.AutoKill_CPU) {
        Write-DaemonLog "CPU CRÍTICA ($cpuLoad%) — Cerrando proceso pesado" "WARN"
        
        $heavyProc = Get-Process | Where-Object { $_.Name -notin $config.ProtectedProcesses -and $_.CPU -gt 1000 } |
            Sort-Object CPU -Descending | Select-Object -First 1
        
        if ($heavyProc) {
            try {
                $ramMB = [math]::Round($heavyProc.WorkingSet64 / 1MB, 0)
                $heavyProc | Stop-Process -Force -ErrorAction Stop
                $actions += "Cerrado (CPU alta): $($heavyProc.Name) (CPU: $([math]::Round($heavyProc.CPU, 0))s)"
                Write-DaemonLog "Cerrado (CPU alta): $($heavyProc.Name)" "ACTION"
            } catch {}
        }
    }
    
    # ============================================================
    # ACCIÓN 4: Procesos zombies (mucho RAM, sin actividad)
    # ============================================================
    $zombies = Get-Process | Where-Object { 
        $_.WorkingSet64 -gt 500MB -and 
        $_.CPU -lt 10 -and
        $_.Name -notin $config.ProtectedProcesses -and
        $_.Name -notin @("System", "Idle")
    }
    foreach ($zombie in $zombies) {
        $ramMB = [math]::Round($zombie.WorkingSet64 / 1MB, 0)
        Write-DaemonLog "Proceso zombie detectado: $($zombie.Name) (${ramMB}MB, CPU: $([math]::Round($zombie.CPU, 1))s)" "WARN"
    }
    
    # ============================================================
    # NOTIFICACIONES
    # ============================================================
    if ($actions.Count -gt 0 -and $config.NotifyOnAction -and !$config.SilentMode) {
        $actionSummary = $actions -join ", "
        Send-Notification -Title "🤖 Daemon" -Message "$($actions.Count) acciones: $actionSummary" -Icon "info"
    }
    
    # Guardar estado
    @{
        LastCheck = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RAM_Percent = $pctRAM
        RAM_Free_GB = $freeRAM
        CPU_Load = $cpuLoad
        ActionsCount = $actions.Count
        Actions = $actions
        TotalSamples = $learned.TotalSamples
    } | ConvertTo-Json -Depth 3 | Out-File $DaemonStateFile -Encoding UTF8
    
    return $actions
}

# ============================================================
# LOOP PRINCIPAL DEL DAEMON
# ============================================================
function Start-Daemon {
    Write-Header "🤖 INICIANDO DAEMON DE MONITOREO"
    
    $config = Get-DaemonConfig
    $interval = $config.MonitorIntervalSec
    $learnInterval = $config.LearnIntervalMin * 60
    $lastLearn = 0
    
    # Guardar PID
    $PID | Out-File $DaemonPIDFile -Encoding UTF8
    
    Write-Host "  ⏱️  Intervalo de monitoreo: ${interval}s" -ForegroundColor White
    Write-Host "  🧠 Intervalo de aprendizaje: $($config.LearnIntervalMin)min" -ForegroundColor White
    Write-Host "  🔔 Notificaciones: $(if($config.NotifyOnAction){"Activadas"}else{"Desactivadas"})" -ForegroundColor White
    Write-Host ""
    Write-Info "El daemon se ejecuta en segundo plano."
    Write-Info "Para detener: .\daemon.ps1 -Action stop"
    Write-Host ""
    
    # Notificación de inicio
    if (!$config.SilentMode) {
        Send-Notification -Title "🤖 Daemon Iniciado" -Message "Monitoreando sistema cada ${interval}s" -Icon "success"
    }
    
    Write-DaemonLog "Daemon iniciado (PID: $PID, Intervalo: ${interval}s)"
    
    try {
        while ($true) {
            # Monitoreo
            $actions = Start-Monitoring
            
            # Aprendizaje periódico
            $lastLearn += $interval
            if ($lastLearn -ge $learnInterval) {
                Learn-Pattern
                $lastLearn = 0
            }
            
            Start-Sleep -Seconds $interval
        }
    } catch {
        Write-DaemonLog "Daemon detenido: $_" "INFO"
    } finally {
        Remove-Item $DaemonPIDFile -Force -ErrorAction SilentlyContinue
        Write-DaemonLog "Daemon detenido"
        
        $config = Get-DaemonConfig
        if (!$config.SilentMode) {
            Send-Notification -Title "🤖 Daemon Detenido" -Message "Monitoreo finalizado" -Icon "warning"
        }
    }
}

# ============================================================
# DETENER DAEMON
# ============================================================
function Stop-Daemon {
    if (Test-Path $DaemonPIDFile) {
        $pid = Get-Content $DaemonPIDFile -Raw
        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $pid -Force
            Write-Success "Daemon detenido (PID: $pid)"
            Write-DaemonLog "Daemon detenido manualmente (PID: $pid)"
        } else {
            Write-Info "El daemon ya no está corriendo."
            Remove-Item $DaemonPIDFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Info "No hay daemon corriendo."
    }
}

# ============================================================
# ESTADO
# ============================================================
function Show-DaemonStatus {
    Write-Header "📊 DAEMON STATUS"
    
    # PID
    if (Test-Path $DaemonPIDFile) {
        $pid = Get-Content $DaemonPIDFile -Raw
        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "  Estado: " -NoNewline
            Write-Host "🟢 ACTIVO (PID: $pid)" -ForegroundColor Green
        } else {
            Write-Host "  Estado: " -NoNewline
            Write-Host "🔴 DETENIDO (PID huérfano)" -ForegroundColor Red
            Remove-Item $DaemonPIDFile -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🔴 DETENIDO" -ForegroundColor Red
    }
    
    # Último estado
    if (Test-Path $DaemonStateFile) {
        $state = Get-Content $DaemonStateFile -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "  Último check: $($state.LastCheck)" -ForegroundColor Gray
        Write-Host "  RAM: $($state.RAM_Percent)% ($($state.RAM_Free_GB) GB libre)" -ForegroundColor White
        Write-Host "  CPU: $($state.CPU_Load)%" -ForegroundColor White
        Write-Host "  Acciones tomadas: $($state.ActionsCount)" -ForegroundColor $(if($state.ActionsCount -gt 0){"Yellow"}else{"Green"})
    }
    
    # Aprendizaje
    if (Test-Path $DaemonLearnFile) {
        $learned = Get-Content $DaemonLearnFile -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "  🧠 APRENDIZAJE" -ForegroundColor Cyan
        Write-Host "  Muestras: $($learned.TotalSamples)" -ForegroundColor White
        Write-Host "  Procesos conocidos: $($learned.ProcessHistory.PSObject.Properties.Name.Count)" -ForegroundColor White
        Write-Host "  Último aprendizaje: $($learned.LastLearned)" -ForegroundColor Gray
        
        if ($learned.UserPatterns.ActiveHours.Count -gt 0) {
            Write-Host "  Horas activas: $($learned.UserPatterns.ActiveHours -join ', ')" -ForegroundColor White
        }
        if ($learned.UserPatterns.IdleHours.Count -gt 0) {
            Write-Host "  Horas inactivas: $($learned.UserPatterns.IdleHours -join ', ')" -ForegroundColor White
        }
    }
    
    # Configuración
    $config = Get-DaemonConfig
    Write-Host ""
    Write-Host "  ⚙️ CONFIGURACIÓN" -ForegroundColor Cyan
    Write-Host "  Monitoreo: $($config.MonitorIntervalSec)s" -ForegroundColor White
    Write-Host "  Aprendizaje: $($config.LearnIntervalMin)min" -ForegroundColor White
    Write-Host "  RAM crítica: $($config.AutoKill_RAM)%" -ForegroundColor White
    Write-Host "  RAM limpiar: $($config.AutoClean_RAM)%" -ForegroundColor White
    Write-Host "  CPU crítica: $($config.AutoKill_CPU)%" -ForegroundColor White
    Write-Host "  Notificaciones: $(if($config.NotifyOnAction){"On"}else{"Off"})" -ForegroundColor White
    Write-Host "  Silencioso: $(if($config.SilentMode){"On"}else{"Off"})" -ForegroundColor White
    
    Write-Host ""
    Write-Info "Iniciar: .\daemon.ps1 -Action start"
    Write-Info "Detener: .\daemon.ps1 -Action stop"
    Write-Info "Logs: .\daemon.ps1 -Action log"
}

# ============================================================
# VER LOGS
# ============================================================
function Show-Log {
    Write-Header "📄 LOG DEL DAEMON"
    Show-DaemonLog -Lines 30
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "start"  { Start-Daemon }
    "stop"   { Stop-Daemon }
    "status" { Show-DaemonStatus }
    "config" {
        $config = Get-DaemonConfig
        Write-Header "⚙️ CONFIGURACIÓN DEL DAEMON"
        $config | ConvertTo-Json -Depth 5
    }
    "log"    { Show-Log }
    "learn"  {
        Write-Header "🧠 APRENDIZAJE MANUAL"
        Learn-Pattern
        Write-Success "Aprendizaje completado"
        $learned = Get-LearnedData
        Write-Info "Muestras totales: $($learned.TotalSamples)"
    }
}
