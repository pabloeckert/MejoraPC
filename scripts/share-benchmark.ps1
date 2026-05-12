# ============================================================
# SHARE BENCHMARK - Exportar/importar benchmarks entre PCs
# ============================================================
# Permite compartir benchmarks entre computadoras para comparar.
# Exporta a JSON portátil que se puede importar en otra PC.
# ============================================================

param(
    [ValidateSet("export", "import", "compare")]
    [string]$Action = "export",
    [string]$File = ""
)

. "$PSScriptRoot\config.ps1"

function Export-Benchmark {
    Write-Header "📤 EXPORTAR BENCHMARK"
    
    # Buscar el benchmark más reciente
    $benchmarkFile = Join-Path $LogDir "benchmark_latest.json"
    if (!(Test-Path $benchmarkFile)) {
        Write-Info "No hay benchmark reciente."
        Write-Info "Ejecutá primero: .\benchmark.ps1 -Mode rapido"
        return
    }
    
    $data = Get-Content $benchmarkFile -Raw | ConvertFrom-Json
    
    # Crear archivo portable
    $portable = @{
        Version = "1.0"
        Source = "MejoraNotebook"
        ExportedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Computer = @{
            Name = $env:COMPUTERNAME
            User = $env:USERNAME
            OS = $data.System.OS
            Build = $data.System.Build
            CPU = $data.System.CPU
            RAM_GB = $data.System.RAM_Total
            GPU = $data.System.GPU
            Model = $data.System.Model
            DriveType = $data.DriveType
        }
        Benchmark = $data
    }
    
    # Guardar
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $computerName = $env:COMPUTERNAME -replace '[^a-zA-Z0-9]', '_'
    $exportFile = Join-Path $LogDir "benchmark_${computerName}_${timestamp}.portable.json"
    
    $portable | ConvertTo-Json -Depth 10 | Out-File $exportFile -Encoding UTF8
    
    $size = [math]::Round((Get-Item $exportFile).Length / 1KB, 1)
    
    Write-Success "Benchmark exportado"
    Write-Host ""
    Write-Host "  📄 Archivo: $exportFile" -ForegroundColor White
    Write-Host "  📦 Tamaño: $size KB" -ForegroundColor White
    Write-Host ""
    Write-Info "Copiá este archivo a otra PC y ejecutá:"
    Write-Info "  .\scripts\share-benchmark.ps1 -Action import -File '$exportFile'"
    Write-Host ""
    Write-Info "O compará directamente:"
    Write-Info "  .\scripts\share-benchmark.ps1 -Action compare -File '$exportFile'"
    
    Log "Benchmark exportado: $exportFile"
}

function Import-Benchmark {
    if (!$File) {
        Write-Host "  Ruta del archivo .portable.json:" -ForegroundColor White
        $File = Read-Host "  Ruta"
    }
    
    if (!(Test-Path $File)) {
        Write-Error "Archivo no encontrado: $File"
        return
    }
    
    Write-Header "📥 IMPORTAR BENCHMARK"
    
    $portable = Get-Content $File -Raw | ConvertFrom-Json
    
    if ($portable.Source -ne "MejoraNotebook") {
        Write-Error "Este archivo no parece ser un benchmark de MejoraNotebook."
        return
    }
    
    $comp = $portable.Computer
    Write-Host "  Benchmark de:" -ForegroundColor White
    Write-Host "    PC: $($comp.Name)" -ForegroundColor Cyan
    Write-Host "    CPU: $($comp.CPU)" -ForegroundColor Gray
    Write-Host "    RAM: $($comp.RAM_GB) GB" -ForegroundColor Gray
    Write-Host "    GPU: $($comp.GPU)" -ForegroundColor Gray
    Write-Host "    OS: $($comp.OS)" -ForegroundColor Gray
    Write-Host "    Disco: $($comp.DriveType)" -ForegroundColor Gray
    Write-Host "    Fecha: $($portable.ExportedAt)" -ForegroundColor Gray
    Write-Host ""
    
    # Guardar en el directorio de benchmarks
    $importFile = Join-Path $LogDir "benchmark_imported_$($comp.Name)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').json"
    $portable.Benchmark | ConvertTo-Json -Depth 10 | Out-File $importFile -Encoding UTF8
    
    Write-Success "Benchmark importado: $importFile"
    Write-Info "Para comparar: .\scripts\share-benchmark.ps1 -Action compare -File '$File'"
    
    Log "Benchmark importado de $($comp.Name)"
}

function Compare-WithPC {
    if (!$File) {
        Write-Host "  Ruta del archivo .portable.json:" -ForegroundColor White
        $File = Read-Host "  Ruta"
    }
    
    if (!(Test-Path $File)) {
        Write-Error "Archivo no encontrado: $File"
        return
    }
    
    $portable = Get-Content $File -Raw | ConvertFrom-Json
    $remote = $portable.Benchmark
    $comp = $portable.Computer
    
    # Obtener benchmark local
    $localFile = Join-Path $LogDir "benchmark_latest.json"
    if (!(Test-Path $localFile)) {
        Write-Info "No hay benchmark local. Ejecutá: .\benchmark.ps1 -Mode rapido"
        return
    }
    
    $local = Get-Content $localFile -Raw | ConvertFrom-Json
    
    Write-Header "📊 COMPARACIÓN ENTRE PCs"
    Write-Host ""
    Write-Host "  🖥️  LOCAL:    $env:COMPUTERNAME" -ForegroundColor Yellow
    Write-Host "  💻 REMOTO:   $($comp.Name)" -ForegroundColor Cyan
    Write-Host ""
    
    # Header
    Write-Host "  ┌─────────────────────┬────────────────┬────────────────┬──────────────┐" -ForegroundColor DarkGray
    Write-Host "  │ Métrica             │ Local          │ Remoto         │ Diferencia   │" -ForegroundColor DarkGray
    Write-Host "  ├─────────────────────┼────────────────┼────────────────┼──────────────┤" -ForegroundColor DarkGray
    
    # CPU
    $cpuDiff = $local.CPU.Load - $remote.CPU.Load
    $cpuColor = if ($cpuDiff -lt 0) { "Green" } elseif ($cpuDiff -gt 0) { "Red" } else { "Gray" }
    $cpuSign = if ($cpuDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ CPU Carga (%)       │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.CPU.Load)%".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.CPU.Load)%".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${cpuSign}${cpuDiff}%".PadRight(12) -NoNewline -ForegroundColor $cpuColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # RAM Libre
    $ramDiff = [math]::Round($local.Memory.Free - $remote.Memory.Free, 2)
    $ramColor = if ($ramDiff -gt 0) { "Green" } elseif ($ramDiff -lt 0) { "Red" } else { "Gray" }
    $ramSign = if ($ramDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ RAM Libre (GB)      │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.Memory.Free)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.Memory.Free)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${ramSign}${ramDiff}".PadRight(12) -NoNewline -ForegroundColor $ramColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # RAM Total
    Write-Host "  │ RAM Total (GB)      │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.System.RAM_Total)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.System.RAM_Total)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "—".PadRight(12) -NoNewline -ForegroundColor Gray
    Write-Host "│" -ForegroundColor DarkGray
    
    # Servicios
    $svcDiff = $local.Services.Running - $remote.Services.Running
    $svcColor = if ($svcDiff -lt 0) { "Green" } elseif ($svcDiff -gt 0) { "Red" } else { "Gray" }
    $svcSign = if ($svcDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Servicios           │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.Services.Running)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.Services.Running)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${svcSign}${svcDiff}".PadRight(12) -NoNewline -ForegroundColor $svcColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Procesos
    $procDiff = $local.Processes.Count - $remote.Processes.Count
    $procColor = if ($procDiff -lt 0) { "Green" } elseif ($procDiff -gt 0) { "Red" } else { "Gray" }
    $procSign = if ($procDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Procesos            │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.Processes.Count)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.Processes.Count)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${procSign}${procDiff}".PadRight(12) -NoNoNewline -ForegroundColor $procColor
    Write-Host "│" -ForegroundColor DarkGray
    
    # Disco
    $diskDiff = [math]::Round($local.Disk.Free - $remote.Disk.Free, 1)
    $diskColor = if ($diskDiff -gt 0) { "Green" } elseif ($diskDiff -lt 0) { "Red" } else { "Gray" }
    $diskSign = if ($diskDiff -gt 0) { "+" } else { "" }
    Write-Host "  │ Disco Libre (GB)    │ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($local.Disk.Free)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($remote.Disk.Free)".PadRight(16) -NoNewline -ForegroundColor White
    Write-Host "│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "${diskSign}${diskDiff}".PadRight(12) -NoNewline -ForegroundColor $diskColor
    Write-Host "│" -ForegroundColor DarkGray
    
    Write-Host "  └─────────────────────┴────────────────┴────────────────┴──────────────┘" -ForegroundColor DarkGray
    
    # Info de hardware
    Write-Host ""
    Write-Host "  ─── HARDWARE ───" -ForegroundColor Gray
    Write-Host "  Local:  $($local.System.CPU) / $($local.System.RAM_Total) GB / $($local.DriveType)" -ForegroundColor White
    Write-Host "  Remoto: $($remote.System.CPU) / $($remote.System.RAM_Total) GB / $($comp.DriveType)" -ForegroundColor White
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "export"  { Export-Benchmark }
    "import"  { Import-Benchmark }
    "compare" { Compare-WithPC }
}
