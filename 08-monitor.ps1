[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Collect,
    [switch]$Analyze,
    [switch]$EnableAutoTune,
    [switch]$Status
)

$scriptRoot   = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Ensure-DataDirectory -ScriptRoot $scriptRoot

$taskMonitor   = 'MejoraPC-Monitor'
$taskAnalysis  = 'MejoraPC-WeeklyAnalysis'
$taskAutoTune  = 'MejoraPC-AutoTune'
$usageDir      = "$scriptRoot\logs\usage"
$smartRecoPath = "$scriptRoot\data\smart-recommendations.json"
$retentionDays = 30
$maxFileSizeKB = 500

# ─── RECOLECCIÓN DE MÉTRICAS ──────────────────────────────────────────────────
function Invoke-MetricCollection {
    $now     = Get-Date
    $dateStr = $now.ToString('yyyy-MM-dd')
    $logFile = "$usageDir\$dateStr.json"

    # CPU %
    $cpuLoad = [int](Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average).Average

    # RAM %
    $os       = Get-CimInstance -ClassName Win32_OperatingSystem
    $ramTotal = $os.TotalVisibleMemorySize
    $ramFree  = $os.FreePhysicalMemory
    $ramPct   = [math]::Round((($ramTotal - $ramFree) / $ramTotal) * 100, 1)

    # Disco I/O % — los contadores de rendimiento requieren admin; usar null si no disponible
    $diskIO = $null
    $diskCounters = @(
        '\PhysicalDisk(_Total)\% Disk Time',
        '\LogicalDisk(_Total)\% Disk Time',
        '\LogicalDisk(C:)\% Disk Time'
    )
    foreach ($counter in $diskCounters) {
        try {
            $c = Get-Counter $counter -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
            $val = [math]::Round($c.CounterSamples[0].CookedValue, 1)
            if ($val -ge 0) { $diskIO = $val; break }
        } catch { }
    }

    # Top 10 procesos por CPU acumulado
    $topProcs = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne 0 -and $_.CPU } |
        Sort-Object CPU -Descending | Select-Object -First 10 |
        ForEach-Object {
            [ordered]@{
                name   = $_.ProcessName
                pid    = $_.Id
                cpuSec = [math]::Round($_.CPU, 1)
                ramMB  = [math]::Round($_.WorkingSet64 / 1MB, 0)
            }
        })

    $sample = [ordered]@{
        time      = $now.ToString('HH:mm')
        cpuPct    = $cpuLoad
        ramPct    = $ramPct
        diskIOPct = $diskIO
        processes = $topProcs
    }

    # Leer log del día o crear nuevo
    $samples = [System.Collections.ArrayList]@()
    if (Test-Path $logFile) {
        try {
            $existing = Get-Content $logFile -Raw | ConvertFrom-Json
            $samples  = [System.Collections.ArrayList]@($existing.samples)
        } catch { }
    }
    $null = $samples.Add($sample)

    $dayLog = [ordered]@{ date = $dateStr; samples = $samples }
    $json   = $dayLog | ConvertTo-Json -Depth 10

    # Limitar tamaño: si supera el máximo, descartar primera mitad
    if ([System.Text.Encoding]::UTF8.GetByteCount($json) / 1KB -gt $maxFileSizeKB) {
        $half    = [math]::Floor($samples.Count / 2)
        $samples = [System.Collections.ArrayList]@($samples[$half..($samples.Count - 1)])
        $dayLog  = [ordered]@{ date = $dateStr; samples = $samples }
        $json    = $dayLog | ConvertTo-Json -Depth 10
    }

    $json | Set-Content $logFile -Encoding UTF8

    # Purgar logs viejos
    Get-ChildItem $usageDir -Filter '*.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$retentionDays) } |
        Remove-Item -Force
}

# ─── ANÁLISIS INTELIGENTE ─────────────────────────────────────────────────────
function Invoke-SmartAnalysis {
    $logs = Read-UsageLogs -LogsDir $usageDir -DaysBack 7

    if (-not $logs -or $logs.Count -eq 0) {
        Write-Host '  Sin logs suficientes. Esperá al menos 1 día de monitoreo.' -ForegroundColor Yellow
        return $null
    }

    $allSamples = [System.Collections.ArrayList]@()
    foreach ($log in $logs) {
        foreach ($s in $log.samples) { $null = $allSamples.Add($s) }
    }

    $total = $allSamples.Count
    if ($total -eq 0) { return $null }

    # Preservar estado applied de ejecuciones anteriores
    $prevApplied = @{}
    if (Test-Path $smartRecoPath) {
        try {
            $prev = Get-Content $smartRecoPath -Raw | ConvertFrom-Json
            foreach ($item in $prev.items) {
                if ($item.applied) { $prevApplied[$item.id] = $true }
            }
        } catch { }
    }

    $recommendations = [System.Collections.ArrayList]@()

    # Apps del sistema — no sugerir deshabilitar
    $sysProcs = @('System','Registry','smss','csrss','wininit','services','lsass','svchost',
        'dwm','fontdrvhost','WmiPrvSE','MsMpEng','SearchIndexer','WUDFHost','spoolsv',
        'audiodg','RuntimeBroker','ShellExperienceHost','StartMenuExperienceHost',
        'explorer','conhost','taskhostw','sihost','ctfmon','TextInputHost','SearchHost',
        'SecurityHealthService','SecurityHealthSystray','NisSrv','SgrmBroker')

    # Apps activas del usuario — tampoco sugerir deshabilitar (solo monitorear RAM)
    $knownUserApps = @('chrome','firefox','msedge','opera','brave','vivaldi',
        'spotify','discord','slack','teams','zoom','telegram','whatsapp',
        'code','devenv','notepad++','idea64','rider64','webstorm64','cursor','windsurf',
        'vlc','obs64','obs32','streamlabs','gimp','photoshop','figma',
        'claude','ollama','docker','git','node','python','powershell',
        'WindowsTerminal','wt','cmd')

    # ── Procesos de fondo siempre activos (no son apps del usuario ni del sistema) ──
    $procData = @{}
    foreach ($s in $allSamples) {
        $seenInSample = @{}
        foreach ($p in $s.processes) {
            if ($seenInSample[$p.name]) { continue }
            $seenInSample[$p.name] = $true
            if ($p.name -notin $sysProcs -and $p.name -notin $knownUserApps) {
                if (-not $procData[$p.name]) { $procData[$p.name] = @{count=0; totalRam=0} }
                $procData[$p.name].count++
                $procData[$p.name].totalRam += $p.ramMB
            }
        }
    }

    $suspectBg = $procData.GetEnumerator() |
        Where-Object { $_.Value.count -gt ($total * 0.85) } |
        Sort-Object { $_.Value.totalRam } -Descending | Select-Object -First 5

    foreach ($proc in $suspectBg) {
        $avgRam = [math]::Round($proc.Value.totalRam / $proc.Value.count, 0)
        $id     = "bg-proc-$($proc.Key)"
        $null = $recommendations.Add([ordered]@{
            id          = $id
            applied     = if ($prevApplied[$id]) { $true } else { $false }
            priority    = if ($avgRam -gt 200) { 'Alta' } else { 'Media' }
            category    = 'Procesos background'
            title       = "Proceso background '$($proc.Key)' siempre activo"
            description = "Activo en $($proc.Value.count)/$total muestras usando ~$($avgRam) MB. No es una app directa del usuario — considerá deshabilitarlo."
            impact      = if ($avgRam -gt 200) { 'Alto' } else { 'Medio' }
            module      = '01'
        })
    }

    # ── Horas pico de CPU (umbral bajado a 50% según datos reales) ──
    $hourCpu = @{}
    foreach ($s in $allSamples) {
        $h = if ($s.time) { $s.time.Split(':')[0].TrimStart('0') } else { '0' }
        if (-not $h) { $h = '0' }
        if (-not $hourCpu.ContainsKey($h)) { $hourCpu[$h] = @() }
        $hourCpu[$h] += $s.cpuPct
    }

    $peakHours = @()
    $peakAvgs  = @{}
    foreach ($h in $hourCpu.Keys) {
        $avg = [math]::Round(($hourCpu[$h] | Measure-Object -Average).Average, 1)
        $peakAvgs[$h] = $avg
        if ($avg -gt 50) { $peakHours += "${h}h ($avg%)" }
    }

    if ($peakHours.Count -gt 0) {
        $id = 'peak-hours-powerplan'
        $null = $recommendations.Add([ordered]@{
            id          = $id
            applied     = if ($prevApplied[$id]) { $true } else { $false }
            priority    = 'Media'
            category    = 'Energía'
            title       = 'Horas pico de CPU detectadas'
            description = "CPU supera 50% en: $($peakHours -join ', '). Activar plan Alto Rendimiento en esos horarios."
            impact      = 'Medio'
            module      = '04'
        })
    }

    # ── RAM alta sostenida (umbral bajado a 80% según datos reales) ──
    $ramAvgGlobal = [math]::Round(($allSamples | Measure-Object -Property ramPct -Average).Average, 1)
    $highRam      = @($allSamples | Where-Object { $_.ramPct -gt 80 })
    $highRamPct   = if ($total -gt 0) { [math]::Round(($highRam.Count / $total) * 100, 0) } else { 0 }

    if ($highRamPct -gt 40) {
        $id = 'ram-high-usage'
        $null = $recommendations.Add([ordered]@{
            id          = $id
            applied     = if ($prevApplied[$id]) { $true } else { $false }
            priority    = if ($ramAvgGlobal -gt 85) { 'Alta' } else { 'Media' }
            category    = 'RAM'
            title       = "RAM elevada sostenida (promedio $ramAvgGlobal%)"
            description = "RAM supera el 80% en el $highRamPct% de las muestras. Promedio global: $ramAvgGlobal%. Cerrar apps en segundo plano o ampliar RAM virtual."
            impact      = 'Alto'
            module      = '01'
        })
    }

    # ── Disco I/O alto ──
    $highDisk = @($allSamples | Where-Object { $_.diskIOPct -gt 60 })
    if ($highDisk.Count -gt 3) {
        $peakDiskHours = @($highDisk | ForEach-Object {
            if ($_.time) { $_.time.Split(':')[0] } else { '00' }
        } | Group-Object | Sort-Object Count -Descending | Select-Object -First 3 -ExpandProperty Name)

        $id = 'disk-io-high'
        $null = $recommendations.Add([ordered]@{
            id          = $id
            applied     = if ($prevApplied[$id]) { $true } else { $false }
            priority    = 'Media'
            category    = 'Almacenamiento'
            title       = 'I/O de disco elevado detectado'
            description = "Disco al >60% en $($highDisk.Count) muestras. Horas pico: $($peakDiskHours -join ', ')h. Revisar indexación o antivirus en esos horarios."
            impact      = 'Medio'
            module      = '07'
        })
    }

    # ── Apps de startup no usadas en las primeras 2 horas ──
    try {
        $allStartup = @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop |
            Select-Object -ExpandProperty Name)

        # Leer items ya deshabilitados via StartupApproved (Task Manager style)
        $alreadyDisabled = @()
        foreach ($regKey in @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        )) {
            if (Test-Path $regKey) {
                Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue |
                    Get-Member -MemberType NoteProperty |
                    Where-Object { $_.Name -notmatch '^PS' } |
                    ForEach-Object {
                        $val = (Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue).$($_.Name)
                        # byte[0] = 3 significa deshabilitado
                        if ($val -and $val[0] -eq 3) {
                            $cleanName = $_.Name -replace '\.lnk$',''
                            $alreadyDisabled += $cleanName
                        }
                    }
            }
        }

        # Solo reportar los que están habilitados Y no aparecen en uso temprano
        $enabledStartup = @($allStartup | Where-Object {
            $name = $_
            $nameNoExt = $name -replace '\.lnk$',''
            $alreadyDisabled -notcontains $name -and $alreadyDisabled -notcontains $nameNoExt
        })

        if ($enabledStartup.Count -gt 0) {
            $earlySamples = @($allSamples | Where-Object {
                $h = if ($_.time) { [int]($_.time.Split(':')[0]) } else { 12 }
                $h -ge 7 -and $h -le 10
            })

            $earlyProcs = @()
            foreach ($s in $earlySamples) {
                $earlyProcs += @($s.processes | Select-Object -ExpandProperty name)
            }
            $earlyProcs = $earlyProcs | Sort-Object -Unique

            $unusedStartup = @($enabledStartup | Where-Object {
                $app = $_; $earlyProcs -notcontains $app
            })

            if ($unusedStartup.Count -gt 0) {
                $id = 'startup-unused'
                $null = $recommendations.Add([ordered]@{
                    id          = $id
                    applied     = if ($prevApplied[$id]) { $true } else { $false }
                    priority    = 'Alta'
                    category    = 'Startup'
                    title       = 'Apps de inicio no utilizadas detectadas'
                    description = "Inician con Windows pero no aparecen en las primeras 2hs: $($unusedStartup -join ', '). Considerá deshabilitarlas."
                    impact      = 'Alto'
                    module      = '01'
                })
            }
        }
    } catch { }

    # Guardar preservando applied de items anteriores
    $smartReco = [ordered]@{
        generated = (Get-Date -Format 'o')
        analyzed  = $total
        period    = '7 días'
        items     = $recommendations
    }
    $smartReco | ConvertTo-Json -Depth 10 | Set-Content $smartRecoPath -Encoding UTF8

    return $recommendations
}

# ─── SCHEDULED TASKS ──────────────────────────────────────────────────────────
function Install-MonitorTasks {
    param([switch]$EnableAutoTune)

    $psExe  = "$PSHOME\powershell.exe"
    $script = $PSCommandPath

    # Usar usuario actual si no hay admin (no requiere elevación)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $principal = if ($isAdmin) {
        New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
    } else {
        New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited
    }

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

    # Tarea de recolección: cada 15 minutos
    $action  = New-ScheduledTaskAction -Execute $psExe -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Collect"
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 15) -Once -At (Get-Date).ToString('HH:mm')
    Register-ScheduledTask -TaskName $taskMonitor -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null
    Write-Host "  [+] '$taskMonitor' instalada (cada 15 min)" -ForegroundColor Green

    # Tarea de análisis semanal: domingos 03:00
    $action2  = New-ScheduledTaskAction -Execute $psExe -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Analyze"
    $trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '03:00'
    Register-ScheduledTask -TaskName $taskAnalysis -Action $action2 -Trigger $trigger2 `
        -Settings $settings -Principal $principal -Force | Out-Null
    Write-Host "  [+] '$taskAnalysis' instalada (domingos 03:00)" -ForegroundColor Green

    # AutoTune opcional: domingos 03:30
    if ($EnableAutoTune) {
        $action3  = New-ScheduledTaskAction -Execute $psExe -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Analyze -EnableAutoTune"
        $trigger3 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '03:30'
        Register-ScheduledTask -TaskName $taskAutoTune -Action $action3 -Trigger $trigger3 `
            -Settings $settings -Principal $principal -Force | Out-Null
        Write-Host "  [+] '$taskAutoTune' instalada (AutoTune habilitado)" -ForegroundColor Green
    }
}

function Uninstall-MonitorTasks {
    foreach ($task in @($taskMonitor, $taskAnalysis, $taskAutoTune)) {
        if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false
            Write-Host "  [+] '$task' eliminada" -ForegroundColor Green
        } else {
            Write-Host "  [-] '$task' no estaba instalada" -ForegroundColor DarkGray
        }
    }
}

function Show-TaskStatus {
    Write-Host ""
    Write-Host "  ┌─ ESTADO DE TAREAS PROGRAMADAS ─────────────────────────────" -ForegroundColor DarkCyan
    foreach ($taskName in @($taskMonitor, $taskAnalysis, $taskAutoTune)) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $info    = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
            $lastRun = if ($info.LastRunTime -gt [datetime]'2000-01-01') { $info.LastRunTime.ToString('yyyy-MM-dd HH:mm') } else { 'Nunca' }
            Write-Status $taskName.PadRight(30) "Activa | Último: $lastRun" 'OK'
        } else {
            Write-Status $taskName.PadRight(30) 'No instalada' 'WARN'
        }
    }

    # Stats de logs
    Write-Host ""
    $files = @(Get-ChildItem $usageDir -Filter '*.json' -ErrorAction SilentlyContinue)
    if ($files.Count -gt 0) {
        $totalSamples = 0
        foreach ($f in $files) {
            try { $totalSamples += @((Get-Content $f.FullName -Raw | ConvertFrom-Json).samples).Count } catch { }
        }
        Write-Host "  Datos: $($files.Count) días de logs, $totalSamples muestras totales" -ForegroundColor Gray
    } else {
        Write-Host "  Sin logs de uso aún." -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ─── MAIN ────────────────────────────────────────────────────────────────────

# Modos no interactivos (invocados por scheduled tasks)
if ($Collect) {
    Invoke-MetricCollection
    exit 0
}

if ($Analyze) {
    $recs = Invoke-SmartAnalysis
    if ($EnableAutoTune -and $recs -and $recs.Count -gt 0) {
        # AutoTune: solo aplica items de bajo impacto
        $changed = $false
        foreach ($r in $recs | Where-Object { $_.impact -eq 'Bajo' -and -not $_.applied }) {
            $r.applied = $true
            $changed   = $true
        }
        if ($changed) {
            $sr = Get-Content $smartRecoPath -Raw | ConvertFrom-Json
            $sr | ConvertTo-Json -Depth 10 | Set-Content $smartRecoPath -Encoding UTF8
        }
    }
    exit 0
}

if ($Install) {
    Write-Host ""
    Install-MonitorTasks -EnableAutoTune:$EnableAutoTune
    exit 0
}

if ($Uninstall) {
    Write-Host ""
    Uninstall-MonitorTasks
    exit 0
}

# ── Modo interactivo ──
do {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         08 — MONITOR INTELIGENTE — MejoraPC            ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    Show-TaskStatus

    Write-Host "  [1] Instalar tareas programadas" -ForegroundColor White
    Write-Host "  [2] Instalar con AutoTune habilitado" -ForegroundColor White
    Write-Host "  [3] Desinstalar tareas programadas" -ForegroundColor White
    Write-Host "  [4] Recolectar métricas ahora (manual)" -ForegroundColor White
    Write-Host "  [5] Ejecutar análisis inteligente ahora" -ForegroundColor White
    Write-Host "  [0] Volver" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Opción: " -NoNewline -ForegroundColor White
    $choice = Read-Host

    switch ($choice) {
        '1' {
            Write-Host ""
            Install-MonitorTasks
            Write-Host ""
            pause
        }
        '2' {
            Write-Host ""
            Install-MonitorTasks -EnableAutoTune
            Write-Host ""
            pause
        }
        '3' {
            Write-Host ""
            Uninstall-MonitorTasks
            Write-Host ""
            pause
        }
        '4' {
            Write-Host ""
            Write-Host "  Recolectando métricas..." -ForegroundColor Cyan
            Invoke-MetricCollection
            Write-Host "  [+] Muestra guardada en $usageDir" -ForegroundColor Green
            Write-Host ""
            pause
        }
        '5' {
            Write-Host ""
            Write-Host "  Analizando los últimos 7 días de logs..." -ForegroundColor Cyan
            $recs = Invoke-SmartAnalysis
            if ($recs -and $recs.Count -gt 0) {
                Write-Host ""
                Write-Host "  $($recs.Count) recomendación(es) generada(s) y guardadas:" -ForegroundColor Yellow
                Write-Host ""
                foreach ($r in $recs) {
                    $color = switch ($r.priority) { 'Alta' { 'Red' }; 'Media' { 'Yellow' }; default { 'Green' } }
                    Write-Host "  [$($r.priority)] $($r.title)" -ForegroundColor $color
                }
                Write-Host ""
                Write-Host "  Usá la opción 10 del menú principal para verlas." -ForegroundColor DarkGray
            } else {
                Write-Host "  Sin recomendaciones (¿hay suficientes datos?)." -ForegroundColor DarkGray
            }
            Write-Host ""
            pause
        }
    }
} while ($choice -ne '0')
