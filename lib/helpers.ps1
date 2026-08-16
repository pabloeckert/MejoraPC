# Funciones compartidas para todos los módulos de MejoraPC

function Write-Status {
    param(
        [string]$Label,
        [string]$Value,
        [ValidateSet('OK','WARN','ERROR','INFO')]
        [string]$Status = 'INFO'
    )
    $icon  = switch ($Status) { 'OK' { '[+]' }; 'WARN' { '[!]' }; 'ERROR' { '[x]' }; default { '[·]' } }
    $color = switch ($Status) { 'OK' { 'Green' }; 'WARN' { 'Yellow' }; 'ERROR' { 'Red' }; default { 'Gray' } }
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$($Label): " -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}

function ConvertTo-HumanReadable {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return '{0:N2} TB' -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Write-AsciiChart {
    param(
        [array]$Values,
        [array]$Labels,
        [string]$Title    = '',
        [int]$MaxWidth    = 35,
        [string]$Unit     = '%',
        [int]$MaxValue    = 100
    )
    if ($Title) { Write-Host "  $Title" -ForegroundColor DarkCyan }
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $val    = [Math]::Max(0, [Math]::Min([int]$Values[$i], $MaxValue))
        $filled = [int](($val / $MaxValue) * $MaxWidth)
        $bar    = ('█' * $filled) + ('░' * ($MaxWidth - $filled))
        $label  = if ($Labels -and $i -lt $Labels.Count) { $Labels[$i] } else { "$i" }
        $lpad   = $label.PadRight(6).Substring(0, 6)
        $color  = if ($val -ge 85) { 'Red' } elseif ($val -ge 60) { 'Yellow' } else { 'Green' }
        Write-Host "  $lpad " -NoNewline -ForegroundColor Gray
        Write-Host $bar -NoNewline -ForegroundColor $color
        Write-Host " $val$Unit" -ForegroundColor White
    }
    Write-Host ""
}

function Read-UsageLogs {
    param(
        [string]$LogsDir,
        [int]$DaysBack = 7
    )
    $logs = [System.Collections.ArrayList]@()
    for ($i = 0; $i -le $DaysBack; $i++) {
        $dateStr = (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd')
        $logFile = Join-Path $LogsDir "$dateStr.json"
        if (Test-Path $logFile) {
            try {
                $content = Get-Content $logFile -Raw | ConvertFrom-Json
                $null = $logs.Add($content)
            } catch { }
        }
    }
    return $logs
}

function Get-SystemScore {
    param([string]$ProfilePath)
    if (-not (Test-Path $ProfilePath)) { return 50 }
    try {
        $p = Get-Content $ProfilePath -Raw | ConvertFrom-Json
        if (-not $p.cpu) { return 50 }
        $score = 100
        $ramGB = if ($p.ram.totalGB) { $p.ram.totalGB } else { [math]::Round($p.ram.totalBytes / 1GB, 1) }
        if     ($ramGB -lt 4)  { $score -= 30 }
        elseif ($ramGB -lt 8)  { $score -= 15 }
        elseif ($ramGB -lt 16) { $score -= 5  }
        if ($p.storage) {
            $hddCount = @($p.storage | Where-Object { $_.type -eq 'HDD' }).Count
            $ssdCount = @($p.storage | Where-Object { $_.type -in 'SSD','NVMe' }).Count
            if ($hddCount -gt 0 -and $ssdCount -eq 0) { $score -= 20 }
        }
        $cores = if ($p.cpu.physicalCores) { $p.cpu.physicalCores } else { 2 }
        if     ($cores -lt 2) { $score -= 20 }
        elseif ($cores -lt 4) { $score -= 10 }
        if ($p.cpu.temperatureC) {
            if     ($p.cpu.temperatureC -gt 90) { $score -= 15 }
            elseif ($p.cpu.temperatureC -gt 75) { $score -= 7  }
        }
        return [Math]::Max(0, [Math]::Min(100, $score))
    } catch { return 50 }
}

function Get-TemperatureStatus {
    param([double]$Temp, [string]$Component = 'CPU')
    $thresholds = @{
        CPU  = @{ OK = 70; WARN = 85 }
        GPU  = @{ OK = 75; WARN = 90 }
        Disk = @{ OK = 45; WARN = 55 }
    }
    $t = if ($thresholds[$Component]) { $thresholds[$Component] } else { $thresholds['CPU'] }
    if ($Temp -le $t.OK)   { return 'OK'    }
    if ($Temp -le $t.WARN) { return 'WARN'  }
    return 'ERROR'
}

function Get-MergedBloatCatalog {
    # Universal (cualquier Windows 11) + data/profile-local.json si existe
    # (perfil de esta máquina: nunca viaja en el paquete USB).
    param([string]$ScriptRoot)
    $u = Get-Content "$ScriptRoot\data\universal-bloatware.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $pPath = "$ScriptRoot\data\profile-local.json"
    if (Test-Path $pPath) {
        $p = Get-Content $pPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($p.blockA_extra -and $p.blockA_extra.groups) {
            foreach ($g in $p.blockA_extra.groups.PSObject.Properties) {
                $u.blockA.groups | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.blockB) { $u | Add-Member -NotePropertyName 'blockB' -NotePropertyValue $p.blockB -Force }
        if ($p.keep_always) { $u | Add-Member -NotePropertyName 'keep_always' -NotePropertyValue $p.keep_always -Force }
    }
    return $u
}

function Get-MergedTweaksCatalog {
    # Universal (cualquier Windows 11) + data/profile-local.json si existe
    # (perfil de esta máquina: nunca viaja en el paquete USB).
    param([string]$ScriptRoot)
    $u = Get-Content "$ScriptRoot\data\universal-tweaks.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $pPath = "$ScriptRoot\data\profile-local.json"
    if (Test-Path $pPath) {
        $p = Get-Content $pPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($p.registry) {
            foreach ($g in $p.registry.PSObject.Properties) {
                $u.registry | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.startup_disable) {
            foreach ($g in $p.startup_disable.PSObject.Properties) {
                $u.startup_disable | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.ram_recoverable_estimate) {
            foreach ($g in $p.ram_recoverable_estimate.PSObject.Properties) {
                $u.ram_recoverable_estimate | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
            $sum = 0
            foreach ($g in $u.ram_recoverable_estimate.PSObject.Properties) {
                if ($g.Name -ne 'total_mb') { $sum += [int]$g.Value }
            }
            $u.ram_recoverable_estimate | Add-Member -NotePropertyName 'total_mb' -NotePropertyValue $sum -Force
        }
    }
    return $u
}

function Get-DiagnosticHeader {
    # Encabezado de contexto para logs/ultimo-diagnostico.txt — info del
    # equipo/entorno que ayuda a diagnosticar remotamente un run.ps1 corrido
    # en una PC ajena (sin acceso directo a esa máquina).
    param([string]$ScriptRoot)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

    $pyVersion = 'no detectado'
    foreach ($c in @('python', 'py')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) {
            try { $pyVersion = (& $c --version 2>&1 | Out-String).Trim() } catch { }
            break
        }
    }

    $buildFile = "$ScriptRoot\data\build-version.txt"
    $build = if (Test-Path $buildFile) { (Get-Content $buildFile -Raw).Trim() } else { 'desarrollo local (sin data\build-version.txt)' }
    $onOneDrive = $ScriptRoot -match 'OneDrive'

    $ramGB = if ($cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { '?' }

    return @"
═══════════════════════════════════════════════════════════
  MejoraPC — Diagnóstico completo
═══════════════════════════════════════════════════════════
Fecha/hora:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Build instalado:   $build
Equipo:            $($cs.Manufacturer) $($cs.Model) — $env:COMPUTERNAME
Windows:           $($os.Caption) $($os.Version) (Build $($os.BuildNumber))
PowerShell:        $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))
Corriendo como admin: $isAdmin
Ruta de ejecución: $ScriptRoot
  ¿Carpeta sincronizada por OneDrive?: $onOneDrive
Python:            $pyVersion
CPU/RAM:           $($cs.NumberOfLogicalProcessors) núcleos lógicos, ${ramGB}GB RAM
═══════════════════════════════════════════════════════════

"@
}

function Wait-KeyIfInteractive {
    param([switch]$Auto)
    if (-not $Auto -and $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected) {
        Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
        $null = Read-Host
    }
}

function Ensure-DataDirectory {
    param([string]$ScriptRoot)
    foreach ($dir in @("$ScriptRoot\data", "$ScriptRoot\logs", "$ScriptRoot\logs\usage")) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    }
}
