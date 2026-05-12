# ============================================================
# BENCHMARK - Diagnóstico completo del sistema
# ============================================================

param(
    [ValidateSet("antes", "despues", "rapido", "completo")]
    [string]$Mode = "rapido"
)

. "$PSScriptRoot\config.ps1"

Write-Header "🔍 DIAGNÓSTICO DEL SISTEMA"

$report = @{}

# 1. Sistema
Write-Step 1 "Información del sistema..."
$cpu = Get-CimInstance Win32_Processor
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$gpu = Get-CimInstance Win32_VideoController

$report.System = @{
    OS = $os.Caption
    Build = $os.BuildNumber
    CPU = $cpu.Name
    CPUCores = $cpu.NumberOfCores
    CPUThreads = $cpu.NumberOfLogicalProcessors
    RAM_Total = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    GPU = $gpu.Name
    GPU_RAM = [math]::Round($gpu.AdapterRAM / 1MB, 0)
    Model = $cs.Model
    Manufacturer = $cs.Manufacturer
}

Write-Host "  CPU: $($cpu.Name)" -ForegroundColor White
Write-Host "  RAM: $($report.System.RAM_Total) GB" -ForegroundColor White
Write-Host "  GPU: $($gpu.Name)" -ForegroundColor White
Write-Host "  OS:  $($os.Caption) Build $($os.BuildNumber)" -ForegroundColor White

# 2. Memoria
Write-Step 2 "Estado de memoria..."
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAM = [math]::Round($report.System.RAM_Total - $freeRAM, 2)
$pctUsed = [math]::Round(($usedRAM / $report.System.RAM_Total) * 100, 1)

$report.Memory = @{
    Total = $report.System.RAM_Total
    Used = $usedRAM
    Free = $freeRAM
    PercentUsed = $pctUsed
}

$ramColor = if ($pctUsed -gt 85) { "Red" } elseif ($pctUsed -gt 70) { "Yellow" } else { "Green" }
Write-Host "  Usado: ${usedRAM} GB ($pctUsed%)" -ForegroundColor $ramColor
Write-Host "  Libre: ${freeRAM} GB" -ForegroundColor $(if ($freeRAM -lt 1.5) { "Red" } else { "Green" })

# 3. CPU
Write-Step 3 "Estado de CPU..."
$cpuLoad = $cpu.LoadPercentage
$report.CPU = @{
    Load = $cpuLoad
    Name = $cpu.Name
}

Write-Host "  Carga: $cpuLoad%" -ForegroundColor $(if ($cpuLoad -gt 80) { "Red" } elseif ($cpuLoad -gt 50) { "Yellow" } else { "Green" })

# 4. Disco
Write-Step 4 "Estado de almacenamiento..."
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
foreach ($disk in $disks) {
    $totalGB = [math]::Round($disk.Size / 1GB, 0)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 0)
    $pctDisk = [math]::Round((($totalGB - $freeGB) / $totalGB) * 100, 1)
    
    $report.Disk = @{
        Letter = $disk.DeviceID
        Total = $totalGB
        Free = $freeGB
        PercentUsed = $pctDisk
    }
    
    $diskColor = if ($pctDisk -gt 90) { "Red" } elseif ($pctDisk -gt 80) { "Yellow" } else { "Green" }
    Write-Host "  $($disk.DeviceID) ${freeGB}/${totalGB} GB libre ($pctDisk% usado)" -ForegroundColor $diskColor
}

# 5. Startup
Write-Step 5 "Programas de inicio..."
$startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Measure-Object).Count
$regRunCount = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).PSObject.Properties.Count
Write-Host "  Startup: $startupCount items" -ForegroundColor $(if ($startupCount -gt 10) { "Yellow" } else { "Green" })

$report.Startup = @{
    Count = $startupCount
}

# 6. Servicios
Write-Step 6 "Servicios..."
$runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
$autoSvc = (Get-Service | Where-Object { $_.StartType -eq "Automatic" } | Measure-Object).Count
Write-Host "  Corriendo: $runningSvc | Auto: $autoSvc" -ForegroundColor $(if ($runningSvc -gt 100) { "Yellow" } else { "Green" })

$report.Services = @{
    Running = $runningSvc
    Auto = $autoSvc
}

# 7. Procesos
Write-Step 7 "Procesos..."
$procCount = (Get-Process | Measure-Object).Count
$heavyProcs = Get-Process | Where-Object { $_.WorkingSet64 -gt 100MB } | 
    Sort-Object WorkingSet64 -Descending | Select-Object -First 5 Name, @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,0)}}

Write-Host "  Total procesos: $procCount" -ForegroundColor $(if ($procCount -gt 200) { "Yellow" } else { "Green" })

$report.Processes = @{
    Count = $procCount
    Top5 = $heavyProcs
}
Write-Host "  Top 5 por RAM:" -ForegroundColor Gray
foreach ($p in $heavyProcs) {
    Write-Host "    $($p.Name): $($p.RAM_MB) MB" -ForegroundColor Gray
}

# 8. Plan de energía
Write-Step 8 "Plan de energía..."
$powerPlan = powercfg /getactivescheme
Write-Host "  $powerPlan" -ForegroundColor White

# 9. Efectos visuales
Write-Step 9 "Efectos visuales..."
$visualSetting = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ErrorAction SilentlyContinue
$transparency = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
Write-Host "  VisualFX: $($visualSetting.VisualFXSetting) | Transparencia: $($transparency.EnableTransparency)" -ForegroundColor White

# 10. Diagnóstico
Write-Step 10 "Diagnóstico..."
Write-Host ""
$issues = @()

if ($pctUsed -gt 80) { $issues += "🔴 RAM alta ($pctUsed%) → Ejecutá memory.ps1 o cerrá apps" }
if ($freeRAM -lt 1.5) { $issues += "🔴 RAM libre baja (${freeRAM} GB) → Necesitás liberar RAM" }
if ($cpuLoad -gt 70) { $issues += "🟡 CPU alta ($cpuLoad%) → Cerrá procesos pesados" }
if ($report.Disk.PercentUsed -gt 85) { $issues += "🟡 Disco lleno ($($report.Disk.PercentUsed)%) → Limpiá archivos" }
if ($startupCount -gt 10) { $issues += "🟡 Muchos programas de inicio ($startupCount) → Ejecutá startup-cleaner.ps1" }
if ($runningSvc -gt 100) { $issues += "🟡 Muchos servicios corriendo ($runningSvc) → Ejecutá services.ps1" }
if ($visualSetting.VisualFXSetting -ne 2) { $issues += "💡 Efectos visuales activos → Ejecutá performance.ps1" }
if ($transparency.EnableTransparency -eq 1) { $issues += "💡 Transparencias activas → Impacto en GPU" }

if ($issues.Count -eq 0) {
    Write-Success "¡Sistema en buen estado! Sin problemas detectados."
} else {
    Write-Host "  Problemas detectados:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "    $issue" -ForegroundColor White
    }
}

# Guardar reporte y comparar con benchmark anterior
$report.Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$report.DriveType = if ($Global:IsSSD) { "SSD" } else { "HDD" }

if ($Mode -ne "rapido") {
    $reportFile = Join-Path $LogDir "benchmark_${Mode}_$Timestamp.json"
    $report | ConvertTo-Json -Depth 5 | Out-File $reportFile -Encoding UTF8
    Write-Host ""
    Write-Info "Reporte guardado en: $reportFile"
}

# Comparar con benchmark "antes" si existe y estamos en modo "despues"
if ($Mode -eq "despues") {
    $antesFile = Get-ChildItem (Join-Path $LogDir "benchmark_antes_*.json") -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($antesFile) {
        Write-Host ""
        Write-Header "📊 COMPARACIÓN ANTES vs DESPUÉS"
        $antes = Get-Content $antesFile.FullName -Raw | ConvertFrom-Json
        
        # RAM
        $ramDiff = [math]::Round($report.Memory.Free - $antes.Memory.Free, 2)
        $ramColor = if ($ramDiff -gt 0) { "Green" } elseif ($ramDiff -lt 0) { "Red" } else { "White" }
        Write-Host "  RAM Libre:     $($antes.Memory.Free) GB → $($report.Memory.Free) GB " -NoNewline
        Write-Host "($(if($ramDiff -gt 0){"+"})${ramDiff} GB)" -ForegroundColor $ramColor
        
        # CPU
        $cpuDiff = $antes.CPU.Load - $report.CPU.Load
        $cpuColor = if ($cpuDiff -gt 0) { "Green" } elseif ($cpuDiff -lt 0) { "Red" } else { "White" }
        Write-Host "  CPU Carga:     $($antes.CPU.Load)% → $($report.CPU.Load)% " -NoNewline
        Write-Host "($cpuDiff%)" -ForegroundColor $cpuColor
        
        # Servicios
        $antesSvc = $antes.Services.Running
        $currSvc = $report.Services.Running
        $svcDiff = $antesSvc - $currSvc
        $svcColor = if ($svcDiff -gt 0) { "Green" } elseif ($svcDiff -lt 0) { "Red" } else { "White" }
        Write-Host "  Servicios:     $antesSvc → $currSvc " -NoNewline
        Write-Host("(-$svcDiff)" ) -ForegroundColor $svcColor
        
        # Procesos
        $antesProc = $antes.Processes.Count
        $currProc = $report.Processes.Count
        $procDiff = $antesProc - $currProc
        $procColor = if ($procDiff -gt 0) { "Green" } elseif ($procDiff -lt 0) { "Red" } else { "White" }
        Write-Host "  Procesos:      $antesProc → $currProc " -NoNewline
        Write-Host "(-$procDiff)" -ForegroundColor $procColor
        
        # Startup
        $antesStart = $antes.Startup.Count
        $currStart = $report.Startup.Count
        $startDiff = $antesStart - $currStart
        $startColor = if ($startDiff -gt 0) { "Green" } elseif ($startDiff -lt 0) { "Red" } else { "White" }
        Write-Host "  Startup:       $antesStart → $currStart " -NoNewline
        Write-Host "(-$startDiff)" -ForegroundColor $startColor
        
        Write-Host ""
    } else {
        Write-Info "No se encontró benchmark 'antes' para comparar."
        Write-Info "Ejecutá: .\benchmark.ps1 -Mode antes   antes de optimizar."
    }
}

# Guardar snapshot rápido para comparaciones futuras
$snapshotFile = Join-Path $LogDir "benchmark_latest.json"
$report | ConvertTo-Json -Depth 5 | Out-File $snapshotFile -Encoding UTF8

# Modo completo: generar HTML automáticamente
if ($Mode -eq "completo") {
    Write-Host ""
    Write-Header "📊 GENERANDO REPORTE HTML..."
    try {
        & "$PSScriptRoot\html-report.ps1" -InputFile $snapshotFile
        # Abrir en navegador
        $reportFile = Get-ChildItem (Join-Path $LogDir "report_*.html") -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($reportFile) {
            Start-Process $reportFile.FullName
            Write-Success "Reporte abierto en el navegador"
        }
    } catch {
        Write-Warn "No se pudo generar el reporte HTML: $_"
    }
}

Log "Benchmark completado ($Mode): RAM $pctUsed%, CPU $cpuLoad%, Disco $($report.Disk.PercentUsed)%"
