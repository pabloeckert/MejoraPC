# ============================================================
# DRIVER UPDATER - Verificar actualizaciones de drivers
# ============================================================
# Escanea drivers instalados y verifica si hay actualizaciones
# disponibles via Windows Update. No instala drivers de terceros.
# ============================================================

param(
    [ValidateSet("scan", "status")]
    [string]$Action = "scan"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🔧 DRIVER UPDATER"

# ============================================================
# ESCANEAR DRIVERS
# ============================================================
function Scan-Drivers {
    Write-Host "  Escaneando drivers instalados..." -ForegroundColor White
    Write-Host ""

    # 1. Obtener todos los drivers con problemas
    Write-Step 1 "Buscando drivers con problemas..."
    $problemDevices = Get-PnpDevice | Where-Object { $_.Status -ne "OK" -and $_.Status -ne "Unknown" }
    if ($problemDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "  ⚠️  Drivers con problemas:" -ForegroundColor Red
        foreach ($dev in $problemDevices) {
            $statusColor = switch ($dev.Status) {
                "Error" { "Red" }
                "Degraded" { "Yellow" }
                default { "Gray" }
            }
            Write-Host "    ❌ $($dev.FriendlyName)" -ForegroundColor $statusColor
            Write-Host "       Status: $($dev.Status) | Clase: $($dev.Class)" -ForegroundColor Gray
            if ($dev.InstanceId) {
                Write-Host "       ID: $($dev.InstanceId)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Success "No se encontraron drivers con problemas"
    }

    # 2. Drivers por categoría
    Write-Host ""
    Write-Step 2 "Listando drivers por categoría..."
    Write-Host ""

    $categories = @(
        @{ Name = "🖥️ Display (Video)"; Filter = "Display" }
        @{ Name = "🔊 Audio"; Filter = "Media" }
        @{ Name = "🌐 Red"; Filter = "Net" }
        @{ Name = "⌨️ Input"; Filter = "HIDClass" }
        @{ Name = "💾 Storage"; Filter = "SCSIAdapter" }
        @{ Name = "🔌 USB"; Filter = "USB" }
        @{ Name = "🖨️ Print"; Filter = "Printer" }
        @{ Name = "📷 Camera"; Filter = "Camera" }
        @{ Name = "🔋 Battery"; Filter = "Battery" }
        @{ Name = "🔲 Bluetooth"; Filter = "Bluetooth" }
    )

    foreach ($cat in $categories) {
        $drivers = Get-PnpDevice -Class $cat.Filter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "OK" }
        if ($drivers.Count -gt 0) {
            Write-Host "  $($cat.Name) ($($drivers.Count) dispositivos)" -ForegroundColor Cyan
            foreach ($drv in $drivers) {
                $driverDate = $drv.InstallDate
                $dateStr = if ($driverDate) { $driverDate.ToString("yyyy-MM-dd") } else { "N/A" }
                Write-Host "    • $($drv.FriendlyName)" -ForegroundColor White
                Write-Host "      Fecha: $dateStr | Status: $($drv.Status)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }

    # 3. Verificar drivers pendientes de Windows Update
    Write-Step 3 "Verificando actualizaciones pendientes..."
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $searcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 AND Type='Driver'")
        
        if ($searchResult.Updates.Count -gt 0) {
            Write-Host ""
            Write-Host "  📥 Actualizaciones de drivers disponibles:" -ForegroundColor Green
            foreach ($update in $searchResult.Updates) {
                Write-Host "    • $($update.Title)" -ForegroundColor White
                Write-Host "      $($update.Description)" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Info "Para instalar: Configuración → Windows Update → Buscar actualizaciones"
        } else {
            Write-Success "No hay actualizaciones de drivers pendientes"
        }
    } catch {
        Write-Warn "No se pudo verificar Windows Update (servicio puede estar desactivado)"
    }

    # 4. Información del sistema
    Write-Host ""
    Write-Step 4 "Resumen del sistema..."
    Write-Host ""

    $gpu = Get-CimInstance Win32_VideoController
    $audio = Get-CimInstance Win32_SoundDevice
    $net = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true }

    Write-Host "  🖥️  GPU:" -ForegroundColor Cyan
    foreach ($g in $gpu) {
        $driverVer = $g.DriverVersion
        $driverDate = $g.DriverDate
        Write-Host "    $($g.Name)" -ForegroundColor White
        Write-Host "    Driver: $driverVer | Fecha: $($driverDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "  🔊 Audio:" -ForegroundColor Cyan
    foreach ($a in $audio) {
        Write-Host "    $($a.Name)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  🌐 Red:" -ForegroundColor Cyan
    foreach ($n in $net) {
        Write-Host "    $($n.Name)" -ForegroundColor White
        Write-Host "    MAC: $($n.MACAddress) | Speed: $($n.Speed)" -ForegroundColor Gray
    }

    # 5. Exportar reporte
    Write-Host ""
    Write-Step 5 "Generando reporte..."
    $reportFile = Join-Path $LogDir "drivers_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"
    
    $report = @()
    $report += "=== DRIVER REPORT ==="
    $report += "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "Sistema: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    $report += ""
    
    $report += "=== DRIVERS CON PROBLEMAS ==="
    if ($problemDevices.Count -gt 0) {
        foreach ($dev in $problemDevices) {
            $report += "  [$($dev.Status)] $($dev.FriendlyName)"
            $report += "    ID: $($dev.InstanceId)"
        }
    } else {
        $report += "  Ninguno"
    }
    $report += ""
    
    $report += "=== TODOS LOS DRIVERS ==="
    Get-PnpDevice -Status OK | ForEach-Object {
        $report += "  $($_.FriendlyName) | $($_.Class) | $($_.Status)"
    }
    
    $report | Out-File $reportFile -Encoding UTF8
    Write-Success "Reporte guardado: $reportFile"

    Log "Driver scan completado: $($problemDevices.Count) problemas encontrados"
}

# ============================================================
# STATUS
# ============================================================
function Show-DriverStatus {
    Write-Header "📊 DRIVER STATUS"

    $problemDevices = Get-PnpDevice | Where-Object { $_.Status -ne "OK" -and $_.Status -ne "Unknown" }
    $totalDrivers = (Get-PnpDevice -Status OK | Measure-Object).Count

    Write-Host "  Total drivers OK: $totalDrivers" -ForegroundColor Green
    Write-Host "  Drivers con problemas: $($problemDevices.Count)" -ForegroundColor $(if ($problemDevices.Count -gt 0) { "Red" } else { "Green" })

    if ($problemDevices.Count -gt 0) {
        Write-Host ""
        foreach ($dev in $problemDevices) {
            Write-Host "    ❌ $($dev.FriendlyName) — $($dev.Status)" -ForegroundColor Red
        }
    }

    # GPU info
    Write-Host ""
    $gpu = Get-CimInstance Win32_VideoController
    foreach ($g in $gpu) {
        Write-Host "  🖥️  $($g.Name)" -ForegroundColor Cyan
        Write-Host "     Driver: $($g.DriverVersion) | VRAM: $([math]::Round($g.AdapterRAM/1MB, 0)) MB" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Info "Escanear: .\driver-updater.ps1 -Action scan"
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "scan"    { Scan-Drivers }
    "status"  { Show-DriverStatus }
}
