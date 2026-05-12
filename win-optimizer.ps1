# ============================================================
#  WIN OPTIMIZER v1.8.0
#  Optimizador de Windows 11 - BANGHO MAX L5
# ============================================================
#  ⚠️  Ejecutar como Administrador
# ============================================================

param(
    [switch]$Silent,
    [switch]$DryRun,
    [switch]$WithGaming
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsDir = Join-Path $ScriptDir "scripts"

# Admin check
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  ⚠️  Este script requiere permisos de administrador." -ForegroundColor Red
    Write-Host "  Click derecho -> 'Ejecutar como administrador'" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# Modo silencioso: ejecutar todo sin prompts y salir
if ($Silent) {
    Run-Silent
    exit 0
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           WIN OPTIMIZER v1.8.0                       ║" -ForegroundColor Cyan
    Write-Host "  ║           Windows 11 - BANGHO MAX L5                 ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── DIAGNÓSTICO ───────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [1] 🔍  Benchmark completo (ver estado del sistema)" -ForegroundColor White
    Write-Host "  [Q] 🏥  Health Check rápido (resumen visual)" -ForegroundColor White
    Write-Host ""
    Write-Host "  ─── 🧙 PRINCIPIANTE ───────────────────────────────────" -ForegroundColor Magenta
    Write-Host "  [Z] 🧙  Wizard guiado (paso a paso, sin tecnicismos)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  ─── OPTIMIZACIÓN ──────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [2] 💾  Crear Rescue Point (respaldo antes de tocar)" -ForegroundColor Green
    Write-Host "  [3] 🗑️  Debloater (eliminar apps basura)" -ForegroundColor Yellow
    Write-Host "  [4] ⚡  Startup Cleaner (limpiar inicio)" -ForegroundColor Yellow
    Write-Host "  [5] 🔧  Services Optimizer (optimizar servicios)" -ForegroundColor Yellow
    Write-Host "  [6] 🚀  Performance Tweaks (rendimiento + efectos)" -ForegroundColor Yellow
    Write-Host "  [7] 💾  Memory Optimizer (liberar RAM)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ─── TODO EN UNO ───────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [A] 🔥  OPTIMIZAR TODO (pasos 3-7 automático)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ─── TURBO BOOST ───────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [T] 🔥🔥🔥  ACTIVAR TURBO BOOST (máximo rendimiento)" -ForegroundColor Red
    Write-Host "  [R] 🔄  Revertir Turbo Boost (volver a normal)" -ForegroundColor Cyan
    Write-Host "  [S] 📊  Status Turbo Boost" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── GAMING ────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [G] 🎮  ACTIVAR Gaming Mode (optimizado para jugar)" -ForegroundColor Green
    Write-Host "  [H] 🔄  Revertir Gaming Mode" -ForegroundColor Cyan
    Write-Host "  [J] 📊  Status Gaming Mode" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── RESTAURAR ─────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [8] 🔄  Restaurar Rescue Point" -ForegroundColor Green
    Write-Host "  [9] 🚨  EMERGENCIA - Restaurar TODO" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ─── PERFILES ──────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [P] 📂  Perfiles (guardar/cargar configuraciones)" -ForegroundColor Cyan
    Write-Host "  [W] 🔒  Windows Update Blocker (pausar/reanudar)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── RED ───────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [N] 🌐  Network Optimizer (optimizar TCP/DNS/latencia)" -ForegroundColor Cyan
    Write-Host "  [M] 🔄  Revertir Network Optimizer" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── EXTRAS ────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [V] 🔧  Driver Updater (escanear drivers)" -ForegroundColor Cyan
    Write-Host "  [Y] 📥  Actualizar MejoraNotebook desde GitHub" -ForegroundColor Cyan
    Write-Host "  [C] 📊  Comparar benchmarks (antes/después)" -ForegroundColor Cyan
    Write-Host "  [O] 📦  Paquete offline (sin internet)" -ForegroundColor Cyan
    Write-Host "  [I] 📊  Generar reporte HTML" -ForegroundColor Cyan
    Write-Host "  [X] 📊  Reporte completo (benchmark + HTML + abrir)" -ForegroundColor Cyan
    Write-Host "  [K] ⏰  Optimización programada (benchmark semanal)" -ForegroundColor Cyan
    Write-Host "  [U] 🗑️  Desinstalador (restaurar todo + eliminar)" -ForegroundColor Red
    Write-Host "  [D] 🧪  Toggle Dry-RUN $(if($Global:DryRun){'(ACTIVO ✅)'}else{'(off)'})" -ForegroundColor $(if($Global:DryRun){"Yellow"}else{"Gray"})
    Write-Host "  [L] 📄  Ver log de esta sesión" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [0] ❌  Salir" -ForegroundColor Gray
    Write-Host ""
}

function Run-OptimizeAll {
    Write-Header "🔥 OPTIMIZACIÓN COMPLETA"
    Write-Host "  Esto va a ejecutar:" -ForegroundColor White
    Write-Host "    1. Debloater (eliminar bloatware)" -ForegroundColor Gray
    Write-Host "    2. Startup Cleaner (limpiar inicio)" -ForegroundColor Gray
    Write-Host "    3. Services Optimizer (optimizar servicios)" -ForegroundColor Gray
    Write-Host "    4. Performance Tweaks (rendimiento)" -ForegroundColor Gray
    Write-Host "    5. Memory Optimizer (liberar RAM)" -ForegroundColor Gray
    Write-Host ""
    Write-Warn "Se creará un Rescue Point antes de empezar."
    Write-Host ""
    Write-Host "  [1] Ejecutar normalmente" -ForegroundColor Green
    Write-Host "  [2] Ejecutar en modo DRY-RUN (simular sin aplicar)" -ForegroundColor Yellow
    Write-Host "  [0] Cancelar" -ForegroundColor Red
    Write-Host ""
    $mode = Read-Host "  Opción"
    
    if ($mode -eq "0") {
        Write-Info "Cancelado."
        return
    }
    
    $isDryRun = ($mode -eq "2")
    if ($isDryRun) {
        Set-DryRun $true
    }
    
    $confirm = Read-Host "  Escribí SI para confirmar"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    
    Run-OptimizeAll-Inner
}

function Run-OptimizeAll-Inner {
    # Rescue point primero
    & "$ScriptsDir\rescue.ps1" -Action create -Name "pre-optimize-all"
    Write-Host ""
    
    # Ejecutar cada paso
    $steps = @("debloater.ps1", "startup-cleaner.ps1", "services.ps1", "performance.ps1", "memory.ps1", "disk-cleanup.ps1")
    $stepNames = @("Debloater", "Startup Cleaner", "Services", "Performance", "Memory", "Disk Cleanup")
    
    for ($i = 0; $i -lt $steps.Count; $i++) {
        Write-Host ""
        Write-Host "  ─── PASO $($i+1)/$($steps.Count): $($stepNames[$i]) ──────" -ForegroundColor Cyan
        Write-Host ""
        try {
            & "$ScriptsDir\$($steps[$i])"
        } catch {
            Write-Error "Error en $($stepNames[$i]): $_"
        }
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
    Write-Header "✅ OPTIMIZACIÓN COMPLETA FINALIZADA"
    Write-Success "Todos los pasos completados."
    Write-Info "Se recomienda REINICIAR para aplicar todos los cambios."
    Show-LogPath
}

# ============================================================
# MODO SILENCIOSO — ejecuta todo sin prompts
# ============================================================
function Run-Silent {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║           WIN OPTIMIZER — MODO SILENCIOSO            ║" -ForegroundColor Magenta
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    
    if ($DryRun) {
        Set-DryRun $true
        Write-Info "Modo DRY-RUN activado — no se aplicarán cambios reales."
        Write-Host ""
    }
    
    # Benchmark antes
    Write-Header "📊 BENCHMARK ANTES"
    & "$ScriptsDir\benchmark.ps1" -Mode antes
    
    # Optimización completa
    Run-OptimizeAll-Inner
    
    # Gaming mode (opcional)
    if ($WithGaming) {
        Write-Host ""
        Write-Header "🎮 ACTIVANDO GAMING MODE"
        & "$ScriptsDir\gaming-mode.ps1" -Action activate
    }
    
    # Benchmark después
    Write-Host ""
    Write-Header "📊 BENCHMARK DESPUÉS"
    & "$ScriptsDir\benchmark.ps1" -Mode despues
    
    Write-Host ""
    Write-Header "✅ MODO SILENCIOSO COMPLETADO"
    Write-Success "Todas las optimizaciones aplicadas."
    if (!$DryRun) {
        Write-Info "Se recomienda REINICIAR para aplicar todos los cambios."
    }
    Show-LogPath
}

# Loop principal
do {
    Show-Menu
    $choice = Read-Host "  Seleccioná una opción"
    
    switch ($choice.ToUpper()) {
        "1" { & "$ScriptsDir\benchmark.ps1" -Mode rapido; pause }
        "Q" { & "$ScriptsDir\health-check.ps1"; pause }
        "2" { & "$ScriptsDir\rescue.ps1" -Action create -Name "manual"; pause }
        "3" { & "$ScriptsDir\debloater.ps1"; pause }
        "4" { & "$ScriptsDir\startup-cleaner.ps1"; pause }
        "5" { & "$ScriptsDir\services.ps1"; pause }
        "6" { & "$ScriptsDir\performance.ps1"; pause }
        "7" { & "$ScriptsDir\memory.ps1"; pause }
        "A" { Run-OptimizeAll; pause }
        "T" { & "$ScriptsDir\turbo-boost.ps1" -Action activate; pause }
        "R" { & "$ScriptsDir\turbo-boost.ps1" -Action revert; pause }
        "S" { & "$ScriptsDir\turbo-boost.ps1" -Action status; pause }
        "G" { & "$ScriptsDir\gaming-mode.ps1" -Action activate; pause }
        "H" { & "$ScriptsDir\gaming-mode.ps1" -Action revert; pause }
        "J" { & "$ScriptsDir\gaming-mode.ps1" -Action status; pause }
        "8" { & "$ScriptsDir\rescue.ps1" -Action restore; pause }
        "9" { & "$ScriptsDir\emergencia.ps1"; pause }
        "P" { 
            Write-Host ""
            Write-Host "  [1] Listar perfiles" -ForegroundColor Cyan
            Write-Host "  [2] Guardar perfil actual" -ForegroundColor Green
            Write-Host "  [3] Cargar perfil" -ForegroundColor Yellow
            Write-Host "  [4] Eliminar perfil" -ForegroundColor Red
            Write-Host "  [0] Volver" -ForegroundColor Gray
            Write-Host ""
            $pChoice = Read-Host "  Opción"
            switch ($pChoice) {
                "1" { & "$ScriptsDir\profiles.ps1" -Action list }
                "2" { & "$ScriptsDir\profiles.ps1" -Action save }
                "3" { & "$ScriptsDir\profiles.ps1" -Action load }
                "4" { & "$ScriptsDir\profiles.ps1" -Action delete }
            }
            pause
        }
        "W" {
            Write-Host ""
            Write-Host "  [1] Ver status de Windows Update" -ForegroundColor Cyan
            Write-Host "  [2] Bloquear Windows Update" -ForegroundColor Red
            Write-Host "  [3] Desbloquear Windows Update" -ForegroundColor Green
            Write-Host "  [0] Volver" -ForegroundColor Gray
            Write-Host ""
            $wChoice = Read-Host "  Opción"
            switch ($wChoice) {
                "1" { & "$ScriptsDir\wu-blocker.ps1" -Action status }
                "2" { & "$ScriptsDir\wu-blocker.ps1" -Action block }
                "3" { & "$ScriptsDir\wu-blocker.ps1" -Action unblock }
            }
            pause
        }
        "N" { & "$ScriptsDir\network-optimizer.ps1" -Action optimize; pause }
        "M" { & "$ScriptsDir\network-optimizer.ps1" -Action revert; pause }
        "V" { & "$ScriptsDir\driver-updater.ps1" -Action scan; pause }
        "Y" { & "$ScriptsDir\updater.ps1" -Action update; pause }
        "C" { & "$ScriptsDir\compare.ps1" -Action compare; pause }
        "O" { & "$ScriptsDir\offline-pack.ps1" -Action export; pause }
        "Z" { & "$ScriptsDir\wizard.ps1"; pause }
        "X" {
            Write-Header "📊 REPORTE COMPLETO"
            & "$ScriptsDir\benchmark.ps1" -Mode completo
            pause
        }
        "U" { & "$ScriptsDir\uninstall-tool.ps1"; pause }
        "D" {
            Set-DryRun (!$Global:DryRun)
            if ($Global:DryRun) {
                Write-Success "Dry-RUN activado — los scripts simularán sin aplicar cambios."
            } else {
                Write-Info "Dry-RUN desactivado — los scripts aplicarán cambios reales."
            }
            Start-Sleep -Seconds 2
        }
        "L" { Show-RecentLogs -Lines 30; pause }
        "I" { & "$ScriptsDir\html-report.ps1"; pause }
        "K" {
            Write-Host ""
            Write-Host "  [1] Ver status" -ForegroundColor Cyan
            Write-Host "  [2] Instalar (benchmark cada lunes)" -ForegroundColor Green
            Write-Host "  [3] Eliminar" -ForegroundColor Red
            Write-Host "  [0] Volver" -ForegroundColor Gray
            Write-Host ""
            $kChoice = Read-Host "  Opción"
            switch ($kChoice) {
                "1" { & "$ScriptsDir\scheduler.ps1" -Action status }
                "2" { & "$ScriptsDir\scheduler.ps1" -Action install }
                "3" { & "$ScriptsDir\scheduler.ps1" -Action uninstall }
            }
            pause
        }
        "0" { 
            Write-Host ""
            Write-Host "  ¡Chau! 👋" -ForegroundColor Cyan
            Write-Host ""
            break 
        }
        default {
            Write-Host "  Opción inválida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "0")
