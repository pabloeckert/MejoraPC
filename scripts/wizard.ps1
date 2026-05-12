# ============================================================
# WIZARD - Modo guiado para principiantes
# ============================================================
# Guía paso a paso sin tecnicismos. Ideal para la primera vez.
# ============================================================

. "$PSScriptRoot\config.ps1"
Assert-Admin

function Show-WizardStep {
    param([string]$Title, [string]$Description, [string]$Icon = "📌")
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           🧙 WIZARD — Modo Guiado                    ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  $Icon $Title" -ForegroundColor White
    Write-Host "  $Description" -ForegroundColor Gray
    Write-Host ""
}

function Wait-User {
    Write-Host ""
    Write-Host "  Presioná ENTER para continuar..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# ============================================================
# PASO 1: Bienvenida
# ============================================================
function Wizard-Welcome {
    Show-WizardStep "¡Bienvenido!" "Este asistente te va a ayudar a optimizar tu notebook paso a paso." "👋"
    
    Write-Host "  Tu notebook va a funcionar mejor después de esto." -ForegroundColor White
    Write-Host ""
    Write-Host "  Lo que vamos a hacer:" -ForegroundColor Yellow
    Write-Host "    1️⃣  Ver cómo está tu notebook ahora" -ForegroundColor White
    Write-Host "    2️⃣  Crear un respaldo (por las dudas)" -ForegroundColor White
    Write-Host "    3️⃣  Limpiar programas basura" -ForegroundColor White
    Write-Host "    4️⃣  Optimizar para que vaya más rápido" -ForegroundColor White
    Write-Host "    5️⃣  Verificar que todo quedó bien" -ForegroundColor White
    Write-Host ""
    Write-Host "  ⏱️  Tiempo estimado: 5-10 minutos" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ¿Empezamos?" -ForegroundColor Green
    Write-Host "    [1] Sí, empezar" -ForegroundColor Green
    Write-Host "    [0] No, salir" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "  Opción"
    if ($choice -eq "0") {
        Write-Host ""
        Write-Host "  ¡Chau! Podés volver cuando quieras. 👋" -ForegroundColor Cyan
        exit 0
    }
}

# ============================================================
# PASO 2: Diagnóstico
# ============================================================
function Wizard-Diagnostic {
    Show-WizardStep "Paso 1 de 5: Diagnóstico" "Vamos a ver cómo está tu notebook ahora." "🔍"
    
    Write-Host "  Analizando tu sistema..." -ForegroundColor White
    Write-Host ""
    
    # RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $pctRAM = [math]::Round((($totalRAM - $freeRAM) / $totalRAM) * 100, 1)
    
    $ramEmoji = if ($pctRAM -gt 85) { "🔴" } elseif ($pctRAM -gt 70) { "🟡" } else { "🟢" }
    Write-Host "  $ramEmoji Memoria (RAM): ${freeRAM} GB libre de ${totalRAM} GB ($pctRAM% usado)" -ForegroundColor $(if ($pctRAM -gt 85) { "Red" } elseif ($pctRAM -gt 70) { "Yellow" } else { "Green" })
    
    # CPU
    $cpu = Get-CimInstance Win32_Processor
    $cpuLoad = $cpu.LoadPercentage
    $cpuEmoji = if ($cpuLoad -gt 80) { "🔴" } elseif ($cpuLoad -gt 50) { "🟡" } else { "🟢" }
    Write-Host "  $cpuEmoji Procesador (CPU): $cpuLoad% de carga" -ForegroundColor $(if ($cpuLoad -gt 80) { "Red" } elseif ($cpuLoad -gt 50) { "Yellow" } else { "Green" })
    
    # Disco
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1
    $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 0)
    $totalDisk = [math]::Round($disk.Size / 1GB, 0)
    $pctDisk = [math]::Round((($totalDisk - $freeDisk) / $totalDisk) * 100, 1)
    $diskEmoji = if ($pctDisk -gt 90) { "🔴" } elseif ($pctDisk -gt 80) { "🟡" } else { "🟢" }
    Write-Host "  $diskEmoji Disco: ${freeDisk} GB libre de ${totalDisk} GB ($pctDisk% usado)" -ForegroundColor $(if ($pctDisk -gt 90) { "Red" } elseif ($pctDisk -gt 80) { "Yellow" } else { "Green" })
    
    # Startup
    $startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Measure-Object).Count
    $startEmoji = if ($startupCount -gt 10) { "🟡" } else { "🟢" }
    Write-Host "  $startEmoji Programas de inicio: $startupCount" -ForegroundColor $(if ($startupCount -gt 10) { "Yellow" } else { "Green" })
    
    # Servicios
    $runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
    $svcEmoji = if ($runningSvc -gt 100) { "🟡" } else { "🟢" }
    Write-Host "  $svcEmoji Servicios activos: $runningSvc" -ForegroundColor $(if ($runningSvc -gt 100) { "Yellow" } else { "Green" })
    
    # Tipo de disco
    $diskType = if ($Global:IsSSD) { "SSD ✅" } else { "HDD ⚠️" }
    Write-Host "  💾 Tipo de disco: $diskType" -ForegroundColor $(if ($Global:IsSSD) { "Green" } else { "Yellow" })
    
    # Guardar para comparar después
    $Global:WizardBefore = @{
        RAM_Free = $freeRAM
        RAM_Pct = $pctRAM
        CPU = $cpuLoad
        Disk_Free = $freeDisk
        Disk_Pct = $pctDisk
        Startup = $startupCount
        Services = $runningSvc
    }
    
    Write-Host ""
    if ($pctRAM -gt 80 -or $startupCount -gt 10 -or $runningSvc -gt 100) {
        Write-Host "  📊 Tu notebook necesita una limpieza. ¡Vamos a hacerlo!" -ForegroundColor Yellow
    } else {
        Write-Host "  📊 Tu notebook está bastante bien, pero podemos mejorarlo un poco." -ForegroundColor Green
    }
    
    Wait-User
}

# ============================================================
# PASO 3: Rescue Point
# ============================================================
function Wizard-Rescue {
    Show-WizardStep "Paso 2 de 5: Respaldo" "Antes de tocar nada, vamos a crear un respaldo de seguridad." "💾"
    
    Write-Host "  Si algo sale mal (muy raro), podemos restaurar todo." -ForegroundColor White
    Write-Host ""
    
    & "$ScriptsDir\rescue.ps1" -Action create -Name "wizard"
    
    Write-Host ""
    Write-Host "  ✅ Respaldo creado. ¡Estamos seguros!" -ForegroundColor Green
    
    Wait-User
}

# ============================================================
# PASO 4: Limpieza
# ============================================================
function Wizard-Cleanup {
    Show-WizardStep "Paso 3 de 5: Limpieza" "Vamos a eliminar programas basura que no necesitás." "🗑️"
    
    Write-Host "  Esto va a:" -ForegroundColor White
    Write-Host "    • Eliminar apps preinstaladas que no usás (Candy Crush, TikTok, etc.)" -ForegroundColor Gray
    Write-Host "    • Limpiar programas que se ejecutan al inicio" -ForegroundColor Gray
    Write-Host "    • Limpiar archivos temporales" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ⚠️  NO se elimina nada importante." -ForegroundColor Yellow
    Write-Host "  Todas las apps se pueden reinstalar desde Microsoft Store." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ¿Querés limpiar?" -ForegroundColor White
    Write-Host "    [1] Sí, limpiar todo" -ForegroundColor Green
    Write-Host "    [2] Solo lo seguro (recomendado)" -ForegroundColor Yellow
    Write-Host "    [0] Saltar" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "  Opción"
    
    if ($choice -eq "0") {
        Write-Info "Limpieza saltada."
        Wait-User
        return
    }
    
    Write-Host ""
    Write-Host "  Limpiando..." -ForegroundColor White
    
    # Debloater
    Write-Host ""
    Write-Host "  ─── ELIMINANDO APPS BASURA ───" -ForegroundColor Cyan
    & "$ScriptsDir\debloater.ps1"
    
    # Startup
    Write-Host ""
    Write-Host "  ─── LIMPIANDO INICIO ───" -ForegroundColor Cyan
    & "$ScriptsDir\startup-cleaner.ps1"
    
    # Disk cleanup
    Write-Host ""
    Write-Host "  ─── LIMPIANDO ARCHIVOS TEMPORALES ───" -ForegroundColor Cyan
    & "$ScriptsDir\disk-cleanup.ps1"
    
    Write-Host ""
    Write-Host "  ✅ Limpieza completada." -ForegroundColor Green
    
    Wait-User
}

# ============================================================
# PASO 5: Optimización
# ============================================================
function Wizard-Optimize {
    Show-WizardStep "Paso 4 de 5: Optimización" "Ahora vamos a hacer que tu notebook vaya más rápido." "⚡"
    
    Write-Host "  Esto va a:" -ForegroundColor White
    Write-Host "    • Optimizar servicios de Windows" -ForegroundColor Gray
    Write-Host "    • Reducir efectos visuales (hace que vaya más fluido)" -ForegroundColor Gray
    Write-Host "    • Liberar memoria RAM" -ForegroundColor Gray
    Write-Host "    • Optimizar el plan de energía" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ¿Querés optimizar?" -ForegroundColor White
    Write-Host "    [1] Sí, optimizar" -ForegroundColor Green
    Write-Host "    [0] Saltar" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "  Opción"
    
    if ($choice -eq "0") {
        Write-Info "Optimización saltada."
        Wait-User
        return
    }
    
    Write-Host ""
    
    # Services
    Write-Host "  ─── OPTIMIZANDO SERVICIOS ───" -ForegroundColor Cyan
    & "$ScriptsDir\services.ps1"
    
    # Performance
    Write-Host ""
    Write-Host "  ─── AJUSTANDO RENDIMIENTO ───" -ForegroundColor Cyan
    & "$ScriptsDir\performance.ps1"
    
    # Memory
    Write-Host ""
    Write-Host "  ─── LIBERANDO MEMORIA ───" -ForegroundColor Cyan
    & "$ScriptsDir\memory.ps1"
    
    Write-Host ""
    Write-Host "  ✅ Optimización completada." -ForegroundColor Green
    
    Wait-User
}

# ============================================================
# PASO 6: Resultado
# ============================================================
function Wizard-Result {
    Show-WizardStep "Paso 5 de 5: Resultado" "¡Listo! Veamos cómo quedó tu notebook." "🎉"
    
    $os = Get-CimInstance Win32_OperatingSystem
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $pctRAM = [math]::Round((($totalRAM - $freeRAM) / $totalRAM) * 100, 1)
    $cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
    $runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
    
    Write-Host "  ─── ANTES ───" -ForegroundColor Yellow
    if ($Global:WizardBefore) {
        Write-Host "    RAM libre:     $($Global:WizardBefore.RAM_Free) GB" -ForegroundColor Gray
        Write-Host "    Servicios:     $($Global:WizardBefore.Services)" -ForegroundColor Gray
        Write-Host "    CPU:           $($Global:WizardBefore.CPU)%" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  ─── DESPUÉS ───" -ForegroundColor Green
    Write-Host "    RAM libre:     ${freeRAM} GB" -ForegroundColor White
    Write-Host "    Servicios:     $runningSvc" -ForegroundColor White
    Write-Host "    CPU:           $cpuLoad%" -ForegroundColor White
    
    if ($Global:WizardBefore) {
        $ramDiff = [math]::Round($freeRAM - $Global:WizardBefore.RAM_Free, 2)
        $svcDiff = $Global:WizardBefore.Services - $runningSvc
        
        Write-Host ""
        Write-Host "  ─── MEJORA ───" -ForegroundColor Cyan
        if ($ramDiff -gt 0) {
            Write-Host "    RAM liberada:  +${ramDiff} GB 🎉" -ForegroundColor Green
        }
        if ($svcDiff -gt 0) {
            Write-Host "    Servicios:     -$svcDiff detenidos" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "  ─── PRÓXIMOS PASOS ───" -ForegroundColor Cyan
    Write-Host "    1. Reiniciá tu notebook para aplicar todos los cambios" -ForegroundColor White
    Write-Host "    2. Si algo no funciona, ejecutá: [9] EMERGENCIA" -ForegroundColor White
    Write-Host "    3. Para máximo rendimiento: [T] Turbo Boost" -ForegroundColor White
    Write-Host "    4. Para gaming: [G] Gaming Mode" -ForegroundColor White
    Write-Host ""
    Write-Host "  🎉 ¡Tu notebook está optimizada!" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "  ¿Reiniciar ahora?" -ForegroundColor Yellow
    Write-Host "    [1] Sí, reiniciar" -ForegroundColor Green
    Write-Host "    [0] No, después" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "  Opción"
    
    if ($choice -eq "1") {
        Log "Wizard completado, reiniciando..."
        Restart-Computer -Force
    } else {
        Write-Info "Recordá reiniciar más tarde."
    }
}

# ============================================================
# MAIN
# ============================================================
Wizard-Welcome
Wizard-Diagnostic
Wizard-Rescue
Wizard-Cleanup
Wizard-Optimize
Wizard-Result

Write-Host ""
Write-Host "  ¡Gracias por usar MejoraNotebook! 👋" -ForegroundColor Cyan
Write-Host ""
Log "Wizard completado"
