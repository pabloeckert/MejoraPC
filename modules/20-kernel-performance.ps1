[CmdletBinding()]
param(
    [switch]$Auto,
    [switch]$Elevated
)

# ── MejoraPC — modules/20-kernel-performance.ps1 ───────────────────
# Optimización profunda a nivel de kernel, servicios, MSI e interrupciones,
# y afinamiento del programador de hilos (Win32PrioritySeparation).

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"
Clear-HostSafe

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   20 - OPTIMIZACIÓN DE KERNEL, MSI & SERVICIOS   ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$logDir = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$date = (Get-Date).ToString('yyyy-MM-dd')
$logFile = Join-Path $logDir "kernel-performance-$date.log"

function Write-KLog {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'HH:mm:ss')  $Msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $Elevated) {
    Write-Host "  [!] Este módulo requiere permisos de Administrador para modificar HKLM, MSI y servicios." -ForegroundColor Yellow
    Write-Host "      Disparando elevación vía UAC..." -ForegroundColor DarkGray
    try {
        $p = Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated -Auto" -Wait -PassThru
        if ($p.ExitCode -eq 0) {
            Write-Host "  [+] Proceso elevado completado con éxito." -ForegroundColor Green
        } else {
            Write-Host "  [!] El proceso elevado retornó código de salida: $($p.ExitCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [x] Elevación cancelada o denegada: $_" -ForegroundColor Red
    }
    Wait-KeyIfInteractive -Auto:$Auto
    return
}

Write-KLog "=== INICIO KERNEL PERFORMANCE OPTIMIZATION ==="
$reportData = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    services = @()
    msi_devices = @()
    path_cleanup = @{}
    scheduling = @{}
}

# ═══════════════════════════════════════════════════════════════════
# 1. SERVICIOS NO ESENCIALES (SysMain y DiagTrack)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  ── 1. Desactivación de Servicios No Esenciales" -ForegroundColor Cyan
$targetServices = @(
    @{ Name = 'SysMain'; Desc = 'SuperFetch / SysMain (E/S redundante en NVMe SSD)' },
    @{ Name = 'DiagTrack'; Desc = 'Connected User Experiences and Telemetry' }
)

foreach ($item in $targetServices) {
    $sName = $item.Name
    $svc = Get-Service -Name $sName -ErrorAction SilentlyContinue
    if ($svc) {
        $oldStart = (Get-CimInstance Win32_Service -Filter "Name='$sName'" -ErrorAction SilentlyContinue).StartMode
        $oldStatus = $svc.Status
        try {
            Set-Service -Name $sName -StartupType Disabled -ErrorAction Stop
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $sName -Force -ErrorAction Stop
            }
            $newSvc = Get-Service -Name $sName
            Write-Status $sName "StartMode: $oldStart -> Disabled | Status: $oldStatus -> $($newSvc.Status)" 'OK'
            Write-KLog "SVC  $sName : $oldStart ($oldStatus) -> Disabled ($($newSvc.Status))"
            $reportData.services += [pscustomobject]@{
                name = $sName
                description = $item.Desc
                old_startup = $oldStart
                new_startup = 'Disabled'
                old_status = "$oldStatus"
                new_status = "$($newSvc.Status)"
            }
        } catch {
            Write-Status $sName "error: $_" 'ERROR'
            Write-KLog "SVC FAIL $sName : $_"
        }
    } else {
        Write-Status $sName "no encontrado en el sistema" 'INFO'
    }
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
# 2. OPTIMIZACIÓN DE INTERRUPCIONES MSI (Message Signaled Interrupts)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  ── 2. Modo MSI en Controladoras de Red y Gráficos" -ForegroundColor Cyan
$enumBase = 'HKLM:\SYSTEM\CurrentControlSet\Enum'
$targetDevices = Get-PnpDevice -Class Net, Display -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'PCI\*' }

foreach ($dev in $targetDevices) {
    $instance = $dev.InstanceId
    $name = $dev.FriendlyName
    $msiKeyPath = Join-Path $enumBase "$instance\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    
    try {
        if (-not (Test-Path $msiKeyPath)) {
            New-Item -Path $msiKeyPath -Force -ErrorAction Stop | Out-Null
        }
        $oldMsi = (Get-ItemProperty -Path $msiKeyPath -Name 'MSISupported' -ErrorAction SilentlyContinue).MSISupported
        Set-ItemProperty -Path $msiKeyPath -Name 'MSISupported' -Value 1 -Type DWord -Force -ErrorAction Stop
        
        # Opcional: MessageNumberLimit = 1 para estabilidad
        Set-ItemProperty -Path $msiKeyPath -Name 'MessageNumberLimit' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        
        $oldDesc = if ($null -eq $oldMsi) { 'Line-Based (0/Inexistente)' } else { "$oldMsi" }
        Write-Status "$name" "MSI Mode activado ($oldDesc -> 1)" 'OK'
        Write-KLog "MSI  $instance ($name) : $oldDesc -> 1"
        $reportData.msi_devices += [pscustomobject]@{
            device = $name
            instance_id = $instance
            class = $dev.Class
            old_msi = $oldDesc
            new_msi = 1
        }
    } catch {
        Write-Status "$name" "error: $_" 'ERROR'
        Write-KLog "MSI FAIL $name : $_"
    }
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
# 3. SINTONIZACIÓN DEL PATH (User y System)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  ── 3. Depuración y Afinamiento de Variables PATH" -ForegroundColor Cyan

function Clean-EnvironmentPath {
    param([ValidateSet('User', 'Machine')] [string]$TargetScope)
    
    $raw = [Environment]::GetEnvironmentVariable('Path', $TargetScope)
    $entries = $raw -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $validList = [System.Collections.ArrayList]@()
    $removedList = [System.Collections.ArrayList]@()

    foreach ($e in $entries) {
        $norm = $e.Trim().TrimEnd('\')
        if (-not (Test-Path $norm)) {
            $null = $removedList.Add("Inexistente / Huérfana: $norm")
        } elseif ($seen.Contains($norm)) {
            $null = $removedList.Add("Duplicada: $norm")
        } else {
            $null = $seen.Add($norm)
            $null = $validList.Add($norm)
        }
    }

    $newPath = $validList -join ';'
    try {
        [Environment]::SetEnvironmentVariable('Path', $newPath, $TargetScope)
        Write-Status "$TargetScope PATH" "Originales: $($entries.Count) | Purgadas: $($removedList.Count) | Conservadas: $($validList.Count)" 'OK'
    } catch {
        Write-Status "$TargetScope PATH" "error al guardar (requiere admin): $_" 'WARN'
    }
    foreach ($r in $removedList) {
        Write-Host "       $r" -ForegroundColor DarkGray
        Write-KLog "PATH $TargetScope PURGE: $r"
    }
    
    return [pscustomobject]@{
        scope = $TargetScope
        original_count = $entries.Count
        cleaned_count = $validList.Count
        removed = $removedList
    }
}

$uClean = Clean-EnvironmentPath -TargetScope 'User'
$sClean = Clean-EnvironmentPath -TargetScope 'Machine'
$reportData.path_cleanup = [ordered]@{
    user = $uClean
    machine = $sClean
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════
# 4. PROCESSOR SCHEDULING (Win32PrioritySeparation)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  ── 4. Optimización de Prioridad de CPU (Processor Scheduling)" -ForegroundColor Cyan
$pCtrlKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
try {
    if (-not (Test-Path $pCtrlKey)) { New-Item -Path $pCtrlKey -Force | Out-Null }
    $oldVal = (Get-ItemProperty -Path $pCtrlKey -Name 'Win32PrioritySeparation' -ErrorAction SilentlyContinue).Win32PrioritySeparation
    $targetVal = 38 # 0x26: Short quanta, variable, 3:1 foreground boost
    Set-ItemProperty -Path $pCtrlKey -Name 'Win32PrioritySeparation' -Value $targetVal -Type DWord -Force -ErrorAction Stop
    $newVal = (Get-ItemProperty -Path $pCtrlKey -Name 'Win32PrioritySeparation').Win32PrioritySeparation
    Write-Status "Win32PrioritySeparation" "$oldVal -> $newVal (0x26: Max Foreground Boost 3:1)" 'OK'
    Write-KLog "SCHED Win32PrioritySeparation : $oldVal -> $newVal"
    $reportData.scheduling = [pscustomobject]@{
        key = $pCtrlKey
        old_value = $oldVal
        new_value = $newVal
        description = '0x26 (38 dec): Quanta cortos variables con triple boost para procesos interactivos de primer plano'
    }
} catch {
    Write-Status "Win32PrioritySeparation" "error: $_" 'ERROR'
    Write-KLog "SCHED FAIL : $_"
}
Write-Host ""

# ── Guardar datos del reporte consolidado ──────────────────────────
$dataFile = "$scriptRoot\data\last-kernel-performance.json"
$reportData | ConvertTo-Json -Depth 6 | Set-Content -Path $dataFile -Encoding UTF8
Write-Status "Informe técnico" "guardado en data\last-kernel-performance.json" 'OK'
Write-KLog "=== FIN KERNEL PERFORMANCE OPTIMIZATION ==="
Write-Host ""

Wait-KeyIfInteractive -Auto:$Auto
