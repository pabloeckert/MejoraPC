# ============================================================
# HTML REPORT - Generar reporte HTML del benchmark
# ============================================================
. "$PSScriptRoot\config.ps1"

param(
    [string]$InputFile = "",
    [string]$OutputFile = ""
)

# Si no se especifica input, usar el último benchmark
if (!$InputFile) {
    $InputFile = Join-Path $LogDir "benchmark_latest.json"
}

if (!(Test-Path $InputFile)) {
    Write-Error "No se encontró el archivo de benchmark: $InputFile"
    Write-Info "Ejecutá primero: .\benchmark.ps1 -Mode antes"
    exit 1
}

$data = Get-Content $InputFile -Raw | ConvertFrom-Json

# Si no se especifica output, generar nombre
if (!$OutputFile) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $OutputFile = Join-Path $LogDir "report_$timestamp.html"
}

# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

function Get-StatusColor {
    param([double]$Value, [double]$WarnThreshold, [double]$CritThreshold, [bool]$Invert = $false)
    if ($Invert) {
        if ($Value -lt $CritThreshold) { return "#e74c3c" }
        if ($Value -lt $WarnThreshold) { return "#f39c12" }
        return "#27ae60"
    } else {
        if ($Value -gt $CritThreshold) { return "#e74c3c" }
        if ($Value -gt $WarnThreshold) { return "#f39c12" }
        return "#27ae60"
    }
}

function Get-StatusEmoji {
    param([double]$Value, [double]$WarnThreshold, [double]$CritThreshold, [bool]$Invert = $false)
    if ($Invert) {
        if ($Value -lt $CritThreshold) { return "🔴" }
        if ($Value -lt $WarnThreshold) { return "🟡" }
        return "🟢"
    } else {
        if ($Value -gt $CritThreshold) { return "🔴" }
        if ($Value -gt $WarnThreshold) { return "🟡" }
        return "🟢"
    }
}

function Get-BarWidth {
    param([double]$Value, [double]$Max = 100)
    return [math]::Min([math]::Round(($Value / $Max) * 100, 0), 100)
}

# ============================================================
# GENERAR HTML
# ============================================================

$ramColor = Get-StatusColor -Value $data.Memory.PercentUsed -WarnThreshold 70 -CritThreshold 85
$ramEmoji = Get-StatusEmoji -Value $data.Memory.PercentUsed -WarnThreshold 70 -CritThreshold 85
$ramBarW = Get-BarWidth -Value $data.Memory.PercentUsed

$cpuColor = Get-StatusColor -Value $data.CPU.Load -WarnThreshold 50 -CritThreshold 80
$cpuEmoji = Get-StatusEmoji -Value $data.CPU.Load -WarnThreshold 50 -CritThreshold 80
$cpuBarW = Get-BarWidth -Value $data.CPU.Load

$diskColor = Get-StatusColor -Value $data.Disk.PercentUsed -WarnThreshold 80 -CritThreshold 90
$diskEmoji = Get-StatusEmoji -Value $data.Disk.PercentUsed -WarnThreshold 80 -CritThreshold 90
$diskBarW = Get-BarWidth -Value $data.Disk.PercentUsed

$svcColor = if ($data.Services.Running -gt 100) { "#f39c12" } else { "#27ae60" }
$procColor = if ($data.Processes.Count -gt 200) { "#f39c12" } else { "#27ae60" }

# Top 5 procesos por RAM
$topProcsHtml = ""
if ($data.Processes.Top5) {
    foreach ($p in $data.Processes.Top5) {
        $procBarW = [math]::Min([math]::Round(($p.RAM_MB / 500) * 100, 0), 100)
        $topProcsHtml += @"
        <div class="proc-row">
            <span class="proc-name">$($p.Name)</span>
            <div class="proc-bar-container">
                <div class="proc-bar" style="width: $procBarW%; background: $(if($p.RAM_MB -gt 200){"#e74c3c"}elseif($p.RAM_MB -gt 100){"#f39c12"}else{"#3498db"})"></div>
            </div>
            <span class="proc-value">$($p.RAM_MB) MB</span>
        </div>
"@
    }
}

# Diagnóstico
$issuesHtml = ""
$hasIssues = $false

$issues = @()
if ($data.Memory.PercentUsed -gt 80) { $issues += @{ Icon = "🔴"; Text = "RAM alta ($($data.Memory.PercentUsed)%)" } }
if ($data.Memory.Free -lt 1.5) { $issues += @{ Icon = "🔴"; Text = "RAM libre baja ($($data.Memory.Free) GB)" } }
if ($data.CPU.Load -gt 70) { $issues += @{ Icon = "🟡"; Text = "CPU alta ($($data.CPU.Load)%)" } }
if ($data.Disk.PercentUsed -gt 85) { $issues += @{ Icon = "🟡"; Text = "Disco lleno ($($data.Disk.PercentUsed)%)" } }
if ($data.Startup.Count -gt 10) { $issues += @{ Icon = "🟡"; Text = "Muchos programas de inicio ($($data.Startup.Count))" } }
if ($data.Services.Running -gt 100) { $issues += @{ Icon = "🟡"; Text = "Muchos servicios ($($data.Services.Running))" } }

if ($issues.Count -gt 0) {
    $hasIssues = $true
    foreach ($issue in $issues) {
        $issuesHtml += "<div class='issue'>$($issue.Icon) $($issue.Text)</div>"
    }
} else {
    $issuesHtml = "<div class='issue ok'>✅ Sistema en buen estado</div>"
}

# Comparación con benchmark anterior (si existe)
$comparisonHtml = ""
$antesFiles = Get-ChildItem (Join-Path $LogDir "benchmark_antes_*.json") -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
if ($antesFiles.Count -gt 1) {
    $prev = Get-Content $antesFiles[1].FullName -Raw | ConvertFrom-Json
    $ramDiff = [math]::Round($data.Memory.Free - $prev.Memory.Free, 2)
    $cpuDiff = $prev.CPU.Load - $data.CPU.Load
    $svcDiff = $prev.Services.Running - $data.Services.Running
    
    $ramDiffColor = if ($ramDiff -gt 0) { "#27ae60" } elseif ($ramDiff -lt 0) { "#e74c3c" } else { "#95a5a6" }
    $cpuDiffColor = if ($cpuDiff -gt 0) { "#27ae60" } elseif ($cpuDiff -lt 0) { "#e74c3c" } else { "#95a5a6" }
    $svcDiffColor = if ($svcDiff -gt 0) { "#27ae60" } elseif ($svcDiff -lt 0) { "#e74c3c" } else { "#95a5a6" }
    
    $comparisonHtml = @"
    <div class="card">
        <h2>📈 Comparación con benchmark anterior</h2>
        <div class="comparison-grid">
            <div class="comp-item">
                <div class="comp-label">RAM Libre</div>
                <div class="comp-diff" style="color: $ramDiffColor">$(if($ramDiff -gt 0){"+"})$ramDiff GB</div>
                <div class="comp-detail">$($prev.Memory.Free) → $($data.Memory.Free) GB</div>
            </div>
            <div class="comp-item">
                <div class="comp-label">CPU Carga</div>
                <div class="comp-diff" style="color: $cpuDiffColor">$(if($cpuDiff -gt 0){"+"})$cpuDiff%</div>
                <div class="comp-detail">$($prev.CPU.Load)% → $($data.CPU.Load)%</div>
            </div>
            <div class="comp-item">
                <div class="comp-label">Servicios</div>
                <div class="comp-diff" style="color: $svcDiffColor">$(if($svcDiff -gt 0){"−"})$svcDiff</div>
                <div class="comp-detail">$($prev.Services.Running) → $($data.Services.Running)</div>
            </div>
        </div>
    </div>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MejoraNotebook — Reporte del Sistema</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', -apple-system, sans-serif;
            background: #0f0f23;
            color: #e0e0e0;
            padding: 2rem;
            min-height: 100vh;
        }
        .container { max-width: 900px; margin: 0 auto; }
        h1 {
            font-size: 1.8rem;
            color: #00d4ff;
            margin-bottom: 0.3rem;
        }
        .subtitle {
            color: #7f8c8d;
            font-size: 0.9rem;
            margin-bottom: 2rem;
        }
        .card {
            background: #1a1a2e;
            border-radius: 12px;
            padding: 1.5rem;
            margin-bottom: 1.5rem;
            border: 1px solid #2a2a4a;
        }
        .card h2 {
            font-size: 1.1rem;
            color: #b8b8d4;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 1px solid #2a2a4a;
        }
        .system-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1rem;
        }
        .sys-item {
            display: flex;
            justify-content: space-between;
            padding: 0.4rem 0;
        }
        .sys-label { color: #7f8c8d; }
        .sys-value { color: #fff; font-weight: 500; }
        
        .metric-row {
            display: flex;
            align-items: center;
            gap: 1rem;
            margin-bottom: 1rem;
        }
        .metric-label {
            width: 80px;
            font-size: 0.85rem;
            color: #7f8c8d;
        }
        .metric-bar-container {
            flex: 1;
            height: 24px;
            background: #2a2a4a;
            border-radius: 12px;
            overflow: hidden;
        }
        .metric-bar {
            height: 100%;
            border-radius: 12px;
            transition: width 0.5s ease;
            display: flex;
            align-items: center;
            justify-content: flex-end;
            padding-right: 8px;
            font-size: 0.75rem;
            font-weight: 600;
            color: #fff;
        }
        .metric-value {
            width: 80px;
            text-align: right;
            font-weight: 600;
            font-size: 0.9rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
        }
        .stat-item {
            text-align: center;
            padding: 1rem;
            background: #16213e;
            border-radius: 8px;
        }
        .stat-value {
            font-size: 2rem;
            font-weight: 700;
        }
        .stat-label {
            font-size: 0.8rem;
            color: #7f8c8d;
            margin-top: 0.3rem;
        }
        
        .proc-row {
            display: flex;
            align-items: center;
            gap: 0.8rem;
            margin-bottom: 0.6rem;
        }
        .proc-name { width: 140px; font-size: 0.85rem; color: #b8b8d4; }
        .proc-bar-container {
            flex: 1;
            height: 16px;
            background: #2a2a4a;
            border-radius: 8px;
            overflow: hidden;
        }
        .proc-bar {
            height: 100%;
            border-radius: 8px;
        }
        .proc-value { width: 60px; text-align: right; font-size: 0.85rem; color: #7f8c8d; }
        
        .issue {
            padding: 0.5rem 0;
            font-size: 0.9rem;
        }
        .issue.ok { color: #27ae60; }
        
        .comparison-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
        }
        .comp-item {
            text-align: center;
            padding: 1rem;
            background: #16213e;
            border-radius: 8px;
        }
        .comp-label { font-size: 0.8rem; color: #7f8c8d; }
        .comp-diff { font-size: 1.5rem; font-weight: 700; margin: 0.3rem 0; }
        .comp-detail { font-size: 0.75rem; color: #555; }
        
        .footer {
            text-align: center;
            color: #555;
            font-size: 0.8rem;
            margin-top: 2rem;
            padding-top: 1rem;
            border-top: 1px solid #2a2a4a;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 MejoraNotebook — Reporte del Sistema</h1>
        <div class="subtitle">Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | $($data.DriveType) | $($data.System.OS) Build $($data.System.Build)</div>
        
        <div class="card">
            <h2>💻 Sistema</h2>
            <div class="system-grid">
                <div class="sys-item"><span class="sys-label">CPU</span><span class="sys-value">$($data.System.CPU)</span></div>
                <div class="sys-item"><span class="sys-label">RAM</span><span class="sys-value">$($data.System.RAM_Total) GB</span></div>
                <div class="sys-item"><span class="sys-label">GPU</span><span class="sys-value">$($data.System.GPU)</span></div>
                <div class="sys-item"><span class="sys-label">Modelo</span><span class="sys-value">$($data.System.Manufacturer) $($data.System.Model)</span></div>
                <div class="sys-item"><span class="sys-label">Cores</span><span class="sys-value">$($data.System.CPUCores) cores / $($data.System.CPUThreads) threads</span></div>
                <div class="sys-item"><span class="sys-label">Disco</span><span class="sys-value">$($data.Disk.Letter) $($data.Disk.Free)/$($data.Disk.Total) GB libre</span></div>
            </div>
        </div>
        
        <div class="card">
            <h2>📊 Estado del Sistema</h2>
            <div class="metric-row">
                <span class="metric-label">RAM</span>
                <div class="metric-bar-container">
                    <div class="metric-bar" style="width: $ramBarW%; background: $ramColor">$ramEmoji $($data.Memory.PercentUsed)%</div>
                </div>
                <span class="metric-value" style="color: $ramColor">$($data.Memory.Free) GB libres</span>
            </div>
            <div class="metric-row">
                <span class="metric-label">CPU</span>
                <div class="metric-bar-container">
                    <div class="metric-bar" style="width: $cpuBarW%; background: $cpuColor">$cpuEmoji $($data.CPU.Load)%</div>
                </div>
                <span class="metric-value" style="color: $cpuColor">$($data.CPU.Load)% carga</span>
            </div>
            <div class="metric-row">
                <span class="metric-label">Disco</span>
                <div class="metric-bar-container">
                    <div class="metric-bar" style="width: $diskBarW%; background: $diskColor">$diskEmoji $($data.Disk.PercentUsed)%</div>
                </div>
                <span class="metric-value" style="color: $diskColor">$($data.Disk.Free) GB libres</span>
            </div>
        </div>
        
        <div class="card">
            <h2>📈 Estadísticas</h2>
            <div class="stats-grid">
                <div class="stat-item">
                    <div class="stat-value" style="color: $svcColor">$($data.Services.Running)</div>
                    <div class="stat-label">Servicios corriendo</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" style="color: $procColor">$($data.Processes.Count)</div>
                    <div class="stat-label">Procesos activos</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value" style="color: $(if($data.Startup.Count -gt 10){"#f39c12"}else{"#27ae60"})">$($data.Startup.Count)</div>
                    <div class="stat-label">Programas de inicio</div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>🔝 Top 5 Procesos por RAM</h2>
            $topProcsHtml
        </div>
        
        <div class="card">
            <h2>🔍 Diagnóstico</h2>
            $issuesHtml
        </div>
        
        $comparisonHtml
        
        <div class="footer">
            MejoraNotebook v3.0.0 — Reporte generado automáticamente<br>
            <a href="https://github.com/pabloeckert/MejoraNotebook" style="color: #3498db">github.com/pabloeckert/MejoraNotebook</a>
        </div>
    </div>
</body>
</html>
"@

$html | Out-File $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║           REPORTE HTML GENERADO                      ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📄 $OutputFile" -ForegroundColor White
Write-Host ""
Write-Info "Abrí el archivo en tu navegador para ver el reporte."
Log "Reporte HTML generado: $OutputFile"
