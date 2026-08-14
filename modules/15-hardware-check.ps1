[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/15-hardware-check.ps1 ───────────────────────
# Diagnóstico de hardware + frescura de drivers. SOLO REPORTA — nunca
# instala, actualiza ni desinstala nada (los drivers se proponen para que
# Pablo confirme, o se derivan a Windows Update / Intel Driver & Support
# Assistant, que ya vive en keep_always). Parte de la rutina "mantenimiento"
# (.claude/skills/mantenimiento) — no integra al pipeline automático de
# run.ps1 por defecto porque algunos chequeos (SMART, eventos del sistema)
# no hacen falta en cada corrida rápida.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║      15 - DIAGNÓSTICO DE HARDWARE Y DRIVERS       ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$script:nOk = 0; $script:nWarn = 0; $script:nErr = 0
$findings = [System.Collections.ArrayList]@()

function Report {
    param(
        [ValidateSet('OK','WARN','ERROR','INFO')] [string]$Estado,
        [string]$Item,
        [string]$Detalle = ''
    )
    switch ($Estado) { 'OK' { $script:nOk++ }; 'WARN' { $script:nWarn++ }; 'ERROR' { $script:nErr++ } }
    Write-Status -Label $Item -Value $Detalle -Status $Estado
    $null = $findings.Add([PSCustomObject]@{ estado = $Estado; item = $Item; detalle = $Detalle })
}

function Write-Section {
    param([string]$Title)
    $rule = '─' * [Math]::Max(0, 40 - $Title.Length)
    Write-Host ""
    Write-Host "  ── $Title $rule" -ForegroundColor Cyan
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════
# 1. DISCOS — salud SMART/reliability + estado operativo
# ═══════════════════════════════════════════════════════════════════
Write-Section "1. Discos"

$disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
if (-not $disks) {
    Report WARN 'Discos' 'Get-PhysicalDisk no devolvió datos (¿correr como admin?)'
} else {
    foreach ($d in $disks) {
        $label = "$($d.FriendlyName) [$($d.MediaType)]"
        if ($d.HealthStatus -ne 'Healthy') {
            Report ERROR $label "HealthStatus=$($d.HealthStatus) — revisar ya"
        } else {
            Report OK $label "HealthStatus=Healthy, OperationalStatus=$($d.OperationalStatus)"
        }
        try {
            $rel = $d | Get-StorageReliabilityCounter -ErrorAction Stop
            if ($rel.Wear -and $rel.Wear -gt 80) {
                Report WARN "$label / desgaste SSD" "Wear=$($rel.Wear)% — vida útil comprometida"
            }
            if ($rel.ReadErrorsTotal -gt 0 -or $rel.WriteErrorsTotal -gt 0) {
                Report WARN "$label / errores I/O" "Read=$($rel.ReadErrorsTotal) Write=$($rel.WriteErrorsTotal)"
            }
            if ($rel.Temperature -and $rel.Temperature -gt 0) {
                $tstat = Get-TemperatureStatus -Temp $rel.Temperature -Component 'Disk'
                if ($tstat -ne 'OK') { Report WARN "$label / temperatura" "$($rel.Temperature)°C" }
            }
        } catch { }
    }
}

# ═══════════════════════════════════════════════════════════════════
# 2. CPU — carga, throttling, errores de hardware en el Event Log
# ═══════════════════════════════════════════════════════════════════
Write-Section "2. CPU"

$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
if ($cpu) {
    foreach ($c in @($cpu)) {
        $ratio = if ($c.MaxClockSpeed -gt 0) { [math]::Round(($c.CurrentClockSpeed / $c.MaxClockSpeed) * 100) } else { 100 }
        if ($ratio -lt 50) {
            Report WARN $c.Name "corriendo a $ratio% del clock máximo — posible throttling térmico"
        } else {
            Report OK $c.Name "Load=$($c.LoadPercentage)%, clock=$ratio% del máximo"
        }
    }
}
try {
    $wheaErrors = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = (Get-Date).AddDays(-30) } -ErrorAction Stop
    if ($wheaErrors) {
        Report WARN 'Errores WHEA (hardware) últimos 30 días' "$($wheaErrors.Count) evento(s) — puede indicar CPU/RAM/PCIe con fallas intermitentes"
    } else {
        Report OK 'Errores WHEA (hardware)' 'ninguno en 30 días'
    }
} catch { Report OK 'Errores WHEA (hardware)' 'ninguno en 30 días' }

# ═══════════════════════════════════════════════════════════════════
# 3. RAM — capacidad y errores corregidos/no corregidos
# ═══════════════════════════════════════════════════════════════════
Write-Section "3. Memoria RAM"

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    Report OK 'RAM total/libre' "$totalGB GB total, $freeGB GB libre ahora"
}
try {
    $memErrors = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-WHEA'; StartTime = (Get-Date).AddDays(-30) } -ErrorAction Stop |
        Where-Object { $_.Message -match 'memory|memoria' }
    if ($memErrors) {
        Report WARN 'Errores de memoria últimos 30 días' "$($memErrors.Count) evento(s) — considerá correr mdsched.exe (Diagnóstico de memoria de Windows, requiere reinicio)"
    } else {
        Report OK 'Errores de memoria' 'ninguno detectado en 30 días'
    }
} catch { Report OK 'Errores de memoria' 'ninguno detectado en 30 días' }

# ═══════════════════════════════════════════════════════════════════
# 4. DRIVERS — antigüedad, dispositivos con problemas, updates disponibles
# ═══════════════════════════════════════════════════════════════════
Write-Section "4. Drivers"

try {
    $problemDevices = & pnputil /enum-devices /problem 2>$null | Out-String
    if ($problemDevices -match 'Instance ID') {
        Report WARN 'Dispositivos con problemas (pnputil)' 'hay hardware con driver roto/faltante — ver detalle con: pnputil /enum-devices /problem'
    } else {
        Report OK 'Dispositivos con problemas' 'ninguno reportado por pnputil'
    }
} catch { Report WARN 'pnputil' 'no se pudo consultar (¿correr como admin?)' }

try {
    $drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop |
        Where-Object { $_.DeviceName -and $_.DriverDate } |
        Select-Object DeviceName, DriverVersion, @{N='DriverDate';E={[datetime]$_.DriverDate}}, Manufacturer
    $old = $drivers | Where-Object { $_.DriverDate -lt (Get-Date).AddYears(-3) -and $_.Manufacturer -notmatch 'Microsoft' } |
        Sort-Object DriverDate | Select-Object -First 15
    if ($old) {
        Report WARN "Drivers de terceros con +3 años sin actualizar" "$($old.Count) candidato(s) — ver logs\hardware-check-$(Get-Date -Format 'yyyy-MM-dd').log para el detalle"
    } else {
        Report OK 'Antigüedad de drivers' 'nada de terceros con más de 3 años'
    }
} catch { $old = @() }

try {
    $winget = & winget upgrade --accept-source-agreements 2>$null | Out-String
    $driverPublishers = 'Intel', 'NVIDIA', 'Realtek', 'Advanced Micro Devices', 'AMD'
    $driverLines = ($winget -split "`n") | Where-Object { $line = $_; $driverPublishers | Where-Object { $line -match $_ } }
    if ($driverLines) {
        Report WARN 'Actualizaciones disponibles (winget) de fabricantes de driver' "$($driverLines.Count) paquete(s) — correr 'winget upgrade' para ver el detalle, NO se auto-instala nada"
    } else {
        Report OK 'winget upgrade (drivers)' 'sin actualizaciones pendientes de Intel/NVIDIA/Realtek/AMD'
    }
} catch { Report WARN 'winget upgrade' 'no se pudo consultar (¿winget instalado?)' }

Report INFO 'Intel Driver & Support Assistant' 'ya está en keep_always de profile-local.json — es la vía recomendada para drivers Intel (chipset/gráficos/wifi/bluetooth)'

# ═══════════════════════════════════════════════════════════════════
# 5. REPORTE FINAL
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                 REPORTE FINAL                    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  OK   : $($script:nOk)"   -ForegroundColor Green
Write-Host "  WARN : $($script:nWarn)" -ForegroundColor Yellow
Write-Host "  ERROR: $($script:nErr)"  -ForegroundColor Red
Write-Host ""
Write-Host "  Nada de esto se aplica solo — son hallazgos para revisar/confirmar." -ForegroundColor DarkGray
Write-Host ""

$logDir = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$logPath = "$logDir\hardware-check-$(Get-Date -Format 'yyyy-MM-dd').log"
$findings | ForEach-Object { "[$($_.estado)] $($_.item): $($_.detalle)" } | Set-Content -Path $logPath -Encoding UTF8
if ($old) { $old | ForEach-Object { "  Driver viejo: $($_.DeviceName) — $($_.DriverDate.ToString('yyyy-MM-dd')) ($($_.Manufacturer))" } | Add-Content -Path $logPath -Encoding UTF8 }

[PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    ok        = $script:nOk
    warn      = $script:nWarn
    error     = $script:nErr
    findings  = $findings
} | ConvertTo-Json -Depth 5 | Set-Content -Path "$scriptRoot\data\last-hardware-check.json" -Encoding UTF8

Wait-KeyIfInteractive -Auto:$Auto
