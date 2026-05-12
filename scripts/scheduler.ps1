# ============================================================
# SCHEDULED OPTIMIZATION - Programar optimización periódica
# ============================================================
# Crea/elimina una tarea de Windows que ejecuta el benchmark
# semanalmente y guarda el reporte para detectar degradación.
# ============================================================

param(
    [ValidateSet("install", "uninstall", "status")]
    [string]$Action = "status"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

$TaskName = "MejoraNotebook_WeeklyBenchmark"
$TaskDesc = "Ejecuta benchmark semanal de MejoraNotebook para detectar degradación del sistema"

# ============================================================
# INSTALAR TAREA
# ============================================================
function Install-ScheduledTask {
    Write-Header "⏰ INSTALANDO OPTIMIZACIÓN PROGRAMADA"
    Write-Host ""
    Write-Host "  Esto va a crear una tarea de Windows que:" -ForegroundColor White
    Write-Host "    • Ejecuta el benchmark cada lunes a las 10:00 AM" -ForegroundColor Gray
    Write-Host "    • Guarda el reporte en la carpeta logs/" -ForegroundColor Gray
    Write-Host "    • Solo corre cuando estás logueado" -ForegroundColor Gray
    Write-Host "    • No interfiere con tu trabajo" -ForegroundColor Gray
    Write-Host ""
    
    # Verificar si ya existe
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Warn "La tarea ya existe. Se sobreescribirá."
        Write-Host ""
        $confirm = Read-Host "  ¿Continuar? (SI para confirmar)"
        if ($confirm -ne "SI") {
            Write-Info "Cancelado."
            return
        }
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Crear acción: ejecutar benchmark
    $benchmarkPath = Join-Path $ScriptsDir "benchmark.ps1"
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$benchmarkPath`" -Mode antes" `
        -WorkingDirectory $ScriptRoot
    
    # Trigger: cada lunes a las 10:00 AM
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 10am
    
    # Settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable:$false `
        -MultipleInstances IgnoreNew
    
    # Principal: usuario actual, solo cuando está logueado
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Description $TaskDesc `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -ErrorAction Stop | Out-Null
        
        Write-Success "Tarea programada instalada"
        Write-Host ""
        Write-Info "Nombre: $TaskName"
        Write-Info "Frecuencia: Cada lunes a las 10:00 AM"
        Write-Info "Reportes: $LogDir\benchmark_antes_*.json"
        Write-Host ""
        Write-Info "Para verificar: .\scheduler.ps1 -Action status"
        Write-Info "Para eliminar: .\scheduler.ps1 -Action uninstall"
        Log "Scheduled task instalada: $TaskName"
    } catch {
        Write-Error "Error al crear tarea: $_"
    }
}

# ============================================================
# ELIMINAR TAREA
# ============================================================
function Uninstall-ScheduledTask {
    Write-Header "🗑️ ELIMINANDO OPTIMIZACIÓN PROGRAMADA"
    
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (!$existing) {
        Write-Info "La tarea no existe. No hay nada que eliminar."
        return
    }
    
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Success "Tarea programada eliminada"
        Log "Scheduled task eliminada: $TaskName"
    } catch {
        Write-Error "Error al eliminar tarea: $_"
    }
}

# ============================================================
# STATUS
# ============================================================
function Show-SchedulerStatus {
    Write-Header "📊 OPTIMIZACIÓN PROGRAMADA — STATUS"
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if ($task) {
        Write-Host "  Estado: " -NoNewline
        $stateColor = switch ($task.State) {
            "Ready" { "Green" }
            "Running" { "Yellow" }
            "Disabled" { "Red" }
            default { "White" }
        }
        Write-Host "$($task.State)" -ForegroundColor $stateColor
        
        # Info del trigger
        $triggers = $task.Triggers
        if ($triggers) {
            $t = $triggers[0]
            Write-Host "  Frecuencia: Semanal (lunes)" -ForegroundColor Gray
            Write-Host "  Hora: $($t.StartBoundary)" -ForegroundColor Gray
        }
        
        # Info de la acción
        $actions = $task.Actions
        if ($actions) {
            Write-Host "  Acción: $($actions.Execute) $($actions.Arguments)" -ForegroundColor Gray
        }
        
        # Última ejecución
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($taskInfo -and $taskInfo.LastRunTime -gt [DateTime]::MinValue) {
            Write-Host "  Última ejecución: $($taskInfo.LastRunTime)" -ForegroundColor Gray
            $resultColor = if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" }
            Write-Host "  Resultado: $($taskInfo.LastTaskResult)" -ForegroundColor $resultColor
        } else {
            Write-Host "  Última ejecución: Nunca" -ForegroundColor Gray
        }
        
        # Reportes generados
        Write-Host ""
        $reports = Get-ChildItem (Join-Path $LogDir "benchmark_antes_*.json") -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        if ($reports.Count -gt 0) {
            Write-Host "  Reportes generados: $($reports.Count)" -ForegroundColor Green
            Write-Host "  Último: $($reports[0].LastWriteTime)" -ForegroundColor Gray
        } else {
            Write-Host "  Reportes generados: 0 (aún no ejecutó)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Info "Eliminar: .\scheduler.ps1 -Action uninstall"
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "❌ NO INSTALADO" -ForegroundColor Red
        Write-Host ""
        Write-Info "Para instalar: .\scheduler.ps1 -Action install"
    }
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "install"   { Install-ScheduledTask }
    "uninstall" { Uninstall-ScheduledTask }
    "status"    { Show-SchedulerStatus }
}
