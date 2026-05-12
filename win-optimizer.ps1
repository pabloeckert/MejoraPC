# ============================================================
#  WIN OPTIMIZER v1.0
#  Optimizador de Windows 11 - BANGHO MAX L5
# ============================================================
#  ⚠️  Ejecutar como Administrador
# ============================================================

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

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           WIN OPTIMIZER v1.0                         ║" -ForegroundColor Cyan
    Write-Host "  ║           Windows 11 - BANGHO MAX L5                 ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ─── DIAGNÓSTICO ───────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [1] 🔍  Benchmark completo (ver estado del sistema)" -ForegroundColor White
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
    Write-Host "  ─── RESTAURAR ─────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  [8] 🔄  Restaurar Rescue Point" -ForegroundColor Green
    Write-Host "  [9] 🚨  EMERGENCIA - Restaurar TODO" -ForegroundColor Red
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
    $confirm = Read-Host "  Escribí SI para confirmar"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    
    # Rescue point primero
    & "$ScriptsDir\rescue.ps1" -Action create -Name "pre-optimize-all"
    Write-Host ""
    
    # Ejecutar cada paso
    $steps = @("debloater.ps1", "startup-cleaner.ps1", "services.ps1", "performance.ps1", "memory.ps1")
    $stepNames = @("Debloater", "Startup Cleaner", "Services", "Performance", "Memory")
    
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
    Write-Host ""
    $reboot = Read-Host "  ¿Reiniciar ahora? [S/N]"
    if ($reboot -eq "S" -or $reboot -eq "s") {
        Restart-Computer -Force
    }
}

# Loop principal
do {
    Show-Menu
    $choice = Read-Host "  Seleccioná una opción"
    
    switch ($choice.ToUpper()) {
        "1" { & "$ScriptsDir\benchmark.ps1" -Mode rapido; pause }
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
        "8" { & "$ScriptsDir\rescue.ps1" -Action restore; pause }
        "9" { & "$ScriptsDir\emergencia.ps1"; pause }
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
