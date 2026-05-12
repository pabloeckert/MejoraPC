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
