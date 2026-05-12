# ============================================================
#  WIN OPTIMIZER v3.0.0
#  Optimizador de Windows 11 - BANGHO MAX L5
#  Diseño: Dashboard + Navegación por Categorías
# ============================================================

param(
    [switch]$Silent,
    [switch]$DryRun,
    [switch]$WithGaming
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptsDir = Join-Path $ScriptDir "scripts"

# ── Admin check ─────────────────────────────────────────────
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

# ── Cargar config compartida ────────────────────────────────
. "$ScriptsDir\config.ps1"

# ── Modo silencioso ─────────────────────────────────────────
if ($Silent) {
    Run-Silent
    exit 0
}

# ============================================================
#  PALETA DE DISEÑO
# ============================================================
$C = @{
    Primary    = "Cyan"
    Accent     = "Yellow"
    Success    = "Green"
    Danger     = "Red"
    Warning    = "DarkYellow"
    Muted      = "DarkGray"
    Text       = "White"
    Subtle     = "Gray"
    Category   = "Cyan"
    Highlight  = "Magenta"
    Header     = "Cyan"
}

# ============================================================
#  COMPONENTES DE UI
# ============================================================

function Draw-Box {
    param([string]$Text, [string]$Color = "Cyan", [int]$Width = 57)
    $pad = $Width - $Text.Length - 4
    $padding = " " * [Math]::Max(0, $pad)
    Write-Host "  ╔$('═' * ($Width - 2))╗" -ForegroundColor $Color
    Write-Host "  ║  $Text$padding║" -ForegroundColor $Color
    Write-Host "  ╚$('═' * ($Width - 2))╝" -ForegroundColor $Color
}

function Draw-Separator {
    param([string]$Label = "", [string]$Color = "DarkGray")
    if ($Label) {
        $line = "─" * 3
        $rest = "─" * (48 - $Label.Length)
        Write-Host "  $line $Label $rest" -ForegroundColor $Color
    } else {
        Write-Host "  $('─' * 55)" -ForegroundColor $Color
    }
}

function Draw-StatusBar {
    param([string]$Label, [int]$Percent, [string]$Color = "Green")
    $barWidth = 20
    $filled = [Math]::Round($Percent / 100 * $barWidth)
    $empty = $barWidth - $filled
    $bar = "█" * $filled + "░" * $empty
    $pctStr = "$Percent%".PadLeft(4)
    Write-Host "  $Label " -ForegroundColor $C.Subtle -NoNewline
    Write-Host "[$bar]" -ForegroundColor $Color -NoNewline
    Write-Host " $pctStr" -ForegroundColor $Color
}

function Draw-MenuItem {
    param([string]$Key, [string]$Icon, [string]$Text, [string]$Color = "White", [string]$Desc = "")
    Write-Host "  [" -ForegroundColor $C.Muted -NoNewline
    Write-Host "$Key" -ForegroundColor $C.Accent -NoNewline
    Write-Host "]" -ForegroundColor $C.Muted -NoNewline
    Write-Host " $Icon  $Text" -ForegroundColor $Color
    if ($Desc) {
        Write-Host "       $Desc" -ForegroundColor $C.Muted
    }
}

function Draw-BackOption {
    Write-Host ""
    Write-Host "  [" -ForegroundColor $C.Muted -NoNewline
    Write-Host "0" -ForegroundColor $C.Accent -NoNewline
    Write-Host "]" -ForegroundColor $C.Muted -NoNewline
    Write-Host " ←  Volver al menú principal" -ForegroundColor $C.Subtle
}

function Draw-ExitOption {
    Write-Host ""
    Write-Host "  [" -ForegroundColor $C.Muted -NoNewline
    Write-Host "Q" -ForegroundColor $C.Danger -NoNewline
    Write-Host "]" -ForegroundColor $C.Muted -NoNewline
    Write-Host " ✕  Salir" -ForegroundColor $C.Subtle
}

function Wait-Input {
    Write-Host ""
    Write-Host "  ───────────────────────────────────────────────────────" -ForegroundColor $C.Muted
    $script:choice = Read-Host "  Elegí una opción"
}

# ============================================================
#  DASHBOARD — INFORMACIÓN DEL SISTEMA
# ============================================================

function Get-SystemDashboard {
    # CPU
    $cpu = Get-CimInstance Win32_Processor
    $cpuLoad = $cpu.LoadPercentage
    $cpuName = ($cpu.Name -replace '\s+', ' ').Trim()

    # RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $pctRAM = [math]::Round(($usedRAM / $totalRAM) * 100, 0)

    # Disco
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1
    $totalDisk = [math]::Round($disk.Size / 1GB, 0)
    $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 0)
    $pctDisk = [math]::Round((($totalDisk - $freeDisk) / $totalDisk) * 100, 0)

    # Servicios
    $runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
    $totalSvc = (Get-Service | Measure-Object).Count

    # Startup
    $startupCount = (Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Measure-Object).Count

    # Procesos
    $procCount = (Get-Process | Measure-Object).Count

    return @{
        CPULoad = $cpuLoad
        CPUName = $cpuName
        RAMTotal = $totalRAM
        RAMFree = $freeRAM
        RAMUsed = $usedRAM
        RAMPct = $pctRAM
        DiskTotal = $totalDisk
        DiskFree = $freeDisk
        DiskPct = $pctDisk
        SvcRunning = $runningSvc
        SvcTotal = $totalSvc
        StartupCount = $startupCount
        ProcCount = $procCount
    }
}

function Get-StatusColor {
    param([int]$Percent, [int]$WarnThreshold = 70, [int]$CritThreshold = 85)
    if ($Percent -ge $CritThreshold) { return "Red" }
    if ($Percent -ge $WarnThreshold) { return "Yellow" }
    return "Green"
}

function Get-StatusIcon {
    param([int]$Percent, [int]$WarnThreshold = 70, [int]$CritThreshold = 85)
    if ($Percent -ge $CritThreshold) { return "🔴" }
    if ($Percent -ge $WarnThreshold) { return "🟡" }
    return "🟢"
}

function Show-Dashboard {
    $sys = Get-SystemDashboard

    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor $C.Header
    Write-Host "  ║                                                       ║" -ForegroundColor $C.Header
    Write-Host "  ║   ██╗   ██╗██╗███╗   ██╗     ██████╗ ██████╗████████╗║" -ForegroundColor $C.Header
    Write-Host "  ║   ██║   ██║██║████╗  ██║    ██╔════╝██╔══██╚══██╔══╝║" -ForegroundColor $C.Header
    Write-Host "  ║   ██║   ██║██║██╔██╗ ██║    ██║     ██████╔╝  ██║   ║" -ForegroundColor $C.Header
    Write-Host "  ║   ╚██╗ ██╔╝██║██║╚██╗██║    ██║     ██╔══██╗  ██║   ║" -ForegroundColor $C.Header
    Write-Host "  ║    ╚████╔╝ ██║██║ ╚████║    ╚██████╗██║  ██║  ██║   ║" -ForegroundColor $C.Header
    Write-Host "  ║     ╚═══╝  ╚═╝╚═╝  ╚═══╝     ╚═════╝╚═╝  ╚═╝  ╚═╝   ║" -ForegroundColor $C.Header
    Write-Host "  ║                                                       ║" -ForegroundColor $C.Header
    Write-Host "  ║          O P T I M I Z E R   v3.0.0                  ║" -ForegroundColor $C.Header
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor $C.Header
    Write-Host ""

    # ── Panel de estado del sistema ──────────────────────────
    Write-Host "  ┌─── ESTADO DEL SISTEMA ──────────────────────────────┐" -ForegroundColor $C.Subtle

    # CPU
    $cpuColor = Get-StatusColor $sys.CPULoad 50 80
    $cpuIcon = Get-StatusIcon $sys.CPULoad 50 80
    Write-Host "  │  $cpuIcon CPU   " -ForegroundColor $cpuColor -NoNewline
    Write-Host "$($sys.CPULoad)%".PadLeft(4) -ForegroundColor $cpuColor -NoNewline
    Write-Host "  " -NoNewline
    Draw-StatusBar "" $sys.CPULoad $cpuColor

    # RAM
    $ramColor = Get-StatusColor $sys.RAMPct 70 85
    $ramIcon = Get-StatusIcon $sys.RAMPct 70 85
    Write-Host "  │  $ramIcon RAM   " -ForegroundColor $ramColor -NoNewline
    Write-Host "$($sys.RAMPct)%".PadLeft(4) -ForegroundColor $ramColor -NoNewline
    Write-Host "  " -NoNewline
    Draw-StatusBar "" $sys.RAMPct $ramColor
    Write-Host "  │       $($sys.RAMFree) GB libre de $($sys.RAMTotal) GB" -ForegroundColor $C.Muted

    # Disco
    $diskColor = Get-StatusColor $sys.DiskPct 80 90
    $diskIcon = Get-StatusIcon $sys.DiskPct 80 90
    Write-Host "  │  $diskIcon Disco " -ForegroundColor $diskColor -NoNewline
    Write-Host "$($sys.DiskPct)%".PadLeft(4) -ForegroundColor $diskColor -NoNewline
    Write-Host "  " -NoNewline
    Draw-StatusBar "" $sys.DiskPct $diskColor
    Write-Host "  │       $($sys.DiskFree) GB libre de $($sys.DiskTotal) GB" -ForegroundColor $C.Muted

    # Info adicional
    Write-Host "  │" -ForegroundColor $C.Subtle
    $svcColor = if ($sys.SvcRunning -gt 100) { "Yellow" } else { "Green" }
    Write-Host "  │  ⚙️  Servicios: $($sys.SvcRunning) activos de $($sys.SvcTotal)" -ForegroundColor $svcColor
    Write-Host "  │  🚀 Inicio:     $($sys.StartupCount) programas" -ForegroundColor $(if($sys.StartupCount -gt 10){"Yellow"}else{"Green"})
    Write-Host "  │  📊 Procesos:   $($sys.ProcCount)" -ForegroundColor $C.Subtle
    Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor $C.Subtle
    Write-Host ""
}

# ============================================================
#  HEADER DE CATEGORÍA
# ============================================================

function Show-CategoryHeader {
    param([string]$Icon, [string]$Title, [string]$Subtitle = "")
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor $C.Header
    Write-Host "  ║  $Icon  $Title$(' ' * [Math]::Max(0, 49 - $Title.Length - 3))║" -ForegroundColor $C.Header
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor $C.Header
    if ($Subtitle) {
        Write-Host "  $Subtitle" -ForegroundColor $C.Subtle
        Write-Host ""
    }
}

# ============================================================
#  MENÚ PRINCIPAL
# ============================================================

function Show-MainMenu {
    Show-Dashboard

    Write-Host "  ¿Qué necesitás hacer?" -ForegroundColor $C.Text
    Write-Host ""

    Draw-MenuItem "1" "🔍" "Diagnóstico" "White" "Ver cómo está tu notebook ahora"
    Draw-MenuItem "2" "🚀" "Optimizar" "Green" "Limpiar, acelerar y liberar recursos"
    Draw-MenuItem "3" "⚡" "Modos especiales" "Yellow" "Turbo Boost, Gaming Mode, Red"
    Draw-MenuItem "4" "🛡️" "Seguridad y respaldo" "Cyan" "Rescue points, perfiles, emergencia"
    Draw-MenuItem "5" "🧰" "Herramientas" "Gray" "Drivers, apps, reportes, actualizaciones"

    Draw-ExitOption
    Write-Host ""
}

# ============================================================
#  CATEGORÍA 1: DIAGNÓSTICO
# ============================================================

function Show-DiagnosticoMenu {
    Show-CategoryHeader "🔍" "DIAGNÓSTICO" "Analizá el estado actual de tu notebook"

    Draw-MenuItem "1" "📊" "Benchmark completo" "White" "Diagnóstico detallado con puntuación"
    Draw-MenuItem "2" "🏥" "Health Check rápido" "Green" "Resumen visual en 10 segundos"
    Draw-MenuItem "3" "📈" "Comparar benchmarks" "Cyan" "Ver evolución entre optimizaciones"
    Draw-MenuItem "4" "🌐" "Dashboard web" "Cyan" "Monitoreo en tiempo real en el navegador"
    Draw-MenuItem "5" "📤" "Exportar benchmark" "Gray" "Compartir resultado con otra PC"

    Draw-BackOption
    Wait-Input

    switch ($script:choice) {
        "1" { & "$ScriptsDir\benchmark.ps1" -Mode rapido; pause; Show-DiagnosticoMenu }
        "2" { & "$ScriptsDir\health-check.ps1"; pause; Show-DiagnosticoMenu }
        "3" { & "$ScriptsDir\compare.ps1" -Action compare; pause; Show-DiagnosticoMenu }
        "4" { & "$ScriptsDir\dashboard.ps1" -Action start; pause; Show-DiagnosticoMenu }
        "5" { & "$ScriptsDir\share-benchmark.ps1" -Action export; pause; Show-DiagnosticoMenu }
        "0" { return }
        default { Show-DiagnosticoMenu }
    }
}

# ============================================================
#  CATEGORÍA 2: OPTIMIZAR
# ============================================================

function Show-OptimizarMenu {
    Show-CategoryHeader "🚀" "OPTIMIZAR" "Mejorá el rendimiento de tu notebook"

    Write-Host "  ── Automático ──────────────────────────────────────" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "A" "🔥" "OPTIMIZAR TODO" "Red" "Ejecuta todos los pasos (5-10 min)"
    Draw-MenuItem "Z" "🧙" "Wizard guiado" "Magenta" "Paso a paso, ideal para la primera vez"
    Write-Host ""

    Write-Host "  ── Manual (paso a paso) ────────────────────────────" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "1" "🗑️" "Debloater" "Yellow" "Eliminar ~30 apps basura de Windows"
    Draw-MenuItem "2" "⚡" "Startup Cleaner" "Yellow" "Limpiar programas que arrancan con Windows"
    Draw-MenuItem "3" "🔧" "Services Optimizer" "Yellow" "Desactivar servicios innecesarios"
    Draw-MenuItem "4" "🚀" "Performance Tweaks" "Yellow" "Efectos visuales, energía, telemetría"
    Draw-MenuItem "5" "💾" "Memory Optimizer" "Yellow" "Liberar RAM y ajustar pagefile"
    Draw-MenuItem "6" "🧹" "Disk Cleanup" "Yellow" "Archivos temp, cache, papelera"
    Draw-MenuItem "7" "🌐" "Network Optimizer" "Cyan" "TCP/DNS/latencia optimizados"

    Draw-BackOption
    Wait-Input

    switch ($script:choice.ToUpper()) {
        "A" { Run-OptimizeAll; pause; Show-OptimizarMenu }
        "Z" { & "$ScriptsDir\wizard.ps1"; pause; Show-OptimizarMenu }
        "1" { & "$ScriptsDir\debloater.ps1"; pause; Show-OptimizarMenu }
        "2" { & "$ScriptsDir\startup-cleaner.ps1"; pause; Show-OptimizarMenu }
        "3" { & "$ScriptsDir\services.ps1"; pause; Show-OptimizarMenu }
        "4" { & "$ScriptsDir\performance.ps1"; pause; Show-OptimizarMenu }
        "5" { & "$ScriptsDir\memory.ps1"; pause; Show-OptimizarMenu }
        "6" { & "$ScriptsDir\disk-cleanup.ps1"; pause; Show-OptimizarMenu }
        "7" { & "$ScriptsDir\network-optimizer.ps1" -Action optimize; pause; Show-OptimizarMenu }
        "0" { return }
        default { Show-OptimizarMenu }
    }
}

# ============================================================
#  CATEGORÍA 3: MODOS ESPECIALES
# ============================================================

function Show-ModosMenu {
    Show-CategoryHeader "⚡" "MODOS ESPECIALES" "Activá perfiles de rendimiento según tu actividad"

    Write-Host "  ── Turbo Boost ─────────────────────────────────────" -ForegroundColor $C.Muted
    Write-Host "  CPU al 100%, +40 servicios detenidos, máximo rendimiento" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "1" "🔥" "Activar Turbo Boost" "Red" "Modo máximo rendimiento"
    Draw-MenuItem "2" "🔄" "Revertir Turbo Boost" "Cyan" "Volver a configuración normal"
    Draw-MenuItem "3" "📊" "Ver status Turbo" "Gray" "¿Está activo o no?"
    Write-Host ""

    Write-Host "  ── Gaming Mode ─────────────────────────────────────" -ForegroundColor $C.Muted
    Write-Host "  Game DVR off, GPU prioridad, red optimizada para baja latencia" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "4" "🎮" "Activar Gaming Mode" "Green" "Optimizado para jugar"
    Draw-MenuItem "5" "🔄" "Revertir Gaming Mode" "Cyan" "Volver a configuración normal"
    Draw-MenuItem "6" "📊" "Ver status Gaming" "Gray" "¿Está activo o no?"
    Write-Host ""

    Write-Host "  ── Windows Update ───────────────────────────────────" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "7" "🔒" "Bloquear Windows Update" "Yellow" "Pausar actualizaciones automáticas"
    Draw-MenuItem "8" "🔓" "Desbloquear Windows Update" "Green" "Reanudar actualizaciones"
    Draw-MenuItem "9" "📊" "Ver status WU" "Gray" "¿Está bloqueado o no?"

    Draw-BackOption
    Wait-Input

    switch ($script:choice) {
        "1" { & "$ScriptsDir\turbo-boost.ps1" -Action activate; pause; Show-ModosMenu }
        "2" { & "$ScriptsDir\turbo-boost.ps1" -Action revert; pause; Show-ModosMenu }
        "3" { & "$ScriptsDir\turbo-boost.ps1" -Action status; pause; Show-ModosMenu }
        "4" { & "$ScriptsDir\gaming-mode.ps1" -Action activate; pause; Show-ModosMenu }
        "5" { & "$ScriptsDir\gaming-mode.ps1" -Action revert; pause; Show-ModosMenu }
        "6" { & "$ScriptsDir\gaming-mode.ps1" -Action status; pause; Show-ModosMenu }
        "7" { & "$ScriptsDir\wu-blocker.ps1" -Action block; pause; Show-ModosMenu }
        "8" { & "$ScriptsDir\wu-blocker.ps1" -Action unblock; pause; Show-ModosMenu }
        "9" { & "$ScriptsDir\wu-blocker.ps1" -Action status; pause; Show-ModosMenu }
        "0" { return }
        default { Show-ModosMenu }
    }
}

# ============================================================
#  CATEGORÍA 4: SEGURIDAD Y RESPALDO
# ============================================================

function Show-SeguridadMenu {
    Show-CategoryHeader "🛡️" "SEGURIDAD Y RESPALDO" "Protegé tu sistema antes de hacer cambios"

    Draw-MenuItem "1" "💾" "Crear Rescue Point" "Green" "Respaldar estado actual (antes de tocar)"
    Draw-MenuItem "2" "🔄" "Restaurar Rescue Point" "Cyan" "Volver a un estado anterior"
    Draw-MenuItem "3" "📂" "Perfiles" "Cyan" "Guardar/cargar configuraciones"
    Draw-MenuItem "4" "🚨" "EMERGENCIA" "Red" "Restaurar TODO si algo salió mal"
    Write-Host ""
    Write-Host "  ── Daemon de monitoreo ─────────────────────────────" -ForegroundColor $C.Muted
    Write-Host "  Monitoreo silencioso que aprende tus patrones de uso" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "5" "🤖" "Iniciar Daemon" "Magenta" "Monitoreo automático en segundo plano"
    Draw-MenuItem "6" "⏹️" "Detener Daemon" "Yellow" "Apagar monitoreo"
    Draw-MenuItem "7" "📊" "Status Daemon" "Gray" "Ver si está corriendo"
    Draw-MenuItem "8" "📄" "Ver logs Daemon" "Gray" "Revisar actividad del daemon"

    Draw-BackOption
    Wait-Input

    switch ($script:choice) {
        "1" { & "$ScriptsDir\rescue.ps1" -Action create -Name "manual"; pause; Show-SeguridadMenu }
        "2" { & "$ScriptsDir\rescue.ps1" -Action restore; pause; Show-SeguridadMenu }
        "3" { Show-PerfilesMenu; Show-SeguridadMenu }
        "4" { & "$ScriptsDir\emergencia.ps1"; pause; Show-SeguridadMenu }
        "5" { & "$ScriptsDir\daemon.ps1" -Action start; pause; Show-SeguridadMenu }
        "6" { & "$ScriptsDir\daemon.ps1" -Action stop; pause; Show-SeguridadMenu }
        "7" { & "$ScriptsDir\daemon.ps1" -Action status; pause; Show-SeguridadMenu }
        "8" { & "$ScriptsDir\daemon.ps1" -Action log; pause; Show-SeguridadMenu }
        "0" { return }
        default { Show-SeguridadMenu }
    }
}

function Show-PerfilesMenu {
    Show-CategoryHeader "📂" "PERFILES" "Guardá y cargá configuraciones completas"

    Draw-MenuItem "1" "📋" "Listar perfiles" "Cyan" "Ver perfiles guardados"
    Draw-MenuItem "2" "💾" "Guardar perfil actual" "Green" "Crear un nuevo perfil"
    Draw-MenuItem "3" "📥" "Cargar perfil" "Yellow" "Aplicar un perfil guardado"
    Draw-MenuItem "4" "🗑️" "Eliminar perfil" "Red" "Borrar un perfil"

    Draw-BackOption
    Wait-Input

    switch ($script:choice) {
        "1" { & "$ScriptsDir\profiles.ps1" -Action list; pause; Show-PerfilesMenu }
        "2" { & "$ScriptsDir\profiles.ps1" -Action save; pause; Show-PerfilesMenu }
        "3" { & "$ScriptsDir\profiles.ps1" -Action load; pause; Show-PerfilesMenu }
        "4" { & "$ScriptsDir\profiles.ps1" -Action delete; pause; Show-PerfilesMenu }
        "0" { return }
        default { Show-PerfilesMenu }
    }
}

# ============================================================
#  CATEGORÍA 5: HERRAMIENTAS
# ============================================================

function Show-HerramientasMenu {
    Show-CategoryHeader "🧰" "HERRAMIENTAS" "Utilidades adicionales"

    Draw-MenuItem "1" "🔧" "Driver Updater" "Cyan" "Escanear y actualizar drivers"
    Draw-MenuItem "2" "📊" "Generar reporte HTML" "Cyan" "Reporte visual del benchmark"
    Draw-MenuItem "3" "⏰" "Optimización programada" "Cyan" "Benchmark automático semanal"
    Draw-MenuItem "4" "📥" "Importar benchmark" "Gray" "Cargar benchmark de otra PC"
    Draw-MenuItem "5" "🏪" "App Store" "Cyan" "Reinstalar apps que eliminaste"
    Draw-MenuItem "6" "📦" "Paquete offline" "Gray" "Exportar para usar sin internet"
    Draw-MenuItem "7" "📥" "Actualizar MejoraNotebook" "Green" "Descargar última versión desde GitHub"
    Draw-MenuItem "8" "🗑️" "Desinstalador" "Red" "Restaurar todo y eliminar"
    Write-Host ""
    Write-Host "  ── Avanzado ────────────────────────────────────────" -ForegroundColor $C.Muted
    Write-Host ""
    Draw-MenuItem "D" "🧪" "Toggle Dry-Run" $(if($Global:DryRun){"Yellow"}else{"Gray"}) $(if($Global:DryRun){"ACTIVO — los scripts simulan sin aplicar"}else{"Off — los scripts aplican cambios reales"})
    Draw-MenuItem "L" "📄" "Ver log de esta sesión" "Gray" "Revisar operaciones realizadas"

    Draw-BackOption
    Wait-Input

    switch ($script:choice.ToUpper()) {
        "1" { & "$ScriptsDir\driver-updater.ps1" -Action scan; pause; Show-HerramientasMenu }
        "2" { & "$ScriptsDir\html-report.ps1"; pause; Show-HerramientasMenu }
        "3" { Show-SchedulerMenu; Show-HerramientasMenu }
        "4" { & "$ScriptsDir\share-benchmark.ps1" -Action import; pause; Show-HerramientasMenu }
        "5" { & "$ScriptsDir\app-store.ps1" -Action list; pause; Show-HerramientasMenu }
        "6" { & "$ScriptsDir\offline-pack.ps1" -Action export; pause; Show-HerramientasMenu }
        "7" { & "$ScriptsDir\updater.ps1" -Action update; pause; Show-HerramientasMenu }
        "8" { & "$ScriptsDir\uninstall-tool.ps1"; pause; Show-HerramientasMenu }
        "D" {
            Set-DryRun (!$Global:DryRun)
            if ($Global:DryRun) {
                Write-Success "Dry-RUN activado — los scripts simularán sin aplicar cambios."
            } else {
                Write-Info "Dry-RUN desactivado — los scripts aplicarán cambios reales."
            }
            Start-Sleep -Seconds 2
            Show-HerramientasMenu
        }
        "L" { Show-RecentLogs -Lines 30; pause; Show-HerramientasMenu }
        "0" { return }
        default { Show-HerramientasMenu }
    }
}

function Show-SchedulerMenu {
    Show-CategoryHeader "⏰" "OPTIMIZACIÓN PROGRAMADA" "Benchmark automático semanal"

    Draw-MenuItem "1" "📊" "Ver status" "Cyan" "¿Hay tareas programadas?"
    Draw-MenuItem "2" "✅" "Instalar" "Green" "Benchmark cada lunes automático"
    Draw-MenuItem "3" "🗑️" "Eliminar" "Red" "Quitar tarea programada"

    Draw-BackOption
    Wait-Input

    switch ($script:choice) {
        "1" { & "$ScriptsDir\scheduler.ps1" -Action status; pause; Show-SchedulerMenu }
        "2" { & "$ScriptsDir\scheduler.ps1" -Action install; pause; Show-SchedulerMenu }
        "3" { & "$ScriptsDir\scheduler.ps1" -Action uninstall; pause; Show-SchedulerMenu }
        "0" { return }
        default { Show-SchedulerMenu }
    }
}

# ============================================================
#  OPTIMIZAR TODO (conservado del original)
# ============================================================

function Run-OptimizeAll {
    Write-Header "🔥 OPTIMIZACIÓN COMPLETA"
    Write-Host "  Esto va a ejecutar:" -ForegroundColor White
    Write-Host "    1. Debloater (eliminar bloatware)" -ForegroundColor Gray
    Write-Host "    2. Startup Cleaner (limpiar inicio)" -ForegroundColor Gray
    Write-Host "    3. Services Optimizer (optimizar servicios)" -ForegroundColor Gray
    Write-Host "    4. Performance Tweaks (rendimiento)" -ForegroundColor Gray
    Write-Host "    5. Memory Optimizer (liberar RAM)" -ForegroundColor Gray
    Write-Host "    6. Disk Cleanup (limpiar disco)" -ForegroundColor Gray
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
    & "$ScriptsDir\rescue.ps1" -Action create -Name "pre-optimize-all"
    Write-Host ""

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
#  MODO SILENCIOSO (conservado del original)
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

    Write-Header "📊 BENCHMARK ANTES"
    & "$ScriptsDir\benchmark.ps1" -Mode antes

    Run-OptimizeAll-Inner

    if ($WithGaming) {
        Write-Host ""
        Write-Header "🎮 ACTIVANDO GAMING MODE"
        & "$ScriptsDir\gaming-mode.ps1" -Action activate
    }

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

# ============================================================
#  LOOP PRINCIPAL
# ============================================================

do {
    Show-MainMenu
    Wait-Input

    switch ($script:choice.ToUpper()) {
        "1" { Show-DiagnosticoMenu }
        "2" { Show-OptimizarMenu }
        "3" { Show-ModosMenu }
        "4" { Show-SeguridadMenu }
        "5" { Show-HerramientasMenu }
        "Q" {
            Clear-Host
            Write-Host ""
            Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "  ║                                                       ║" -ForegroundColor Cyan
            Write-Host "  ║   ¡Listo! Tu notebook te espera. 🚀                  ║" -ForegroundColor Cyan
            Write-Host "  ║                                                       ║" -ForegroundColor Cyan
            Write-Host "  ║   Recordá reiniciar si optimizaste.                   ║" -ForegroundColor Cyan
            Write-Host "  ║   Cualquier cosa, volvé a ejecutar.                   ║" -ForegroundColor Cyan
            Write-Host "  ║                                                       ║" -ForegroundColor Cyan
            Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            break
        }
        default {
            # No hacer nada, vuelve al loop
        }
    }
} while ($script:choice.ToUpper() -ne "Q")
