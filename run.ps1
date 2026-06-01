#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Ensure-DataDirectory -ScriptRoot $scriptRoot

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       MejoraPC v2.0 — Optimizador de Windows            ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Resumen de hardware si existe perfil
    $profilePath = "$scriptRoot\data\hardware-profile.json"
    if (Test-Path $profilePath) {
        try {
            $hw = Get-Content $profilePath -Raw | ConvertFrom-Json
            if ($hw.cpu) {
                $cpuShort = ($hw.cpu.model -replace 'Intel\(R\)|AMD|Core\(TM\)|Processor|CPU|@\s*[\d.]+\s*GHz', '' -replace '\s+', ' ').Trim()
                $cpuShort = $cpuShort.Substring(0, [Math]::Min(28, $cpuShort.Length))
                $score    = Get-SystemScore -ProfilePath $profilePath
                $sc       = if ($score -ge 70) { 'Green' } elseif ($score -ge 40) { 'Yellow' } else { 'Red' }
                $ramGB    = [math]::Round($hw.ram.totalBytes / 1GB, 0)
                Write-Host "  CPU: $cpuShort | RAM: $($ramGB)GB | Score: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$score/100" -ForegroundColor $sc
                Write-Host ""
            }
        } catch { }
    }

    # Alerta recomendaciones pendientes
    $srPath = "$scriptRoot\data\smart-recommendations.json"
    if (Test-Path $srPath) {
        try {
            $sr = Get-Content $srPath -Raw | ConvertFrom-Json
            if ($sr.items) {
                $pending = @($sr.items | Where-Object { $_ -and -not $_.applied })
                if ($pending.Count -gt 0) {
                    Write-Host "  ! $($pending.Count) recomendación(es) inteligente(s) pendiente(s) — opción 10" -ForegroundColor Yellow
                    Write-Host ""
                }
            }
        } catch { }
    }
}

function Show-Menu {
    Write-Host "  ── OPTIMIZACIONES ──────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [1]  Gestión de Startup" -ForegroundColor White
    Write-Host "  [2]  Optimización de Servicios" -ForegroundColor White
    Write-Host "  [3]  Ajustes Visuales" -ForegroundColor White
    Write-Host "  [4]  Optimización de Red" -ForegroundColor White
    Write-Host "  [5]  Privacidad y Telemetría" -ForegroundColor White
    Write-Host "  [6]  Modo Gaming" -ForegroundColor White
    Write-Host ""
    Write-Host "  ── ANÁLISIS Y MONITOREO ────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [7]  Escaneo de Hardware" -ForegroundColor Cyan
    Write-Host "  [8]  Monitor Inteligente" -ForegroundColor Cyan
    Write-Host "  [9]  Dashboard / Reporte" -ForegroundColor Cyan
    Write-Host "  [10] Aplicar Recomendaciones Inteligentes" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [0]  Salir" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Elegí una opción: " -NoNewline -ForegroundColor White
}

function Invoke-Module {
    param([string]$Path)
    if (Test-Path $Path) {
        & $Path
    } else {
        Write-Host "`n  Módulo no encontrado: $Path" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function Apply-SmartRecommendations {
    $srPath = "$scriptRoot\data\smart-recommendations.json"
    Write-Host ""
    if (-not (Test-Path $srPath)) {
        Write-Host "  No hay recomendaciones. Ejecutá Monitor Inteligente (8 → opción 5) primero." -ForegroundColor Yellow
        Write-Host ""; pause; return
    }
    try {
        $sr      = Get-Content $srPath -Raw | ConvertFrom-Json
        $pending = @($sr.items | Where-Object { $_ -and -not $_.applied })
        if ($pending.Count -eq 0) {
            Write-Host "  Todo al día. Sin recomendaciones pendientes." -ForegroundColor Green
            Write-Host ""; pause; return
        }
        Write-Host "  $($pending.Count) recomendación(es) pendiente(s):" -ForegroundColor Cyan
        Write-Host ""
        foreach ($r in $pending) {
            $color = switch ($r.priority) { 'Alta' { 'Red' }; 'Media' { 'Yellow' }; default { 'Green' } }
            Write-Host "  [$($r.priority.PadRight(5))] $($r.title)" -ForegroundColor $color
            Write-Host "          $($r.description)" -ForegroundColor DarkGray
            Write-Host ""
        }
        Write-Host "  Abrí el módulo correspondiente para aplicarlas manualmente." -ForegroundColor DarkGray
        Write-Host "  (Startup→1, Servicios→2, Visual→3, Red→4, Privacy→5)" -ForegroundColor DarkGray
    } catch {
        Write-Host "  Error leyendo recomendaciones: $_" -ForegroundColor Red
    }
    Write-Host ""; pause
}

do {
    Show-Banner
    Show-Menu
    $choice = Read-Host

    switch ($choice) {
        '1'  { Invoke-Module "$scriptRoot\01-startup.ps1"  }
        '2'  { Invoke-Module "$scriptRoot\02-services.ps1" }
        '3'  { Invoke-Module "$scriptRoot\03-visual.ps1"   }
        '4'  { Invoke-Module "$scriptRoot\04-network.ps1"  }
        '5'  { Invoke-Module "$scriptRoot\05-privacy.ps1"  }
        '6'  { Invoke-Module "$scriptRoot\06-gaming.ps1"   }
        '7'  { Invoke-Module "$scriptRoot\07-scan.ps1"     }
        '8'  { Invoke-Module "$scriptRoot\08-monitor.ps1"  }
        '9'  { Invoke-Module "$scriptRoot\09-report.ps1"   }
        '10' { Apply-SmartRecommendations }
        '0'  { Write-Host "`n  Hasta luego.`n" -ForegroundColor Cyan; break }
        default {
            Write-Host "`n  Opción no válida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne '0')
