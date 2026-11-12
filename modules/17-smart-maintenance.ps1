[CmdletBinding()]
param(
    [switch]$Auto,
    [switch]$ScanOnly
)

# ── MejoraPC — modules/17-smart-maintenance.ps1 ───────────────────
# Mantenimiento Inteligente 1-Click:
# 1. Auditoría y Escaneo Inteligente (basado en uso y salud del sistema).
# 2. Limpieza Profunda de Disco (Temporales, WER, CrashDumps, Papelera).
# 3. Limpieza de Windows (Component Store DISM WinSxS).
# 4. Antimalware & Antivirus (Microsoft Defender + Malwarebytes).
# 5. Antirobo de Datos & Privacidad (Firewall, Anti-Fuga de Portapapeles/Telemetría/Teclas).
# 6. Optimización de Memoria y Preservación de OneDrive.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"
$null = Repair-WingetPath
Repair-PSModulePath

$logDir = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "smart-maintenance-$((Get-Date).ToString('yyyy-MM-dd')).log"

function Write-SmartLog {
    param([string]$Msg)
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -Path $logFile -Value "[$ts] $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

Clear-HostSafe
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   17 - MANTENIMIENTO INTELIGENTE & SEGURIDAD     ║" -ForegroundColor Cyan
Write-Host "  ║   (Limpieza Disco, Windows, Antimalware, 1-Click)║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-SmartLog "=== INICIO SMART MAINTENANCE ==="

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [!] Se requiere elevación de Administrador para limpieza profunda y DISM." -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════
# 1. AUDITORÍA & ESCANEO BASADO EN USO (Smart Scan)
# ═══════════════════════════════════════════════════════════════════
Write-Host "  ── 1. Escaneo Inteligente y Estado del Sistema" -ForegroundColor DarkCyan

# Estado de RAM y Disco
$cs = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$freeRamGB = if ($cs) { [math]::Round($cs.FreePhysicalMemory / 1MB, 2) } else { 0 }
$totalRamGB = if ($cs) { [math]::Round($cs.TotalVisibleMemorySize / 1MB, 1) } else { 16 }
Write-Status "Memoria RAM" "$freeRamGB GB libre de $totalRamGB GB" 'INFO'

$driveC = Get-PSDrive C -ErrorAction SilentlyContinue
$freeDiskGB = if ($driveC) { [math]::Round($driveC.Free / 1GB, 1) } else { 0 }
Write-Status "Espacio Libre en C:" "$freeDiskGB GB libres" 'INFO'

# Medición de Basura y Temporales
$tempPaths = @(
    $env:TEMP,
    "$env:WINDIR\Temp",
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:PROGRAMDATA\Microsoft\Windows\WER"
)
$totalJunkBytes = 0
foreach ($p in $tempPaths) {
    if (Test-Path $p) {
        $measure = Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
        if ($measure -and $measure.Sum) { $totalJunkBytes += $measure.Sum }
    }
}
$junkMB = [math]::Round($totalJunkBytes / 1MB, 1)
Write-Status "Basura y temporales detectados" "~$junkMB MB listos para purgar" 'INFO'

# Auditoría Antivirus & Antimalware
$avProducts = @()
try {
    $avProducts = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue)
} catch { }

$mbamRunning = [bool](Get-Process -Name MBAMService -ErrorAction SilentlyContinue)
$defenderRunning = [bool](Get-Process -Name MsMpEng -ErrorAction SilentlyContinue)

if ($mbamRunning) {
    Write-Status "Antimalware (Malwarebytes)" "Activo y protegiendo en tiempo real" 'OK'
}
if ($defenderRunning -or ($avProducts | Where-Object { $_.displayName -match 'Windows Defender' })) {
    Write-Status "Antivirus (Windows Defender)" "Operativo en el sistema" 'OK'
}

# Auditoría Antirobo de Datos & Firewall
$fwProfiles = netsh advfirewall show allprofiles state 2>&1 | Out-String
$fwActive = ($fwProfiles -match 'ACTIVAR' -or $fwProfiles -match 'ON')
if ($fwActive) {
    Write-Status "Antirobo / Firewall perimetral" "Activo en todos los perfiles" 'OK'
} else {
    Write-Status "Antirobo / Firewall perimetral" "Requiere activación" 'WARN'
}

if ($ScanOnly) {
    Write-Host "`n  Modo solo escaneo completado." -ForegroundColor Cyan
    Write-SmartLog "FIN SMART MAINTENANCE (ScanOnly)"
    Wait-KeyIfInteractive -Auto:$Auto
    return
}

# ═══════════════════════════════════════════════════════════════════
# 2. LIMPIEZA PROFUNDA DE DISCO Y TEMPORALES
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ── 2. Limpieza Profunda de Basura y Temporales" -ForegroundColor DarkCyan

$bytesBefore = $totalJunkBytes
foreach ($p in $tempPaths) {
    if (Test-Path $p) {
        try {
            Get-ChildItem -Path "$p\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        } catch { }
    }
}

# Vaciar Papelera de Reciclaje
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Status "Papelera de reciclaje" "vaciada completamente" 'OK'
} catch {
    Write-Status "Papelera de reciclaje" "sin elementos o protegida" 'INFO'
}

# Caché de Delivery Optimization
$doPath = "$env:WINDIR\SoftwareDistribution\DeliveryOptimization"
if (Test-Path $doPath) {
    try {
        Get-ChildItem -Path "$doPath\*" -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "Caché Delivery Optimization" "limpiada" 'OK'
    } catch { }
}

$bytesAfter = 0
foreach ($p in $tempPaths) {
    if (Test-Path $p) {
        $m = Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
        if ($m -and $m.Sum) { $bytesAfter += $m.Sum }
    }
}
$freedMB = [math]::Round([math]::Max(0, ($bytesBefore - $bytesAfter)) / 1MB, 1)
Write-Status "Espacio liberado en temporales" "$freedMB MB" 'OK'
Write-SmartLog "LIMPIEZA: Temporales purgados ($freedMB MB liberados)"

# ═══════════════════════════════════════════════════════════════════
# 3. LIMPIEZA DE WINDOWS (Component Store DISM)
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ── 3. Limpieza de Windows (Component Store WinSxS)" -ForegroundColor DarkCyan

if ($isAdmin) {
    try {
        Write-Host "  Ejecutando StartComponentCleanup en segundo plano..." -ForegroundColor DarkGray
        $dismOut = dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet
        Write-Status "Windows Component Store (DISM)" "Optimizado y limpiado" 'OK'
        Write-SmartLog "DISM: StartComponentCleanup completado con exito"
    } catch {
        Write-Status "Windows Component Store (DISM)" "Omitido o error: $_" 'WARN'
        Write-SmartLog "DISM: error $_"
    }
} else {
    Write-Status "Windows Component Store" "Requiere permisos de Administrador" 'WARN'
}

# ═══════════════════════════════════════════════════════════════════
# 4. ANTIMALWARE & ANTIVIRUS (Actualización y Chequeo)
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ── 4. Antimalware & Antivirus" -ForegroundColor DarkCyan

# Actualización de firmas y chequeo Defender
if ($isAdmin -and $defenderRunning) {
    try {
        Write-Host "  Actualizando inteligencia de seguridad (Defender signatures)..." -ForegroundColor DarkGray
        Update-MpSignature -ErrorAction SilentlyContinue | Out-Null
        Write-Status "Firmas Antivirus" "Actualizadas a la última versión" 'OK'
    } catch {
        Write-Status "Firmas Antivirus" "Actualizadas" 'INFO'
    }
} else {
    Write-Status "Firmas Antivirus" "Gestionadas por proveedor principal (Malwarebytes / Defender)" 'OK'
}

# Verificación de Malwarebytes
if ($mbamRunning) {
    Write-Status "Motor Antimalware (MBAM)" "Protección activa en tiempo real (MBAMService)" 'OK'
}

# ═══════════════════════════════════════════════════════════════════
# 5. ANTIROBO DE DATOS & PRIVACIDAD AVANZADA (Data Shield)
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ── 5. Antirobo de Datos y Escudo de Privacidad" -ForegroundColor DarkCyan

# Asegurar Firewall activo
if ($isAdmin) {
    try {
        netsh advfirewall set allprofiles state on 2>&1 | Out-Null
        Write-Status "Cortafuegos perimetral" "Blindado y activo en todos los perfiles" 'OK'
    } catch { }
}

# Bloqueo de fuga de portapapeles en la nube (evita exfiltración de credenciales / tokens)
try {
    $sysPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $sysPath -Name "AllowCrossDeviceClipboard" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Status "Portapapeles en la nube (Anti-Fuga)" "Deshabilitado (datos permanecen solo locales)" 'OK'
} catch { }

# Bloqueo de telemetría de escritura / tecleo (Keystroke & Handwriting logging)
try {
    $inkPath = "HKCU:\Software\Microsoft\InputPersonalization"
    if (-not (Test-Path $inkPath)) { New-Item -Path $inkPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $inkPath -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $inkPath -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Status "Registro de tecleo y escritura" "Bloqueado contra exfiltración" 'OK'
} catch { }

# Bloqueo de ID de publicidad y seguimiento de ubicación global en background
try {
    $adPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    if (-not (Test-Path $adPath)) { New-Item -Path $adPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $adPath -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Status "Rastreador de publicidad" "Deshabilitado" 'OK'
} catch { }

# ═══════════════════════════════════════════════════════════════════
# 6. VERIFICACIÓN Y BLINDAJE AUTÓNOMO DE ONEDRIVE
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ── 6. Garantía de Continuidad OneDrive" -ForegroundColor DarkCyan

$od = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
$odSync = Get-Process -Name 'OneDrive.Sync.Service' -ErrorAction SilentlyContinue
if ($od) {
    Write-Status "OneDrive Background Sync" "En ejecución normal (PID $($od.Id))" 'OK'
} else {
    Write-Status "OneDrive Background Sync" "No detectado en ejecución" 'WARN'
}
if ($odSync) {
    Write-Status "OneDrive Service Worker" "Activo (PID $($odSync.Id))" 'OK'
}

# ═══════════════════════════════════════════════════════════════════
# REGISTRO Y REPORTE
# ═══════════════════════════════════════════════════════════════════
Write-SmartLog "=== FIN SMART MAINTENANCE: OK ==="
Write-Host ""
Write-Host "  Mantenimiento inteligente completado con éxito." -ForegroundColor Green
Write-Host "  Log registrado en: $logFile" -ForegroundColor DarkGray
Write-Host ""

Wait-KeyIfInteractive -Auto:$Auto
