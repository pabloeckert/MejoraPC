# ============================================================
# DASHBOARD - Servidor web local con gráficos en tiempo real
# ============================================================
# Levanta un servidor HTTP local que muestra el estado del
# sistema en tiempo real con gráficos interactivos.
# Se abre automáticamente en el navegador.
# ============================================================

param(
    [ValidateSet("start", "status")]
    [string]$Action = "start",
    [int]$Port = 8080
)

. "$PSScriptRoot\config.ps1"

$DashboardStateFile = Join-Path $RescueDir "dashboard_state.json"

function Get-SystemMetrics {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1
    
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $pctRAM = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
    
    $totalDisk = [math]::Round($disk.Size / 1GB, 0)
    $freeDisk = [math]::Round($disk.FreeSpace / 1GB, 0)
    $pctDisk = [math]::Round((($totalDisk - $freeDisk) / $totalDisk) * 100, 1)
    
    $runningSvc = (Get-Service | Where-Object { $_.Status -eq "Running" } | Measure-Object).Count
    $procCount = (Get-Process | Measure-Object).Count
    
    # Top 5 procesos por RAM
    $topProcs = Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB } |
        Sort-Object WorkingSet64 -Descending | Select-Object -First 5 Name,
        @{N="RAM_MB";E={[math]::Round($_.WorkingSet64/1MB,0)}}
    
    # Estado de optimizaciones
    $turboActive = (Test-Path (Join-Path $RescueDir "turbo_state.json"))
    $gamingActive = (Test-Path (Join-Path $RescueDir "gaming_state.json"))
    $netActive = (Test-Path (Join-Path $RescueDir "network_state.json"))
    $wuBlocked = (Test-Path (Join-Path $RescueDir "wu_blocker_state.json"))
    
    return @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        CPU = @{
            Name = $cpu.Name
            Load = $cpu.LoadPercentage
            Cores = $cpu.NumberOfCores
        }
        RAM = @{
            Total = $totalRAM
            Used = $usedRAM
            Free = $freeRAM
            Percent = $pctRAM
        }
        Disk = @{
            Letter = $disk.DeviceID
            Total = $totalDisk
            Free = $freeDisk
            Percent = $pctDisk
        }
        System = @{
            Services = $runningSvc
            Processes = $procCount
            SSD = $Global:IsSSD
        }
        TopProcesses = $topProcs | ForEach-Object {
            @{ Name = $_.Name; RAM_MB = $_.RAM_MB }
        }
        Optimizations = @{
            TurboBoost = $turboActive
            GamingMode = $gamingActive
            Network = $netActive
            WUBlocked = $wuBlocked
        }
    }
}

function Start-Dashboard {
    Write-Header "📊 INICIANDO DASHBOARD"
    
    # Guardar estado
    @{
        Active = $true
        Port = $Port
        StartedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } | ConvertTo-Json | Out-File $DashboardStateFile -Encoding UTF8
    
    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MejoraNotebook — Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #0a0a1a; color: #e0e0e0; padding: 1rem; }
        .header { text-align: center; padding: 1.5rem; background: linear-gradient(135deg, #1a1a2e, #16213e); border-radius: 12px; margin-bottom: 1.5rem; }
        .header h1 { color: #00d4ff; font-size: 1.5rem; }
        .header .subtitle { color: #7f8c8d; font-size: 0.85rem; margin-top: 0.3rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
        .card { background: #1a1a2e; border-radius: 12px; padding: 1.2rem; border: 1px solid #2a2a4a; }
        .card h2 { font-size: 1rem; color: #b8b8d4; margin-bottom: 0.8rem; display: flex; align-items: center; gap: 0.5rem; }
        .metric { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.6rem; }
        .metric-label { color: #7f8c8d; font-size: 0.85rem; }
        .metric-value { font-weight: 600; font-size: 1.1rem; }
        .bar-container { width: 100%; height: 20px; background: #2a2a4a; border-radius: 10px; overflow: hidden; margin: 0.5rem 0; }
        .bar { height: 100%; border-radius: 10px; transition: width 1s ease; display: flex; align-items: center; justify-content: flex-end; padding-right: 8px; font-size: 0.75rem; font-weight: 600; }
        .status-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; }
        .status-item { display: flex; align-items: center; gap: 0.5rem; padding: 0.4rem; background: #16213e; border-radius: 6px; font-size: 0.85rem; }
        .dot { width: 8px; height: 8px; border-radius: 50%; }
        .dot-green { background: #27ae60; }
        .dot-red { background: #e74c3c; }
        .dot-yellow { background: #f39c12; }
        .proc-row { display: flex; justify-content: space-between; padding: 0.3rem 0; font-size: 0.85rem; border-bottom: 1px solid #2a2a4a; }
        .proc-name { color: #b8b8d4; }
        .proc-ram { color: #7f8c8d; }
        .refresh-btn { background: #00d4ff; color: #0a0a1a; border: none; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; font-weight: 600; }
        .refresh-btn:hover { background: #00b8d9; }
        .auto-refresh { display: flex; align-items: center; gap: 0.5rem; margin-top: 0.5rem; font-size: 0.8rem; color: #7f8c8d; }
        .timestamp { text-align: center; color: #555; font-size: 0.75rem; margin-top: 1rem; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔥 MejoraNotebook — Dashboard</h1>
        <div class="subtitle">Monitoreo en tiempo real</div>
    </div>
    
    <div class="grid">
        <div class="card">
            <h2>🖥️ CPU</h2>
            <div class="metric">
                <span class="metric-label">Carga</span>
                <span class="metric-value" id="cpu-value">—</span>
            </div>
            <div class="bar-container">
                <div class="bar" id="cpu-bar" style="width: 0%"></div>
            </div>
            <div class="metric">
                <span class="metric-label">Procesador</span>
                <span style="font-size: 0.8rem; color: #7f8c8d" id="cpu-name">—</span>
            </div>
        </div>
        
        <div class="card">
            <h2>💾 RAM</h2>
            <div class="metric">
                <span class="metric-label">Uso</span>
                <span class="metric-value" id="ram-value">—</span>
            </div>
            <div class="bar-container">
                <div class="bar" id="ram-bar" style="width: 0%"></div>
            </div>
            <div class="metric">
                <span class="metric-label">Libre</span>
                <span style="font-size: 0.85rem" id="ram-free">—</span>
            </div>
        </div>
        
        <div class="card">
            <h2>💿 Disco</h2>
            <div class="metric">
                <span class="metric-label">Uso</span>
                <span class="metric-value" id="disk-value">—</span>
            </div>
            <div class="bar-container">
                <div class="bar" id="disk-bar" style="width: 0%"></div>
            </div>
            <div class="metric">
                <span class="metric-label">Libre</span>
                <span style="font-size: 0.85rem" id="disk-free">—</span>
            </div>
        </div>
        
        <div class="card">
            <h2>⚡ Estado</h2>
            <div class="status-grid">
                <div class="status-item"><div class="dot" id="dot-turbo"></div> Turbo Boost</div>
                <div class="status-item"><div class="dot" id="dot-gaming"></div> Gaming Mode</div>
                <div class="status-item"><div class="dot" id="dot-network"></div> Network</div>
                <div class="status-item"><div class="dot" id="dot-wu"></div> Win Update</div>
            </div>
            <div style="margin-top: 0.8rem">
                <div class="metric"><span class="metric-label">Servicios</span><span id="svc-count">—</span></div>
                <div class="metric"><span class="metric-label">Procesos</span><span id="proc-count">—</span></div>
            </div>
        </div>
    </div>
    
    <div class="card" style="max-width: 600px; margin: 0 auto;">
        <h2>🔝 Top 5 Procesos por RAM</h2>
        <div id="top-procs">Cargando...</div>
    </div>
    
    <div style="text-align: center; margin-top: 1rem;">
        <button class="refresh-btn" onclick="refresh()">🔄 Actualizar</button>
        <div class="auto-refresh">
            <input type="checkbox" id="auto-refresh" checked>
            <label for="auto-refresh">Auto-actualizar cada 5s</label>
        </div>
    </div>
    
    <div class="timestamp" id="timestamp"></div>
    
    <script>
        function getStatusColor(value, warn, crit, invert) {
            if (invert) {
                if (value < crit) return '#e74c3c';
                if (value < warn) return '#f39c12';
                return '#27ae60';
            } else {
                if (value > crit) return '#e74c3c';
                if (value > warn) return '#f39c12';
                return '#27ae60';
            }
        }
        
        function refresh() {
            fetch('/api/metrics')
                .then(r => r.json())
                .then(data => {
                    // CPU
                    const cpuColor = getStatusColor(data.CPU.Load, 50, 80);
                    document.getElementById('cpu-value').textContent = data.CPU.Load + '%';
                    document.getElementById('cpu-value').style.color = cpuColor;
                    document.getElementById('cpu-bar').style.width = data.CPU.Load + '%';
                    document.getElementById('cpu-bar').style.background = cpuColor;
                    document.getElementById('cpu-bar').textContent = data.CPU.Load + '%';
                    document.getElementById('cpu-name').textContent = data.CPU.Name;
                    
                    // RAM
                    const ramColor = getStatusColor(data.RAM.Percent, 70, 85);
                    document.getElementById('ram-value').textContent = data.RAM.Percent + '%';
                    document.getElementById('ram-value').style.color = ramColor;
                    document.getElementById('ram-bar').style.width = data.RAM.Percent + '%';
                    document.getElementById('ram-bar').style.background = ramColor;
                    document.getElementById('ram-bar').textContent = data.RAM.Percent + '%';
                    document.getElementById('ram-free').textContent = data.RAM.Free + ' GB libre de ' + data.RAM.Total + ' GB';
                    
                    // Disk
                    const diskColor = getStatusColor(data.Disk.Percent, 80, 90);
                    document.getElementById('disk-value').textContent = data.Disk.Percent + '%';
                    document.getElementById('disk-value').style.color = diskColor;
                    document.getElementById('disk-bar').style.width = data.Disk.Percent + '%';
                    document.getElementById('disk-bar').style.background = diskColor;
                    document.getElementById('disk-bar').textContent = data.Disk.Percent + '%';
                    document.getElementById('disk-free').textContent = data.Disk.Free + ' GB libre de ' + data.Disk.Total + ' GB';
                    
                    // Status dots
                    document.getElementById('dot-turbo').className = 'dot ' + (data.Optimizations.TurboBoost ? 'dot-red' : 'dot-green');
                    document.getElementById('dot-gaming').className = 'dot ' + (data.Optimizations.GamingMode ? 'dot-green' : 'dot-yellow');
                    document.getElementById('dot-network').className = 'dot ' + (data.Optimizations.Network ? 'dot-green' : 'dot-yellow');
                    document.getElementById('dot-wu').className = 'dot ' + (data.Optimizations.WUBlocked ? 'dot-red' : 'dot-green');
                    
                    // Counts
                    document.getElementById('svc-count').textContent = data.System.Services;
                    document.getElementById('proc-count').textContent = data.System.Processes;
                    
                    // Top processes
                    let procsHtml = '';
                    if (data.TopProcesses && data.TopProcesses.length > 0) {
                        data.TopProcesses.forEach(p => {
                            procsHtml += '<div class="proc-row"><span class="proc-name">' + p.Name + '</span><span class="proc-ram">' + p.RAM_MB + ' MB</span></div>';
                        });
                    }
                    document.getElementById('top-procs').innerHTML = procsHtml || 'Sin datos';
                    
                    // Timestamp
                    document.getElementById('timestamp').textContent = 'Última actualización: ' + data.Timestamp;
                })
                .catch(err => {
                    console.error('Error fetching metrics:', err);
                });
        }
        
        // Auto-refresh
        setInterval(() => {
            if (document.getElementById('auto-refresh').checked) {
                refresh();
            }
        }, 5000);
        
        // Initial load
        refresh();
    </script>
</body>
</html>
"@
    
    # Crear servidor HTTP
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    
    try {
        $listener.Start()
        Write-Success "Dashboard iniciado en: http://localhost:$Port"
        Write-Host ""
        Write-Info "Abriendo navegador..."
        Start-Process "http://localhost:$Port"
        Write-Host ""
        Write-Info "Presioná Ctrl+C para detener el servidor."
        Write-Host ""
        
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            if ($request.Url.LocalPath -eq "/api/metrics") {
                # API: devolver métricas como JSON
                $metrics = Get-SystemMetrics
                $json = $metrics | ConvertTo-Json -Depth 5
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } else {
                # HTML: devolver dashboard
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            $response.Close()
        }
    } catch {
        Write-Host ""
        Write-Info "Dashboard detenido."
    } finally {
        $listener.Stop()
        Remove-Item $DashboardStateFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "start"  { Start-Dashboard }
    "status" {
        if (Test-Path $DashboardStateFile) {
            $state = Get-Content $DashboardStateFile -Raw | ConvertFrom-Json
            Write-Host "  Dashboard activo en: http://localhost:$($state.Port)" -ForegroundColor Green
        } else {
            Write-Host "  Dashboard no está activo." -ForegroundColor Yellow
        }
    }
}
