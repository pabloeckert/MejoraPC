#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$scriptRoot    = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Ensure-DataDirectory -ScriptRoot $scriptRoot

$profilePath   = "$scriptRoot\data\hardware-profile.json"
$recoPath      = "$scriptRoot\data\recommendations.json"
$smartRecoPath = "$scriptRoot\data\smart-recommendations.json"
$usageDir      = "$scriptRoot\logs\usage"

function Show-Dashboard {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  DASHBOARD — MejoraPC                                        ║" -ForegroundColor Cyan
    Write-Host "  ║  $(((Get-Date).ToString('dddd dd/MM/yyyy HH:mm')).PadRight(56))║" -ForegroundColor DarkCyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # ── HARDWARE SUMMARY + SCORE ──────────────────────────────────────────────
    if (Test-Path $profilePath) {
        try {
            $hw    = Get-Content $profilePath -Raw | ConvertFrom-Json
            $score = Get-SystemScore -ProfilePath $profilePath
            $sc    = if ($score -ge 70) { 'Green' } elseif ($score -ge 40) { 'Yellow' } else { 'Red' }
            $bar   = ('█' * [int]($score / 5)) + ('░' * (20 - [int]($score / 5)))

            Write-Host "  ┌─ HARDWARE ─────────────────────────────────────────────────" -ForegroundColor DarkCyan

            if ($hw.cpu) {
                $cpuShort = ($hw.cpu.model -replace 'Intel\(R\)|AMD|Core\(TM\)|Processor|CPU|@.*', '' -replace '\s+', ' ').Trim()
                Write-Host "  │ CPU : $cpuShort" -ForegroundColor White
                Write-Host "  │      $($hw.cpu.physicalCores) núcleos / $($hw.cpu.logicalCores) hilos @ $($hw.cpu.baseFreqMHz) MHz" -ForegroundColor DarkGray
            }

            if ($hw.ram) {
                $ramGB = [math]::Round($hw.ram.totalBytes / 1GB, 0)
                Write-Host "  │ RAM : $ramGB GB $($hw.ram.type) @ $($hw.ram.speedMHz) MHz | Slots: $($hw.ram.slotsFilled)/$($hw.ram.slotsTotal)" -ForegroundColor White
            }

            if ($hw.gpu -and $hw.gpu.Count -gt 0) {
                $g       = $hw.gpu[0]
                $gpuName = $g.model; if ($gpuName.Length -gt 42) { $gpuName = $gpuName.Substring(0, 42) }
                Write-Host "  │ GPU : $gpuName | $($g.vramGB) GB VRAM" -ForegroundColor White
            }

            foreach ($disk in $hw.storage) {
                $dc = switch ($disk.health) { 'Healthy' { 'Green' }; 'Warning' { 'Yellow' }; 'Critical' { 'Red' }; default { 'Yellow' } }
                $dm = $disk.model; if ($dm.Length -gt 30) { $dm = $dm.Substring(0, 30) }
                Write-Host "  │ [$($disk.type.PadRight(4))] $dm | $($disk.sizeGB) GB | $($disk.usedPercent)% usado | $($disk.health)" -ForegroundColor $dc
            }

            Write-Host "  │" -ForegroundColor DarkCyan
            Write-Host "  │ Score  " -NoNewline -ForegroundColor DarkGray
            Write-Host $bar -NoNewline -ForegroundColor $sc
            Write-Host " $score/100" -ForegroundColor $sc

            $health = if ($score -ge 80) { 'Excelente' } elseif ($score -ge 60) { 'Bueno' } elseif ($score -ge 40) { 'Regular' } else { 'Necesita atención' }
            Write-Host "  │ Estado $health" -ForegroundColor $sc
            Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host ""
        } catch { }
    } else {
        Write-Host "  [!] Sin perfil de hardware — ejecutá el Escaneo (opción 7)." -ForegroundColor Yellow
        Write-Host ""
    }

    # ── GRÁFICO CPU/RAM ÚLTIMAS 24HS ─────────────────────────────────────────
    $todayFile = "$usageDir\$(Get-Date -Format 'yyyy-MM-dd').json"
    if (Test-Path $todayFile) {
        try {
            $dayData = Get-Content $todayFile -Raw | ConvertFrom-Json
            $samples = @($dayData.samples)

            if ($samples.Count -gt 0) {
                $hourCpu = @{}; $hourRam = @{}
                foreach ($s in $samples) {
                    $h = if ($s.time) { $s.time.Split(':')[0].TrimStart('0') } else { '0' }
                    if (-not $h) { $h = '0' }
                    if (-not $hourCpu[$h]) { $hourCpu[$h] = [System.Collections.ArrayList]@(); $hourRam[$h] = [System.Collections.ArrayList]@() }
                    $null = $hourCpu[$h].Add($s.cpuPct)
                    $null = $hourRam[$h].Add($s.ramPct)
                }

                $hours   = $hourCpu.Keys | Sort-Object { [int]$_ }
                $cpuVals = @(); $ramVals = @(); $labels = @()
                foreach ($h in $hours) {
                    $cpuVals += [int](($hourCpu[$h] | Measure-Object -Average).Average)
                    $ramVals += [int](($hourRam[$h] | Measure-Object -Average).Average)
                    $labels  += "${h}h"
                }

                Write-Host "  ┌─ USO HOY — ÚLTIMAS 24HS (promedio por hora) ───────────────" -ForegroundColor DarkCyan
                Write-Host ""
                Write-AsciiChart -Values $cpuVals -Labels $labels -Title 'CPU %' -MaxWidth 32
                Write-AsciiChart -Values $ramVals -Labels $labels -Title 'RAM %' -MaxWidth 32
                Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
                Write-Host ""
            }
        } catch { }
    }

    # ── TOP 5 PROCESOS DE LA SEMANA ───────────────────────────────────────────
    $allLogs = Read-UsageLogs -LogsDir $usageDir -DaysBack 7
    if ($allLogs -and $allLogs.Count -gt 0) {
        $procAgg = @{}
        foreach ($log in $allLogs) {
            foreach ($s in $log.samples) {
                foreach ($p in $s.processes) {
                    if (-not $procAgg[$p.name]) { $procAgg[$p.name] = [ordered]@{ cpu = 0.0; ram = 0; count = 0 } }
                    $procAgg[$p.name].cpu   += $p.cpuSec
                    $procAgg[$p.name].ram   += $p.ramMB
                    $procAgg[$p.name].count += 1
                }
            }
        }

        $top5 = $procAgg.GetEnumerator() |
            Sort-Object { $_.Value.cpu } -Descending |
            Select-Object -First 5

        Write-Host "  ┌─ TOP 5 PROCESOS — ÚLTIMA SEMANA ───────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  │  Proceso                  CPU total    RAM promedio" -ForegroundColor Gray
        Write-Host "  │  ──────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($e in $top5) {
            $name   = $e.Key.PadRight(24).Substring(0, 24)
            $cpu    = "$([int]$e.Value.cpu)s".PadLeft(12)
            $avgRam = if ($e.Value.count -gt 0) { [int]($e.Value.ram / $e.Value.count) } else { 0 }
            $ram    = (ConvertTo-HumanReadable ($avgRam * 1MB)).PadLeft(12)
            Write-Host "  │  $name $cpu $ram" -ForegroundColor White
        }
        Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host ""
    }

    # ── RECOMENDACIONES ───────────────────────────────────────────────────────
    $anyReco = $false

    if (Test-Path $recoPath) {
        try {
            $hwReco = Get-Content $recoPath -Raw | ConvertFrom-Json
            $hwItems = @($hwReco.items | Where-Object { $_ })
            if ($hwItems.Count -gt 0) {
                $anyReco = $true
                Write-Host "  ┌─ RECOMENDACIONES DE HARDWARE ($($hwItems.Count)) ──────────────────────" -ForegroundColor Yellow
                foreach ($r in $hwItems | Sort-Object { switch ($_.priority) { 'Alta' { 0 }; 'Media' { 1 }; default { 2 } } }) {
                    $color = switch ($r.priority) { 'Alta' { 'Red' }; 'Media' { 'Yellow' }; default { 'Green' } }
                    Write-Host "  │ [$($r.priority.PadRight(5))] $($r.title)" -ForegroundColor $color
                }
                Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor Yellow
                Write-Host ""
            }
        } catch { }
    }

    if (Test-Path $smartRecoPath) {
        try {
            $sr      = Get-Content $smartRecoPath -Raw | ConvertFrom-Json
            $pending = @($sr.items | Where-Object { $_ -and -not $_.applied })
            if ($pending.Count -gt 0) {
                $anyReco = $true
                Write-Host "  ┌─ RECOMENDACIONES INTELIGENTES ($($pending.Count) pendientes) ──────────" -ForegroundColor Green
                if ($sr.generated) {
                    Write-Host "  │ Generadas: $([datetime]::Parse($sr.generated).ToString('yyyy-MM-dd HH:mm')) | Analizadas: $($sr.analyzed) muestras" -ForegroundColor DarkGray
                }
                Write-Host "  │" -ForegroundColor DarkCyan
                $shown = 0
                foreach ($r in $pending | Sort-Object { switch ($_.priority) { 'Alta' { 0 }; 'Media' { 1 }; default { 2 } } }) {
                    if ($shown -ge 8) { Write-Host "  │ ... y $($pending.Count - $shown) más" -ForegroundColor DarkGray; break }
                    $color = switch ($r.priority) { 'Alta' { 'Red' }; 'Media' { 'Yellow' }; default { 'Green' } }
                    $desc  = $r.description; if ($desc.Length -gt 62) { $desc = $desc.Substring(0, 62) + '...' }
                    Write-Host "  │ [$($r.priority.PadRight(5))] $($r.title)" -ForegroundColor $color
                    Write-Host "  │         $desc" -ForegroundColor DarkGray
                    $shown++
                }
                Write-Host "  └─────────────────────────────────────────────────────────────" -ForegroundColor Green
                Write-Host ""
            }
        } catch { }
    }

    if (-not $anyReco) {
        Write-Host "  [+] Sin recomendaciones pendientes. El sistema está optimizado." -ForegroundColor Green
        Write-Host ""
    }

    # ── SCORE FINAL ───────────────────────────────────────────────────────────
    $score  = Get-SystemScore -ProfilePath $profilePath
    $sc     = if ($score -ge 70) { 'Green' } elseif ($score -ge 40) { 'Yellow' } else { 'Red' }
    $health = if ($score -ge 80) { 'Excelente' } elseif ($score -ge 60) { 'Bueno' } elseif ($score -ge 40) { 'Regular' } else { 'Necesita atención' }
    $bar    = ('█' * [int]($score / 5)) + ('░' * (20 - [int]($score / 5)))

    Write-Host "  SCORE GLOBAL: " -NoNewline -ForegroundColor DarkGray
    Write-Host $bar -NoNewline -ForegroundColor $sc
    Write-Host " $score/100 — $health" -ForegroundColor $sc
    Write-Host ""

    Write-Host "  [R] Actualizar   [0] Volver" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Opción: " -NoNewline -ForegroundColor White
}

do {
    Show-Dashboard
    $choice = Read-Host
} while ($choice -eq 'R' -or $choice -eq 'r')
