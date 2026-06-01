#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Ensure-DataDirectory -ScriptRoot $scriptRoot

$profilePath = "$scriptRoot\data\hardware-profile.json"
$recoPath    = "$scriptRoot\data\recommendations.json"
$logPath     = "$scriptRoot\logs\scan-$(Get-Date -Format 'yyyy-MM-dd').json"

# ─── CPU ─────────────────────────────────────────────────────────────────────
function Get-CpuInfo {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1

    $tempC = $null
    # Intentar OpenHardwareMonitor
    try {
        $ohmSensors = Get-CimInstance -Namespace root\OpenHardwareMonitor -ClassName Sensor -ErrorAction Stop |
            Where-Object { $_.SensorType -eq 'Temperature' -and $_.Name -match 'CPU' }
        if ($ohmSensors) {
            $tempC = [math]::Round(($ohmSensors | Measure-Object -Property Value -Average).Average, 1)
        }
    } catch { }

    # Fallback: zona térmica ACPI
    if (-not $tempC) {
        try {
            $zone = Get-CimInstance -Namespace root\WMI -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
                Select-Object -First 1
            if ($zone -and $zone.CurrentTemperature -gt 0) {
                $tempC = [math]::Round(($zone.CurrentTemperature - 2732) / 10, 1)
                # Descartar valores claramente inválidos
                if ($tempC -lt 0 -or $tempC -gt 150) { $tempC = $null }
            }
        } catch { }
    }

    return [ordered]@{
        model         = $cpu.Name.Trim()
        physicalCores = [int]$cpu.NumberOfCores
        logicalCores  = [int]$cpu.NumberOfLogicalProcessors
        baseFreqMHz   = [int]$cpu.MaxClockSpeed
        temperatureC  = $tempC
        architecture  = $cpu.Architecture
        l2CacheKB     = [int]($cpu.L2CacheSize)
        l3CacheKB     = [int]($cpu.L3CacheSize)
        socket        = $cpu.SocketDesignation
    }
}

# ─── RAM ─────────────────────────────────────────────────────────────────────
function Get-RamInfo {
    $os       = Get-CimInstance -ClassName Win32_OperatingSystem
    $modules  = @(Get-CimInstance -ClassName Win32_PhysicalMemory)
    $memArray = Get-CimInstance -ClassName Win32_PhysicalMemoryArray | Select-Object -First 1

    $totalSlots  = if ($memArray) { [int]$memArray.MemoryDevices } else { $modules.Count }
    $slotsFilled = $modules.Count

    $memTypeMap = @{ 24='DDR3'; 26='DDR4'; 34='DDR5'; 22='DDR2'; 20='DDR'; 0='Unknown' }
    $memType    = $memTypeMap[[int]$modules[0].SMBIOSMemoryType]
    if (-not $memType) { $memType = 'Unknown' }

    $speedMHz = if ($modules[0].ConfiguredClockSpeed -and $modules[0].ConfiguredClockSpeed -gt 0) {
        [int]$modules[0].ConfiguredClockSpeed
    } else { [int]$modules[0].Speed }

    $slots = @()
    foreach ($mod in $modules) {
        $mtype = $memTypeMap[[int]$mod.SMBIOSMemoryType]
        $slots += [ordered]@{
            slot         = $mod.DeviceLocator
            capacityGB   = [math]::Round($mod.Capacity / 1GB, 0)
            speedMHz     = if ($mod.ConfiguredClockSpeed -gt 0) { [int]$mod.ConfiguredClockSpeed } else { [int]$mod.Speed }
            manufacturer = $mod.Manufacturer.Trim()
            type         = if ($mtype) { $mtype } else { 'Unknown' }
            partNumber   = $mod.PartNumber.Trim()
        }
    }

    $totalBytes = $os.TotalVisibleMemorySize * 1KB

    return [ordered]@{
        totalBytes   = [long]$totalBytes
        totalGB      = [math]::Round($totalBytes / 1GB, 1)
        type         = $memType
        speedMHz     = $speedMHz
        slotsFilled  = $slotsFilled
        slotsTotal   = $totalSlots
        slotsAvail   = $totalSlots - $slotsFilled
        dualChannel  = ($slotsFilled -ge 2 -and $slotsFilled % 2 -eq 0)
        slots        = $slots
    }
}

# ─── GPU ─────────────────────────────────────────────────────────────────────
function Get-GpuInfo {
    $gpus   = @(Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.AdapterRAM -and $_.AdapterRAM -ne 0 })
    $result = @()

    foreach ($gpu in $gpus) {
        # VRAM: AdapterRAM puede ser negativo en tarjetas > 2GB (desbordamiento uint32)
        $vramBytes = [uint32]$gpu.AdapterRAM
        if ($vramBytes -eq 0) { $vramBytes = 134217728 }  # 128MB mínimo si no reporta

        $tempC = $null
        try {
            $ohmGpu = Get-CimInstance -Namespace root\OpenHardwareMonitor -ClassName Sensor -ErrorAction Stop |
                Where-Object { $_.SensorType -eq 'Temperature' -and $_.Name -match 'GPU' } |
                Select-Object -First 1
            if ($ohmGpu) { $tempC = [math]::Round($ohmGpu.Value, 1) }
        } catch { }

        $driverDate = $null
        if ($gpu.DriverDate) {
            try { $driverDate = ([Management.ManagementDateTimeConverter]::ToDateTime($gpu.DriverDate)).ToString('yyyy-MM-dd') } catch { }
        }

        $result += [ordered]@{
            model         = $gpu.Name.Trim()
            vramBytes     = [long]$vramBytes
            vramGB        = [math]::Round($vramBytes / 1GB, 1)
            driverVersion = $gpu.DriverVersion
            driverDate    = $driverDate
            resolution    = "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
            refreshHz     = [int]$gpu.CurrentRefreshRate
            temperatureC  = $tempC
        }
    }

    return $result
}

# ─── ALMACENAMIENTO ──────────────────────────────────────────────────────────
function Get-StorageInfo {
    $disks  = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $result = @()

    foreach ($disk in $disks) {
        # Tipo de disco
        $diskType = switch ($disk.MediaType) {
            'HDD'         { 'HDD' }
            'SSD'         { 'SSD' }
            'SCM'         { 'NVMe' }
            'Unspecified' { if ($disk.BusType -eq 'NVMe') { 'NVMe' } elseif ($disk.BusType -eq 'SATA') { 'SSD' } else { 'HDD' } }
            default       { $disk.MediaType }
        }
        if ($disk.BusType -eq 'NVMe') { $diskType = 'NVMe' }

        # S.M.A.R.T.
        $health    = 'Unknown'
        $smartData = $null
        try {
            $rel = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop
            $smartData = [ordered]@{
                readErrors  = [long]$rel.ReadErrorsUncorrected
                writeErrors = [long]$rel.WriteErrorsUncorrected
                temperature = if ($rel.Temperature) { [int]$rel.Temperature } else { $null }
                wearLevel   = if ($rel.Wear)        { [int]$rel.Wear }        else { $null }
            }
            $health = if ($rel.ReadErrorsUncorrected -gt 0 -or $rel.WriteErrorsUncorrected -gt 0) { 'Warning' }
                      elseif ($rel.Wear -and $rel.Wear -lt 10) { 'Critical' }
                      else { 'Healthy' }
        } catch { }

        # Uso por volúmenes
        $usedBytes = 0
        $freeBytes = 0
        try {
            $vols = Get-Disk | Where-Object { $_.SerialNumber -eq $disk.SerialNumber } |
                Get-Partition -ErrorAction SilentlyContinue |
                Get-Volume    -ErrorAction SilentlyContinue |
                Where-Object  { $_.DriveLetter }
            if ($vols) {
                $usedBytes = ($vols | ForEach-Object { $_.Size - $_.SizeRemaining } | Measure-Object -Sum).Sum
                $freeBytes = ($vols | Measure-Object -Property SizeRemaining -Sum).Sum
            }
        } catch { }

        $usedPct = if ($disk.Size -gt 0) { [math]::Round(($usedBytes / $disk.Size) * 100, 1) } else { 0 }

        $result += [ordered]@{
            model        = $disk.FriendlyName.Trim()
            type         = $diskType
            busType      = $disk.BusType
            sizeBytes    = [long]$disk.Size
            sizeGB       = [math]::Round($disk.Size / 1GB, 0)
            usedBytes    = [long]$usedBytes
            freeBytes    = [long]$freeBytes
            usedPercent  = $usedPct
            health       = $health
            smart        = $smartData
            serialNumber = $disk.SerialNumber
        }
    }

    return $result
}

# ─── RED ─────────────────────────────────────────────────────────────────────
function Get-NetworkInfo {
    $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    $result   = @()

    foreach ($a in $adapters) {
        $ip = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Select-Object -First 1).IPAddress

        $type = if ($a.PhysicalMediaType -match 'Wireless|802\.11' -or $a.Name -match 'Wi-?Fi|WLAN') {
            'WiFi'
        } else { 'Ethernet' }

        $result += [ordered]@{
            name      = $a.Name
            interface = $a.InterfaceDescription
            mac       = $a.MacAddress
            speedMbps = if ($a.LinkSpeed -gt 0) { [math]::Round($a.LinkSpeed / 1000000, 0) } else { 0 }
            ip        = $ip
            type      = $type
            status    = $a.Status.ToString()
        }
    }

    return $result
}

# ─── PLACA MADRE ─────────────────────────────────────────────────────────────
function Get-MotherboardInfo {
    $board  = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -First 1
    $bios   = Get-CimInstance -ClassName Win32_BIOS      | Select-Object -First 1
    $system = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -First 1

    $biosDate = $null
    if ($bios.ReleaseDate) {
        try { $biosDate = ([Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)).ToString('yyyy-MM-dd') } catch { }
    }

    return [ordered]@{
        manufacturer = $board.Manufacturer.Trim()
        model        = $board.Product.Trim()
        serialNumber = $board.SerialNumber
        biosVersion  = $bios.SMBIOSBIOSVersion
        biosDate     = $biosDate
        biosVendor   = $bios.Manufacturer.Trim()
        systemModel  = $system.Model.Trim()
        systemMfr    = $system.Manufacturer.Trim()
    }
}

# ─── RECOMENDACIONES ─────────────────────────────────────────────────────────
function Get-HardwareRecommendations {
    param($Profile)
    $reco = [System.Collections.ArrayList]@()

    $ramGB    = $Profile.ram.totalGB
    $hasHDD   = @($Profile.storage | Where-Object { $_.type -eq 'HDD' }).Count -gt 0
    $hasSSD   = @($Profile.storage | Where-Object { $_.type -in 'SSD','NVMe' }).Count -gt 0
    $cores    = $Profile.cpu.physicalCores
    $lowVram  = @($Profile.gpu | Where-Object { $_.vramGB -gt 0 -and $_.vramGB -lt 4 })

    if ($ramGB -lt 8) {
        $null = $reco.Add([ordered]@{
            id='ram-pagefile'; priority='Alta'; category='RAM'; applied=$false
            title='Ajustar paginación virtual'
            description="RAM: $ramGB GB. Configurar pagefile a 1.5x la RAM mejora la estabilidad."
            action='Set-VMPageFile'; impact='Alto'
        })
    }

    if ($hasHDD) {
        $null = $reco.Add([ordered]@{
            id='hdd-indexing'; priority='Media'; category='Almacenamiento'; applied=$false
            title='Deshabilitar indexación agresiva en HDD'
            description='El disco mecánico tiene indexación activa. Deshabilitarla reduce la carga de I/O.'
            action='Disable-DiskIndexing'; impact='Medio'
        })
        $null = $reco.Add([ordered]@{
            id='hdd-defrag'; priority='Media'; category='Almacenamiento'; applied=$false
            title='Programar desfragmentación semanal'
            description='Un HDD se beneficia de la desfragmentación periódica.'
            action='Enable-DefragSchedule'; impact='Medio'
        })
    }

    if ($hasSSD) {
        $null = $reco.Add([ordered]@{
            id='ssd-trim'; priority='Alta'; category='Almacenamiento'; applied=$false
            title='Verificar TRIM habilitado en SSD'
            description='TRIM mantiene el rendimiento del SSD a largo plazo.'
            action='Enable-SsdTrim'; impact='Alto'
        })
        if ($hasHDD) {
            $null = $reco.Add([ordered]@{
                id='ssd-no-defrag'; priority='Alta'; category='Almacenamiento'; applied=$false
                title='Deshabilitar defrag en SSD'
                description='El desfragmentador deteriora los SSD. Excluirlos del programa de defrag.'
                action='Disable-SsdDefrag'; impact='Alto'
            })
        }
    }

    if ($cores -lt 4) {
        $null = $reco.Add([ordered]@{
            id='cpu-visual'; priority='Alta'; category='Visual'; applied=$false
            title='Deshabilitar efectos visuales'
            description="CPU con $cores núcleos. Reducir animaciones libera recursos para apps."
            action='Set-PerformanceVisuals'; impact='Alto'
        })
    }

    if ($lowVram.Count -gt 0) {
        $null = $reco.Add([ordered]@{
            id='gpu-vram-low'; priority='Media'; category='GPU'; applied=$false
            title='Optimizar para GPU con VRAM limitada'
            description="GPU con $($lowVram[0].vramGB) GB VRAM. Reducir calidad de texturas y deshabilitar efectos de post-proceso."
            action='Set-LowVramTweaks'; impact='Medio'
        })
    }

    if ($ramGB -ge 16) {
        $null = $reco.Add([ordered]@{
            id='ram-hibernate'; priority='Baja'; category='RAM'; applied=$false
            title='Deshabilitar hibernación (RAM >= 16 GB)'
            description="Con $ramGB GB de RAM, hiberfil.sys ocupa espacio innecesario en disco."
            action='Disable-Hibernation'; impact='Bajo'
        })
    }

    return $reco
}

# ─── REPORTE VISUAL ──────────────────────────────────────────────────────────
function Show-ScanReport {
    param($Profile)

    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║              ESCANEO DE HARDWARE — MejoraPC              ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkGray
    Write-Host ""

    # CPU
    Write-Host "  ┌─ CPU ──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    $cpuStatus = if ($Profile.cpu.physicalCores -lt 4) { 'WARN' } else { 'OK' }
    if ($Profile.cpu.temperatureC -and $Profile.cpu.temperatureC -gt 85) { $cpuStatus = 'ERROR' }
    Write-Status 'Modelo    ' $Profile.cpu.model $cpuStatus
    Write-Status 'Núcleos   ' "$($Profile.cpu.physicalCores) físicos / $($Profile.cpu.logicalCores) lógicos" 'OK'
    Write-Status 'Frecuencia' "$($Profile.cpu.baseFreqMHz) MHz base" 'OK'
    if ($Profile.cpu.temperatureC) {
        Write-Status 'Temp      ' "$($Profile.cpu.temperatureC)°C" (Get-TemperatureStatus -Temp $Profile.cpu.temperatureC -Component CPU)
    } else {
        Write-Status 'Temp      ' 'No disponible (instalar OpenHardwareMonitor)' 'WARN'
    }
    Write-Host ""

    # RAM
    Write-Host "  ┌─ RAM ──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    $ramStatus = if ($Profile.ram.totalGB -lt 4) { 'ERROR' } elseif ($Profile.ram.totalGB -lt 8) { 'WARN' } else { 'OK' }
    Write-Status 'Total     ' "$($Profile.ram.totalGB) GB $($Profile.ram.type) @ $($Profile.ram.speedMHz) MHz" $ramStatus
    Write-Status 'Slots     ' "$($Profile.ram.slotsFilled)/$($Profile.ram.slotsTotal) usados ($($Profile.ram.slotsAvail) libres)" 'OK'
    Write-Status 'Dual Ch.  ' $(if ($Profile.ram.dualChannel) { 'Sí' } else { 'No (rendimiento reducido)' }) $(if ($Profile.ram.dualChannel) { 'OK' } else { 'WARN' })
    foreach ($slot in $Profile.ram.slots) {
        $mfr = $slot.manufacturer
        if ($mfr.Length -gt 12) { $mfr = $mfr.Substring(0, 12) }
        Write-Status "  $($slot.slot.PadRight(14))" "$($slot.capacityGB) GB $mfr @ $($slot.speedMHz) MHz" 'INFO'
    }
    Write-Host ""

    # GPU
    Write-Host "  ┌─ GPU ──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    foreach ($gpu in $Profile.gpu) {
        $gpuStatus = if ($gpu.vramGB -lt 2) { 'WARN' } else { 'OK' }
        $gpuName   = $gpu.model; if ($gpuName.Length -gt 48) { $gpuName = $gpuName.Substring(0, 48) }
        Write-Status 'Modelo    ' $gpuName $gpuStatus
        Write-Status 'VRAM      ' "$($gpu.vramGB) GB" $gpuStatus
        Write-Status 'Driver    ' "$($gpu.driverVersion) ($($gpu.driverDate))" 'OK'
        Write-Status 'Resolución' "$($gpu.resolution) @ $($gpu.refreshHz) Hz" 'OK'
        if ($gpu.temperatureC) {
            Write-Status 'Temp      ' "$($gpu.temperatureC)°C" (Get-TemperatureStatus -Temp $gpu.temperatureC -Component GPU)
        }
    }
    Write-Host ""

    # Almacenamiento
    Write-Host "  ┌─ ALMACENAMIENTO ───────────────────────────────────────────" -ForegroundColor DarkCyan
    foreach ($disk in $Profile.storage) {
        $hs = switch ($disk.health) { 'Healthy' { 'OK' }; 'Warning' { 'WARN' }; 'Critical' { 'ERROR' }; default { 'WARN' } }
        $dm = $disk.model; if ($dm.Length -gt 32) { $dm = $dm.Substring(0, 32) }
        Write-Status "[$($disk.type.PadRight(4))] $dm" "$($disk.sizeGB) GB | $($disk.usedPercent)% usado | $($disk.health)" $hs
        if ($disk.smart -and $disk.smart.temperature) {
            Write-Status '  Temp S.M.A.R.T' "$($disk.smart.temperature)°C" (Get-TemperatureStatus -Temp $disk.smart.temperature -Component Disk)
        }
    }
    Write-Host ""

    # Red
    Write-Host "  ┌─ RED ──────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    foreach ($net in $Profile.network) {
        Write-Status "$($net.type) $($net.name)" "$($net.ip) | $($net.speedMbps) Mbps | $($net.mac)" 'OK'
    }
    Write-Host ""

    # Placa madre
    Write-Host "  ┌─ PLACA MADRE ──────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Status 'Fabricante' $Profile.motherboard.manufacturer 'OK'
    Write-Status 'Modelo    ' $Profile.motherboard.model 'OK'
    Write-Status 'BIOS      ' "$($Profile.motherboard.biosVersion) ($($Profile.motherboard.biosDate))" 'OK'
    Write-Host ""
}

# ─── MAIN ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Escaneando hardware del sistema..." -ForegroundColor Cyan

$steps = @('CPU', 'RAM', 'GPU', 'Almacenamiento', 'Red', 'Placa madre')
$step  = 0
foreach ($s in $steps) {
    $step++
    Write-Host "  [$step/$($steps.Count)] $s..." -ForegroundColor DarkGray
}

$profile = [ordered]@{
    timestamp   = (Get-Date -Format 'o')
    cpu         = (Get-CpuInfo)
    ram         = (Get-RamInfo)
    gpu         = (Get-GpuInfo)
    storage     = (Get-StorageInfo)
    network     = (Get-NetworkInfo)
    motherboard = (Get-MotherboardInfo)
}

Write-Host ""

# Guardar perfil
$profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath -Encoding UTF8
Write-Host "  [+] hardware-profile.json guardado" -ForegroundColor Green

# Generar y guardar recomendaciones
$recs = Get-HardwareRecommendations -Profile $profile
$recoObj = [ordered]@{
    generated = (Get-Date -Format 'o')
    items     = $recs
}
$recoObj | ConvertTo-Json -Depth 10 | Set-Content $recoPath -Encoding UTF8
Write-Host "  [+] recommendations.json guardado ($($recs.Count) recomendaciones)" -ForegroundColor Green

# Log del scan
$profile | ConvertTo-Json -Depth 10 | Set-Content $logPath -Encoding UTF8
Write-Host "  [+] Log: $logPath" -ForegroundColor Green

Start-Sleep -Seconds 1

# Mostrar reporte
Show-ScanReport -Profile $profile

# Mostrar recomendaciones
if ($recs -and $recs.Count -gt 0) {
    Write-Host "  ┌─ RECOMENDACIONES ($($recs.Count)) ───────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""
    foreach ($r in $recs | Sort-Object { switch ($_.priority) { 'Alta' { 0 }; 'Media' { 1 }; default { 2 } } }) {
        $color = switch ($r.priority) { 'Alta' { 'Red' }; 'Media' { 'Yellow' }; default { 'Green' } }
        Write-Host "  [$($r.priority.PadRight(5))] $($r.title)" -ForegroundColor $color
        Write-Host "           $($r.description)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

Write-Host "  Presioná ENTER para volver al menú..." -ForegroundColor DarkGray
$null = Read-Host
