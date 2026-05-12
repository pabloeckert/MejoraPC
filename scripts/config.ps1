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
