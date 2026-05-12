# ============================================================
# HEALTH CHECK - Verificación rápida del sistema
# ============================================================
# Muestra un resumen visual del estado del sistema en segundos.
# Ideal para verificar rápidamente si todo está OK.
# ============================================================

. "$PSScriptRoot\config.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║           🏥 HEALTH CHECK RÁPIDO                     ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. CPU
$cpu = Get-CimInstance Win32_Processor
$cpuLoad = $cpu.LoadPercentage
$cpuColor = if ($cpuLoad -gt 80) { "Red" } elseif ($cpuLoad -gt 50) { "Yellow" } else { "Green" }
$cpuIcon = if ($cpuLoad -gt 80) { "🔴" } elseif ($cpuLoad -gt 50) { "🟡" } else { "🟢" }
Write-Host "  $cpuIcon CPU:    $cpuLoad%  " -ForegroundColor $cpuColor -NoNewline
Write-Host "($($cpu.Name))" -ForegroundColor Gray

# 2. RAM
$os = Get-CimInstance Win32_OperatingSystem
$totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
$pctRAM = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
$ramColor = if ($pctRAM -gt 85) { "Red" } elseif ($pctRAM -gt 70) { "Yellow" } else { "Green" }
$ramIcon = if ($pctRAM -gt 85) { "🔴" } elseif ($pctRAM -gt 70) { "🟡" } else { "🟢" }
Write-Host "  $ramIcon RAM:    ${pctRAM}%  (${freeRAM} GB libre de ${totalRAM} GB)" -ForegroundColor $ramColor

# 3. Disco
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1
$totalDisk = [math]::Round($disk.Size / 1GB, 0)
$freeDisk = [math]::Round($disk.FreeSpace / 1GB, 0)
$pctDisk = [math]::Round((($totalDisk - $freeDisk) / $totalDisk) * 100, 1)
$diskColor = if ($pctDisk -gt 90) { "Red" } elseif ($pctDisk -gt 80) { "Yellow" } else { "Green" }
$diskIcon = if ($pctDisk -gt 90) { "🔴" } elseif ($pctDisk -gt 80) { "🟡" } else { "🟢" }
Write-Host "  $diskIcon Disco:  ${pctDisk}%  (${freeDisk} GB libre de ${totalDisk} GB)" -ForegroundColor $diskColor

# 4. Servicios
$runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
$svcColor = if ($runningSvc -gt 120) { "Red" } elseif ($runningSvc -gt 80) { "Yellow" } else { "Green" }
$svcIcon = if ($runningSvc -gt 120) { "🔴" } elseif ($runningSvc -gt 80) { "🟡" } else { "🟢" }
Write-Host "  $svcIcon Servicios: $runningSvc corriendo" -ForegroundColor $svcColor

# 5. Procesos
$procCount = (Get-Process | Measure-Object).Count
$procColor = if ($procCount -gt 200) { "Yellow" } else { "Green" }
$procIcon = if ($procCount -gt 200) { "🟡" } else { "🟢" }
Write-Host "  $procIcon Procesos: $procCount" -ForegroundColor $procColor

# 6. Startup
$startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Measure-Object).Count
$startColor = if ($startupCount -gt 10) { "Yellow" } else { "Green" }
$startIcon = if ($startupCount -gt 10) { "🟡" } else { "🟢" }
Write-Host "  $startIcon Startup:  $startupCount items" -ForegroundColor $startColor

# 7. Disco tipo
$diskType = if ($Global:IsSSD) { "SSD ✅" } else { "HDD ⚠️" }
$diskTypeColor = if ($Global:IsSSD) { "Green" } else { "Yellow" }
Write-Host "  💾 Tipo:   $diskType" -ForegroundColor $diskTypeColor

# 8. Network
Write-Host ""
Write-Host "  ─── RED ───────────────────────────────────────────" -ForegroundColor Gray
$ping = Test-NetConnection -ComputerName "1.1.1.1" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
if ($ping) {
    $pingMs = $ping.PingReplyDetails.RoundtripTime
    $pingColor = if ($pingMs -lt 30) { "Green" } elseif ($pingMs -lt 100) { "Yellow" } else { "Red" }
    $pingIcon = if ($pingMs -lt 30) { "🟢" } elseif ($pingMs -lt 100) { "🟡" } else { "🔴" }
    Write-Host "  $pingIcon Ping:    ${pingMs} ms (1.1.1.1)" -ForegroundColor $pingColor
} else {
    Write-Host "  🔴 Ping:   Sin conexión" -ForegroundColor Red
}

# Estado de optimizaciones
Write-Host ""
Write-Host "  ─── OPTIMIZACIONES ACTIVAS ────────────────────────" -ForegroundColor Gray

# Turbo Boost
$turboState = Get-Content (Join-Path $RescueDir "turbo_state.json") -Raw -ErrorAction SilentlyContinue
if ($turboState) {
    $turbo = $turboState | ConvertFrom-Json
    if ($turbo.Active) {
        Write-Host "  🔥 Turbo Boost:    ACTIVO (desde $($turbo.Timestamp))" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚪ Turbo Boost:    Inactivo" -ForegroundColor Gray
}

# Gaming Mode
$gamingState = Get-Content (Join-Path $RescueDir "gaming_state.json") -Raw -ErrorAction SilentlyContinue
if ($gamingState) {
    $gaming = $gamingState | ConvertFrom-Json
    if ($gaming.Active) {
        Write-Host "  🎮 Gaming Mode:    ACTIVO (desde $($gaming.Timestamp))" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚪ Gaming Mode:    Inactivo" -ForegroundColor Gray
}

# Network Optimizer
$netState = Get-Content (Join-Path $RescueDir "network_state.json") -Raw -ErrorAction SilentlyContinue
if ($netState) {
    $net = $netState | ConvertFrom-Json
    if ($net.Active) {
        Write-Host "  🌐 Network:        OPTIMIZADO (desde $($net.Timestamp))" -ForegroundColor Cyan
    }
} else {
    Write-Host "  ⚪ Network:        Por defecto" -ForegroundColor Gray
}

# WU Blocker
$wuState = Get-Content (Join-Path $RescueDir "wu_blocker_state.json") -Raw -ErrorAction SilentlyContinue
if ($wuState) {
    $wu = $wuState | ConvertFrom-Json
    if ($wu.Blocked) {
        Write-Host "  🔒 Windows Update: BLOQUEADO (desde $($wu.Timestamp))" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚪ Windows Update: Activo" -ForegroundColor Gray
}

# Diagnóstico rápido
Write-Host ""
Write-Host "  ─── DIAGNÓSTICO ───────────────────────────────────" -ForegroundColor Gray
$issues = 0
if ($pctRAM -gt 85) { Write-Host "  🔴 RAM crítica ($pctRAM%) → Ejecutá Memory Optimizer" -ForegroundColor Red; $issues++ }
if ($freeRAM -lt 1.5) { Write-Host "  🔴 RAM libre baja (${freeRAM} GB) → Cerrá apps o ejecutá Memory Optimizer" -ForegroundColor Red; $issues++ }
if ($cpuLoad -gt 80) { Write-Host "  🟡 CPU alta ($cpuLoad%) → Cerrá procesos pesados" -ForegroundColor Yellow; $issues++ }
if ($pctDisk -gt 90) { Write-Host "  🔴 Disco lleno ($pctDisk%) → Ejecutá Disk Cleanup" -ForegroundColor Red; $issues++ }
if ($startupCount -gt 10) { Write-Host "  🟡 Muchos programas de inicio ($startupCount) → Ejecutá Startup Cleaner" -ForegroundColor Yellow; $issues++ }
if ($runningSvc -gt 120) { Write-Host "  🟡 Muchos servicios ($runningSvc) → Ejecutá Services Optimizer" -ForegroundColor Yellow; $issues++ }

if ($issues -eq 0) {
    Write-Host "  ✅ ¡Todo OK! Sin problemas detectados." -ForegroundColor Green
}

Write-Host ""
Write-Host "  ─── QUICK ACTIONS ─────────────────────────────────" -ForegroundColor Gray
Write-Host "  [1] Benchmark completo  [2] Optimizar todo  [3] Turbo Boost" -ForegroundColor DarkGray
Write-Host "  [4] Gaming Mode         [5] Network         [6] Disk Cleanup" -ForegroundColor DarkGray
Write-Host ""
