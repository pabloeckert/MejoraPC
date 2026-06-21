# ============================================================
# CLAUDE BOOST -- Optimizacion extrema para Claude Code x4 + 5GB
# Standalone: se puede ejecutar desde acceso directo en escritorio
# ============================================================

[CmdletBinding()]
param([switch]$Silent)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# --- AUTO-ELEVACION ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- HELPERS: usa config.ps1 del proyecto, o fallback standalone -------------
if (Test-Path "$PSScriptRoot\config.ps1") { . "$PSScriptRoot\config.ps1" }
else {
    function Write-Step($n, $t) { Write-Host "  [$n] $t" -ForegroundColor Yellow }
    function Write-Success($t)  { Write-Host "      [+] $t" -ForegroundColor Green }
    function Write-Warn($t)     { Write-Host "      [!] $t" -ForegroundColor DarkYellow }
    function Write-Info($t)     { Write-Host "      [.] $t" -ForegroundColor DarkGray }
    function Log($m)            {}
}

# --- ESTADO INICIAL ----------------------------------------------------------
$sysInfo       = Get-CimInstance Win32_ComputerSystem
$totalRAMgb    = [math]::Round($sysInfo.TotalPhysicalMemory / 1GB)
$osBefore      = Get-CimInstance Win32_OperatingSystem
$freeRamBefore = [math]::Round($osBefore.FreePhysicalMemory / 1MB, 2)
$diskBefore    = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
$step          = 0
$lnkPath       = [System.Environment]::GetFolderPath('Desktop') + '\Claude Boost.lnk'

# --- BANNER ------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host "   CLAUDE BOOST  --  Optimizacion Extrema para IA" -ForegroundColor Magenta
Write-Host "   4 instancias paralelas  |  archivos mas de 5GB" -ForegroundColor DarkMagenta
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  RAM: $($totalRAMgb)GB total  |  $($freeRamBefore)GB libre  |  $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# =============================================================================
# PASO 1: PLAN DE ENERGIA -- MAXIMO RENDIMIENTO
# =============================================================================
$step++
Write-Step $step "Plan de energia -- Maximo Rendimiento"

$powerList = powercfg /list 2>$null
$ultiLine  = $powerList | Select-String 'Ultimate|ltimo\s*rendimiento|Rendimiento m' | Select-Object -First 1
$highLine  = $powerList | Select-String 'High performance|Alto rendimiento'            | Select-Object -First 1
$ultiGuid  = if ($ultiLine) { [regex]::Match([string]$ultiLine, '([0-9a-f-]{36})').Value } else { '' }
$highGuid  = if ($highLine) { [regex]::Match([string]$highLine, '([0-9a-f-]{36})').Value } else { '' }

if ($ultiGuid) {
    powercfg /setactive $ultiGuid 2>$null
    Write-Success "Plan Ultimate Performance activado"
} elseif ($highGuid) {
    powercfg /setactive $highGuid 2>$null
    Write-Success "Plan Alto Rendimiento activado"
} else {
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
    $pl2 = powercfg /list 2>$null
    $g2  = [regex]::Match([string]($pl2 | Select-String 'Ultimate|ltimo' | Select-Object -First 1), '([0-9a-f-]{36})').Value
    if ($g2) { powercfg /setactive $g2 2>$null; Write-Success "Plan Ultimate creado y activado" }
    else      { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null; Write-Success "Plan Alto Rendimiento (GUID fijo)" }
}

powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>$null
powercfg /setactive scheme_current 2>$null
powercfg /change standby-timeout-ac 0 2>$null
powercfg /change monitor-timeout-ac 0 2>$null
Write-Info "CPU al 100% garantizado | Suspension deshabilitada"

# =============================================================================
# PASO 2: LIMPIEZA DE DISCO
# =============================================================================
$step++
Write-Step $step "Limpieza de disco (temps + WU cache + browsers + papelera)"

$cleanDirs = @(
    $env:TEMP,
    $env:TMP,
    "$env:WINDIR\Temp",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
)

$totalCleaned = 0L
foreach ($dir in $cleanDirs) {
    if (Test-Path $dir) {
        $sz = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $dir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $totalCleaned += $sz
    }
}

# Windows Update cache
$wuDir = "$env:WINDIR\SoftwareDistribution\Download"
if (Test-Path $wuDir) {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    $wuSz = (Get-ChildItem $wuDir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Get-ChildItem $wuDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    $totalCleaned += $wuSz
}

# Thumbs + icon cache
$explorerCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $explorerCache) {
    Get-ChildItem $explorerCache -Filter 'thumbcache_*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $explorerCache -Filter 'iconcache_*'  -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Clear-RecycleBin -Force -ErrorAction SilentlyContinue

Write-Success "Liberados: $([math]::Round($totalCleaned / 1MB, 0)) MB"

# =============================================================================
# PASO 3: SERVICIOS NO CRITICOS -- STOP TEMPORAL
# =============================================================================
$step++
Write-Step $step "Servicios no criticos -- Stop temporal"

$svcsToStop = @(
    'DiagTrack',
    'WSearch',
    'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',
    'MapsBroker', 'lfsvc',
    'PhoneSvc', 'MessagingService',
    'WMPNetworkSvc', 'RetailDemo', 'wisvc',
    'SCardSvr', 'ScDeviceEnum',
    'WerSvc', 'diagsvc', 'DPS', 'WdiServiceHost'
)

$stoppedSvcs = 0
foreach ($sn in $svcsToStop) {
    $svc = Get-Service -Name $sn -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Stop-Service -Name $sn -Force -ErrorAction SilentlyContinue
        $stoppedSvcs++
    }
}
Write-Success "$stoppedSvcs servicios detenidos"

# =============================================================================
# PASO 4: PROCESOS DE FONDO -- PRIORIDAD BAJA + CERRAR BLOATWARE
# =============================================================================
$step++
Write-Step $step "Procesos de fondo -- Prioridad Idle + cierre de bloatware"

$setIdle = @('SearchApp','SearchIndexer','OneDrive','MicrosoftEdgeUpdate',
             'BackgroundTaskHost','SpeechRuntime','AdobeARM','GoogleUpdate',
             'BraveUpdate','CCXProcess','AGSService')

$lowered = 0
foreach ($pn in $setIdle) {
    Get-Process -Name $pn -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.PriorityClass = 'Idle'; $lowered++ } catch {}
    }
}

$killList = @('Widgets','WidgetService','YourPhone','PhoneExperienceHost',
              'Cortana','TabTip','tabtip32')
foreach ($pn in $killList) {
    Get-Process -Name $pn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Success "$lowered procesos relegados a prioridad Idle"

# =============================================================================
# PASO 5: RAM -- PURGA STANDBY LIST + EMPTY WORKING SETS
# =============================================================================
$step++
Write-Step $step "RAM -- Purga Standby List + vaciado de Working Sets"

$memCode = @'
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
public class ClaudeBoostMem {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr handle);
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int infoClass, IntPtr info, int length);
    [DllImport("ntdll.dll")]
    public static extern int RtlAdjustPrivilege(int priv, bool enable, bool current, out bool prevState);

    public static void EmptyAllWorkingSets() {
        foreach (var p in Process.GetProcesses()) {
            try { EmptyWorkingSet(p.Handle); } catch {}
        }
    }
    public static void PurgeStandbyList() {
        bool prev;
        RtlAdjustPrivilege(19, true, false, out prev);
        IntPtr ptr = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(ptr, 4);
        NtSetSystemInformation(80, ptr, 4);
        Marshal.FreeHGlobal(ptr);
    }
}
'@

$memPurged = $false
try {
    Add-Type -TypeDefinition $memCode -Language CSharp -ErrorAction Stop
    [ClaudeBoostMem]::EmptyAllWorkingSets()
    [ClaudeBoostMem]::PurgeStandbyList()
    $memPurged = $true
} catch {}

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

if ($memPurged) { Write-Success "Standby list purgada + working sets vaciados (WinAPI)" }
else            { Write-Success "GC.Collect completado" }

# =============================================================================
# PASO 6: REGISTRO -- I/O PARA >5GB + CPU SCHEDULING
# =============================================================================
$step++
Write-Step $step "Registro -- I/O archivos mas de 5GB + CPU scheduling + NTFS"

$memMgmt = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$fileReg = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
$prioReg = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
$ctrlReg = 'HKLM:\SYSTEM\CurrentControlSet\Control'

# Kernel en RAM, no paginado
Set-ItemProperty $memMgmt 'DisablePagingExecutive'  1          -Type DWord -ErrorAction SilentlyContinue

# Workstation mode: priorizar apps sobre file cache del sistema
Set-ItemProperty $memMgmt 'LargeSystemCache'        0          -Type DWord -ErrorAction SilentlyContinue

# I/O page lock limit: 256MB -- mas I/O asincrona para archivos grandes
Set-ItemProperty $memMgmt 'IoPageLockLimit'         268435456  -Type DWord -ErrorAction SilentlyContinue

# CPU scheduling: maximo boost foreground
Set-ItemProperty $prioReg 'Win32PrioritySeparation' 38         -Type DWord -ErrorAction SilentlyContinue

# NTFS: sin LastAccess updates en lecturas (critico para archivos 5GB+)
Set-ItemProperty $fileReg 'NtfsDisableLastAccessUpdate' 1      -Type DWord -ErrorAction SilentlyContinue
fsutil behavior set disablelastaccess 1 2>$null | Out-Null

# NTFS: mas RAM para metadata
Set-ItemProperty $fileReg 'NtfsMemoryUsage'         2          -Type DWord -ErrorAction SilentlyContinue

# SvcHost: un pool cuando hay suficiente RAM (menos overhead)
$visKB = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize
Set-ItemProperty $ctrlReg 'SvcHostSplitThresholdInKB' $visKB  -Type DWord -ErrorAction SilentlyContinue

Write-Success "Kernel en RAM | I/O 256MB | NTFS sin LastAccess | CPU max-boost foreground"

# =============================================================================
# PASO 7: NODE.JS / CLAUDE CODE -- VARIABLES DE ENTORNO PERSISTENTES
# =============================================================================
$step++
Write-Step $step "Node.js / Claude Code -- Variables de entorno"

# Heap por instancia: (RAM - 4GB OS) / 4 instancias, min 2GB, max 8GB
$heapMB = [math]::Max(2048, [math]::Min(8192, [math]::Floor(($totalRAMgb - 4) * 1024 / 4)))

# Persistir en Machine (disponible en todas las terminales nuevas)
[System.Environment]::SetEnvironmentVariable('NODE_OPTIONS',       "--max-old-space-size=$heapMB", 'Machine')
[System.Environment]::SetEnvironmentVariable('UV_THREADPOOL_SIZE', '16',                           'Machine')

# Tambien en este proceso
$env:NODE_OPTIONS       = "--max-old-space-size=$heapMB"
$env:UV_THREADPOOL_SIZE = '16'

Write-Success "NODE_OPTIONS=--max-old-space-size=$($heapMB)MB  ($($totalRAMgb)GB / 4 instancias)"
Write-Info    "UV_THREADPOOL_SIZE=16  (thread pool I/O para lectura de archivos grandes)"

# =============================================================================
# PASO 8: RED -- DNS FLUSH + TCP AUTOTUNING
# =============================================================================
$step++
Write-Step $step "Red -- DNS flush + TCP autotuning"

ipconfig /flushdns 2>$null | Out-Null
netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null

Write-Success "DNS cache vaciado | TCP autotuning normalizado"

# =============================================================================
# PASO 9: ACCESO DIRECTO EN ESCRITORIO (Run as Admin automatico)
# =============================================================================
$step++
Write-Step $step "Acceso directo en escritorio"

$scriptTarget = $PSCommandPath

try {
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath       = "$PSHOME\powershell.exe"
    $lnk.Arguments        = "-ExecutionPolicy Bypass -File `"$scriptTarget`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.Description      = 'Claude Boost -- Optimizacion para Claude Code x4 + archivos 5GB+'
    $lnk.IconLocation     = '%SystemRoot%\System32\imageres.dll,109'
    $lnk.WindowStyle      = 1
    $lnk.Save()

    # Bit 0x20 en offset 0x15 del .lnk = "Ejecutar como administrador"
    $lnkBytes = [System.IO.File]::ReadAllBytes($lnkPath)
    $lnkBytes[0x15] = $lnkBytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($lnkPath, $lnkBytes)

    Write-Success "Creado con UAC automatica: $lnkPath"
} catch {
    Write-Warn "No se pudo crear acceso directo: $_"
}

# =============================================================================
# RESUMEN FINAL
# =============================================================================
$osAfter      = Get-CimInstance Win32_OperatingSystem
$freeRamAfter = [math]::Round($osAfter.FreePhysicalMemory / 1MB, 2)
$ramFreedGB   = [math]::Round($freeRamAfter - $freeRamBefore, 2)
$diskAfter    = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
$diskFreedGB  = [math]::Round(($diskAfter - $diskBefore) / 1GB, 2)
$ramColor     = if ($ramFreedGB -ge 0) { 'Green' } else { 'Yellow' }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "              CLAUDE BOOST COMPLETADO" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  RAM:   $($freeRamBefore)GB libres -> $($freeRamAfter)GB libres  ($([math]::Abs($ramFreedGB))GB $( if ($ramFreedGB -ge 0) { 'liberados' } else { 'comprometidos' }))" -ForegroundColor $ramColor
Write-Host "  Disco: +$($diskFreedGB)GB liberados en C:" -ForegroundColor Green
Write-Host ""
Write-Host "  Sistema listo para:" -ForegroundColor White
Write-Host "    * 4x Claude Code en paralelo  (~$($heapMB)MB heap por instancia)" -ForegroundColor Cyan
Write-Host "    * Archivos mas de 5GB  (NTFS optimizado, I/O async lock 256MB)" -ForegroundColor Cyan
Write-Host "    * CPU sin throttling  (plan Alto Rendimiento activo)" -ForegroundColor Cyan
Write-Host "    * 16 threads I/O por instancia Node.js  (UV_THREADPOOL)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Acceso directo: $lnkPath" -ForegroundColor DarkGray
Write-Host "  (doble clic la proxima vez -- UAC automatica)" -ForegroundColor DarkGray
Write-Host ""

Log "Claude Boost: RAM $($freeRamBefore)->$($freeRamAfter)GB | disco+$($diskFreedGB)GB | heap=$($heapMB)MB | svcs=$stoppedSvcs"

Write-Host "  Presiona Enter para cerrar..." -ForegroundColor DarkGray
if (-not $Silent) { $null = Read-Host }
