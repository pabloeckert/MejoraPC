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
