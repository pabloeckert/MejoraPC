# ============================================================
# CONFIGURACIÓN COMPARTIDA - Win Optimizer
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Paths
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ScriptRoot "logs"
$RescueDir = Join-Path $ScriptRoot "rescue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Crear dirs si no existen
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (!(Test-Path $RescueDir)) { New-Item -ItemType Directory -Path $RescueDir -Force | Out-Null }

# Colores
function Write-Header($text) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($num, $text) {
    Write-Host "  [$num] " -ForegroundColor Yellow -NoNewline
    Write-Host $text -ForegroundColor White
}

function Write-Success($text) {
    Write-Host "  ✅ $text" -ForegroundColor Green
}

function Write-Warn($text) {
    Write-Host "  ⚠️  $text" -ForegroundColor DarkYellow
}

function Write-Error($text) {
    Write-Host "  ❌ $text" -ForegroundColor Red
}

function Write-Info($text) {
    Write-Host "  ℹ️  $text" -ForegroundColor Gray
}

function Log($msg) {
    $logFile = Join-Path $LogDir "optimizer_$Timestamp.log"
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Add-Content -Path $logFile -Value $entry -ErrorAction SilentlyContinue
}

# Admin check
function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Este script requiere permisos de administrador."
        Write-Info "Click derecho -> 'Ejecutar como administrador'"
        exit 1
    }
}

# System info
function Get-SystemSummary {
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $ramFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $build = (Get-CimInstance Win32_OperatingSystem).BuildNumber
    
    return @{
        CPU = $cpu
        RAM_Total = $ram
        RAM_Free = $ramFree
        OS = $os
        Build = $build
    }
}

# ============================================================
# LISTAS CENTRALIZADAS DE SERVICIOS
# ============================================================

# Servicios que se pueden poner en Manual (no esenciales)
$Global:ServicesToManual = @(
    @{ Name = "DiagTrack"; Desc = "Telemetría de Microsoft" }
    @{ Name = "diagnosticshub.standardcollector.service"; Desc = "Collector de diagnósticos" }
    @{ Name = "diagsvc"; Desc = "Servicio de diagnósticos" }
    @{ Name = "DPS"; Desc = "Directivas de diagnóstico" }
    @{ Name = "WdiServiceHost"; Desc = "Host de diagnóstico" }
    @{ Name = "WdiSystemHost"; Desc = "Sistema de diagnóstico" }
    @{ Name = "AdobeARMservice"; Desc = "Adobe Acrobat Update" }
    @{ Name = "brave"; Desc = "Brave Update" }
    @{ Name = "bravem"; Desc = "Brave Update (med)" }
    @{ Name = "edgeupdate"; Desc = "Edge Update" }
    @{ Name = "edgeupdatem"; Desc = "Edge Update (med)" }
    @{ Name = "gupdate"; Desc = "Google Update" }
    @{ Name = "gupdatem"; Desc = "Google Update (med)" }
    @{ Name = "GoogleChromeElevationService"; Desc = "Chrome Elevation" }
    @{ Name = "CapCutServiceLS"; Desc = "CapCut Service" }
    @{ Name = "DFWSIDService"; Desc = "Wondershare WSID" }
    @{ Name = "DSAService"; Desc = "Intel Driver Assistant" }
    @{ Name = "DSAUpdateService"; Desc = "Intel Driver Assistant Updater" }
    @{ Name = "AESMService"; Desc = "Intel SGX AESM" }
    @{ Name = "MapsBroker"; Desc = "Mapas descargados" }
    @{ Name = "lfsvc"; Desc = "Geolocalización" }
    @{ Name = "SharedAccess"; Desc = "Internet Connection Sharing" }
    @{ Name = "RemoteRegistry"; Desc = "Registro remoto" }
    @{ Name = "RetailDemo"; Desc = "Modo demostración" }
    @{ Name = "WMPNetworkSvc"; Desc = "Windows Media Player Sharing" }
    @{ Name = "WerSvc"; Desc = "Windows Error Reporting" }
    @{ Name = "XblAuthManager"; Desc = "Xbox Auth" }
    @{ Name = "XblGameSave"; Desc = "Xbox Game Save" }
    @{ Name = "XboxGipSvc"; Desc = "Xbox Accessory" }
    @{ Name = "XboxNetApiSvc"; Desc = "Xbox Live Networking" }
    @{ Name = "SEMgrSvc"; Desc = "Pagos y NFC/SE" }
    @{ Name = "PhoneSvc"; Desc = "Servicio telefónico" }
    @{ Name = "TapiSrv"; Desc = "Telephony" }
    @{ Name = "MessagingService"; Desc = "Mensajería" }
    @{ Name = "PimIndexMaintenanceSvc"; Desc = "Contactos" }
    @{ Name = "BcastDVRUserService"; Desc = "Game DVR" }
    @{ Name = "wisvc"; Desc = "Windows Insider" }
    @{ Name = "dmwappushservice"; Desc = "WAP Push" }
)

# Servicios que se pueden desactivar completamente (solo si no los usás)
$Global:ServicesToDisable = @(
    @{ Name = "SysMain"; Desc = "Superfetch (con SSD es innecesario)" }
    @{ Name = "WSearch"; Desc = "Windows Search Indexer (come RAM y CPU)" }
)

# Servicios adicionales que solo Turbo Boost detiene (no desactiva)
$Global:TurboExtraServices = @(
    "BITS", "DoSvc", "AeLookupSvc", "WpcMonSvc",
    "SCardSvr", "ScDeviceEnum", "TrkWks"
)

# Procesos que Turbo Boost cierra
$Global:TurboProcesses = @(
    "OneDrive", "FileSyncHelper",
    "MicrosoftEdge*", "msedge",
    "Widgets", "WidgetService",
    "YourPhone", "PhoneExperienceHost",
    "Cortana", "SearchApp", "SearchUI",
    "SecurityHealthSystray",
    "Spotify", "Discord",
    "Teams", "MSTeams",
    "AdobeARM", "AdobeUpdate",
    "GoogleUpdate", "BraveUpdate",
    "Steam", "EpicGamesLauncher",
    "CCXProcess", "AGSService",
    "IntelDriverSupportAssistant",
    "Copilot", "WindowsCopilot",
    "TabTip", "tabtip32",
    "ctfmon"
)

# ============================================================
# DRY-RUN MODE
# ============================================================
$Global:DryRun = $false

function Set-DryRun([bool]$enabled) {
    $Global:DryRun = $enabled
    if ($enabled) {
        Write-Warn "MODO DRY-RUN ACTIVADO — No se aplicarán cambios reales."
        Write-Host ""
    }
}

# Wrapper para registry: respeta dry-run
function Set-RegProperty {
    param($Path, $Name, $Value)
    if ($Global:DryRun) {
        Write-Info "[DRY-RUN] Set-ItemProperty $Path -Name $Name -Value $Value"
        return
    }
    Set-ItemProperty $Path -Name $Name -Value $Value -ErrorAction SilentlyContinue
}

# Wrapper para servicios: respeta dry-run
function Set-ServiceState {
    param([string]$Name, [string]$StartupType, [bool]$Stop = $false)
    if ($Global:DryRun) {
        Write-Info "[DRY-RUN] Set-Service $Name -StartupType $StartupType$(if($Stop){' + Stop-Service'})"
        return
    }
    if ($Stop) { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
    Set-Service -Name $Name -StartupType $StartupType -ErrorAction SilentlyContinue
}

# ============================================================
# AUTO-DETECT SSD vs HDD
# ============================================================
$Global:IsSSD = $false

function Detect-DriveType {
    try {
        $disk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "NVMe" }
        $Global:IsSSD = [bool]$disk
    } catch {
        $Global:IsSSD = $false
    }
    return $Global:IsSSD
}

# Ejecutar detección al cargar
Detect-DriveType | Out-Null

# ============================================================
# VALIDACIÓN POST-OPERACIÓN
# ============================================================
function Confirm-ServiceState {
    param([string]$Name, [string]$ExpectedStartType, [string]$Desc = "")
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (!$svc) {
        Write-Info "Servicio $Name no encontrado (puede que no exista en este sistema)"
        return $true
    }
    if ($svc.StartType -eq $ExpectedStartType) {
        return $true
    } else {
        Write-Warn "Servicio $Name : esperado=$ExpectedStartType, actual=$($svc.StartType)"
        return $false
    }
}

function Confirm-RegistryValue {
    param($Path, $Name, $ExpectedValue)
    $actual = (Get-ItemProperty $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($actual -eq $ExpectedValue) {
        return $true
    } else {
        Write-Warn "Registro $Path\$Name : esperado=$ExpectedValue, actual=$actual"
        return $false
    }
}

# ============================================================
# LOG DISPLAY
# ============================================================
function Show-LogPath {
    $logFile = Join-Path $LogDir "optimizer_$Timestamp.log"
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Info "Log guardado en: $logFile"
    }
}

function Show-RecentLogs {
    param([int]$Lines = 20)
    $logFile = Join-Path $LogDir "optimizer_$Timestamp.log"
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "  ─── ÚLTIMAS $Lines LÍNEAS DEL LOG ───" -ForegroundColor Gray
        Get-Content $logFile -Tail $Lines | ForEach-Object {
            Write-Host "    $_" -ForegroundColor DarkGray
        }
        Write-Host ""
    } else {
        Write-Info "No hay logs de esta sesión."
    }
}

# ============================================================
# NOTIFICACIONES (wrapper)
# ============================================================
function Send-Notification {
    param([string]$Title, [string]$Message, [string]$Icon = "info")
    try {
        $scriptPath = Join-Path $PSScriptRoot "notifications.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath -Title $Title -Message $Message -Icon $Icon -Duration 3
        }
    } catch {}
}
