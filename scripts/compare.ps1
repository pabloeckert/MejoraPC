# ============================================================
# COMPARE - Comparar benchmarks entre PCs o sesiones
# ============================================================
# Compara dos archivos de benchmark y muestra diferencias.
# Útil para: comparar antes/después, comparar entre PCs,
# detectar degradación del sistema.
# ============================================================

param(
    [string]$File1 = "",
    [string]$File2 = "",
    [ValidateSet("compare", "list", "trend")]
    [string]$Action = "compare"
)

. "$PSScriptRoot\config.ps1"

function Get-BenchmarkFiles {
    $files = Get-ChildItem (Join-Path $LogDir "benchmark_*.json") -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "latest" } |
        Sort-Object LastWriteTime -Descending
    return $files
}

function Show-FileList {
    Write-Header "📋 BENCHMARKS DISPONIBLES"
    $files = Get-BenchmarkFiles
    if ($files.Count -eq 0) {
        Write-Info "No hay benchmarks guardados."
        Write-Info "Ejecutá: .\benchmark.ps1 -Mode antes"
        return $files
    }
    Write-Host ""
    for ($i = 0; $i -lt $files.Count; $i++) {
        $data = Get-Content $files[$i].FullName -Raw | ConvertFrom-Json
        $date = $data.Timestamp
        $ram = "$($data.Memory.Free)GB libre"
        $cpu = "$($data.CPU.Load)% CPU"
        $type = $data.DriveType
        Write-Host "    [$($i+1)] $date — $ram, $cpu, $type" -ForegroundColor Cyan
        Write-Host "        $($files[$i].Name)" -ForegroundColor DarkGray
    }
    Write-Host ""
    return $files
}

# ============================================================
# COMPARAR DOS BENCHMARKS
# ============================================================
function Compare-Benchmarks {
    $files = Get-BenchmarkFiles
    
    if ($files.Count -lt 2 -and !$File1 -and !$File2) {
        Write-Info "Necesitás al menos 2 benchmarks para comparar."
        Write-Info "Ejecutá: .\benchmark.ps1 -Mode antes"
        return
    }
    
    # Seleccionar archivos
    if (!$File1 -or !$File2) {
        $files = Show-FileList
        if ($files.Count -lt 2) { return }
        
        Write-Host "  Seleccioná el benchmark ANTES (el viejo):" -ForegroundColor Yellow
        $choice1 = Read-Host "  Número"
        $idx1 = [int]$choice1 - 1
        if ($idx1 -lt 0 -or $idx1 -ge $files.Count) { Write-Error "Selección inválida."; return }
        
        Write-Host "  Seleccioná el benchmark DESPUÉS (el nuevo):" -ForegroundColor Yellow
        $choice2 = Read-Host "  Número"
        $idx2 = [int]$choice2 - 1
        if ($idx2 -lt 0 -or $idx2 -ge $files.Count) { Write-Error "Selección inválida."; return }
        
        $File1 = $files[$idx1].FullName
        $File2 = $files[$idx2].FullName
    }
    
    if (!(Test-Path $File1)) { Write-Error "Archivo no encontrado: $File1"; return }
    if (!(Test-Path $File2)) { Write-Error "Archivo no encontrado: $File2"; return }
    
    $before = Get-Content $File1 -Raw | ConvertFrom-Json
    $after = Get-Content $File2 -Raw | ConvertFrom-Json
    
    Write-Header "📊 COMPARACIÓN DE BENCHMARKS"
    
    Write-Host "  ANTES:    $($before.Timestamp)" -ForegroundColor Yellow
    Write-Host "  DESPUÉS:  $($after.Timestamp)" -ForegroundColor Green
    Write-Host ""
    
    # Header de tabla
    Write-Host "  ┌─────────────────────┬──────────────┬──────────────┬──────────────┐" -ForegroundColor DarkGray
    Write-Host "  │ Métrica             │ Antes        │ Después      │ Diferencia   │" -ForegroundColor DarkGray
    Write-Host "  ├─────────────────────┼──────────────┼──────────────┼──────────────┤" -ForegroundColor DarkGray
    
    # RAM Libre
    $ramDiff = [math]::Round($after.Memory.Free - $before.Memory.Free, 2)
    $ramColor = if ($ramDiff -gt 0) { "Green" } elseif ($ramDiff -lt 0) { "Red" } else { "Gray" }
    $ramSign = if ($ramDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ RAM Libre (GB)      │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Memory.Free)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Memory.Free)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${ramSign}${ramDiff}".PadRight(12) -NoNewline -ForegroundColor $ramColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # RAM %
    $pctDiff = [math]::Round($after.Memory.PercentUsed - $before.Memory.PercentUsed, 1)
    $pctColor = if ($pctDiff -lt 0) { "Green" } elseif ($pctDiff -gt 0) { "Red" } else { "Gray" }
    $pctSign = if ($pctDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ RAM Usado (%)       │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Memory.PercentUsed)%".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Memory.PercentUsed)%".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${pctSign}${pctDiff}%".PadRight(12) -NoNewline -ForegroundColor $pctColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # CPU
    $cpuDiff = $after.CPU.Load - $before.CPU.Load
    $cpuColor = if ($cpuDiff -lt 0) { "Green" } elseif ($cpuDiff -gt 0) { "Red" } else { "Gray" }
    $cpuSign = if ($cpuDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ CPU Carga (%)       │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.CPU.Load)%".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.CPU.Load)%".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${cpuSign}${cpuDiff}%".PadRight(12) -NoNewline -ForegroundColor $cpuColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Servicios
    $svcDiff = $after.Services.Running - $before.Services.Running
    $svcColor = if ($svcDiff -lt 0) { "Green" } elseif ($svcDiff -gt 0) { "Red" } else { "Gray" }
    $svcSign = if ($svcDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Servicios           │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Services.Running)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Services.Running)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${svcSign}${svcDiff}".PadRight(12) -NoNewline -ForegroundColor $svcColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Procesos
    $procDiff = $after.Processes.Count - $before.Processes.Count
    $procColor = if ($procDiff -lt 0) { "Green" } elseif ($procDiff -gt 0) { "Red" } else { "Gray" }
    $procSign = if ($procDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Procesos            │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Processes.Count)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Processes.Count)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${procSign}${procDiff}".PadRight(12) -NoNewline -ForegroundColor $procColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Startup
    $startDiff = $after.Startup.Count - $before.Startup.Count
    $startColor = if ($startDiff -lt 0) { "Green" } elseif ($startDiff -gt 0) { "Red" } else { "Gray" }
    $startSign = if ($startDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Startup             │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Startup.Count)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Startup.Count)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${startSign}${startDiff}".PadRight(12) -NoNewline -ForegroundColor $startColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Disco
    $diskDiff = [math]::Round($after.Disk.Free - $before.Disk.Free, 1)
    $diskColor = if ($diskDiff -gt 0) { "Green" } elseif ($diskDiff -lt 0) { "Red" } else { "Gray" }
    $diskSign = if ($diskDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Disco Libre (GB)    │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($before.Disk.Free)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($after.Disk.Free)".PadRight(12) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${diskSign}${diskDiff}".PadRight(12) -NoNewline -ForegroundColor $diskColor
    Write-Host "│" -ForegroundColor DarkGray
    
    Write-Host "  └─────────────────────┴──────────────┴──────────────┴──────────────┘" -ForegroundColor DarkGray
    
    # Score de mejora
    Write-Host ""
    $improvements = 0
    $total = 0
    if ($ramDiff -ne 0) { $total++; if ($ramDiff -gt 0) { $improvements++ } }
    if ($pctDiff -ne 0) { $total++; if ($pctDiff -lt 0) { $improvements++ } }
    if ($cpuDiff -ne 0) { $total++; if ($cpuDiff -lt 0) { $improvements++ } }
    if ($svcDiff -ne 0) { $total++; if ($svcDiff -lt 0) { $improvements++ } }
    if ($procDiff -ne 0) { $total++; if ($procDiff -lt 0) { $improvements++ } }
    if ($startDiff -ne 0) { $total++; if ($startDiff -lt 0) { $improvements++ } }
    if ($diskDiff -ne 0) { $total++; if ($diskDiff -gt 0) { $improvements++ } }
    
    if ($total -gt 0) {
        $score = [math]::Round(($improvements / $total) * 100, 0)
        $scoreColor = if ($score -gt 70) { "Green" } elseif ($score -gt 40) { "Yellow" } else { "Red" }
        Write-Host "  📈 Score de mejora: $score% ($improvements/$total métricas mejoradas)" -ForegroundColor $scoreColor
    }
}

# ============================================================
# TENDENCIA (múltiples benchmarks)
# ============================================================
function Show-Trend {
    $files = Get-BenchmarkFiles
    if ($files.Count -lt 2) {
        Write-Info "Necesitás al menos 2 benchmarks para ver tendencia."
        return
    }
    
    Write-Header "📈 TENDENCIA DE BENCHMARKS"
    Write-Host ""
    
    # Recopilar datos
    $data = @()
    foreach ($f in $files) {
        $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
        $data += $d
    }
    
    # Mostrar tendencia
    Write-Host "  Fecha                RAM Libre   CPU    Servicios  Procesos" -ForegroundColor Gray
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $prev = $null
    foreach ($d in $data) {
        $date = $d.Timestamp
        $ram = "$($d.Memory.Free)GB"
        $cpu = "$($d.CPU.Load)%"
        $svc = "$($d.Services.Running)"
        $proc = "$($d.Processes.Count)"
        
        # Indicadores de tendencia
        $ramIndicator = ""
        if ($prev) {
            $ramDiff = $d.Memory.Free - $prev.Memory.Free
            $ramIndicator = if ($ramDiff -gt 0.1) { " ↑" } elseif ($ramDiff -lt -0.1) { " ↓" } else { " →" }
        }
        
        Write-Host "  $date  $ram$ramIndicator".PadRight(30) -NoNewline -ForegroundColor White
        Write-Host "$cpu".PadRight(8) -NoNewline -ForegroundColor White
        Write-Host "$svc".PadRight(12) -NoNewline -ForegroundColor White
        Write-Host "$proc" -ForegroundColor White
        
        $prev = $d
    }
    
    # Estadísticas
    Write-Host ""
    Write-Host "  ─── ESTADÍSTICAS ───" -ForegroundColor Gray
    
    $ramValues = $data | ForEach-Object { $_.Memory.Free }
    $cpuValues = $data | ForEach-Object { $_.CPU.Load }
    
    $ramAvg = [math]::Round(($ramValues | Measure-Object -Average).Average, 2)
    $ramMin = ($ramValues | Measure-Object -Minimum).Minimum
    $ramMax = ($ramValues | Measure-Object -Maximum).Maximum
    
    $cpuAvg = [math]::Round(($cpuValues | Measure-Object -Average).Average, 1)
    $cpuMin = ($cpuValues | Measure-Object -Minimum).Minimum
    $cpuMax = ($cpuValues | Measure-Object -Maximum).Maximum
    
    Write-Host "  RAM Libre:  Avg=$ramAvg GB  Min=$ramMin GB  Max=$ramMax GB" -ForegroundColor White
    Write-Host "  CPU Carga:  Avg=$cpuAvg%  Min=$cpuMin%  Max=$cpuMax%" -ForegroundColor White
    Write-Host "  Benchmarks: $($data.Count) registros" -ForegroundColor White
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "compare" { Compare-Benchmarks }
    "list"    { Show-FileList }
    "trend"   { Show-Trend }
}
