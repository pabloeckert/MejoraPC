[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/00-discover.ps1 ─────────────────────────────
# Motor de descubrimiento. Puramente observacional: enumera software
# instalado y lo clasifica contra el catálogo UNIVERSAL (nunca contra el
# perfil local) para armar un reporte. NUNCA borra ni cambia nada — la
# remoción real la sigue haciendo 02-debloat.ps1 en su propio paso, con su
# propia verificación (Test-PackageInstalled). Todo lo no reconocido queda
# intacto, siempre, sin excepción.
#
# Al final corre una encuesta breve (solo si hay consola interactiva),
# generada a partir de lo que encontró — no un formulario en blanco. Las
# respuestas dan CONTEXTO para priorizar recomendaciones futuras
# (monitor/analyze.py); nunca autorizan tocar software no reconocido.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║      00 - DESCUBRIMIENTO (primera vez aquí)      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Escaneando software instalado (solo lectura)..." -ForegroundColor DarkGray

# ── 1. Enumerar TODO lo instalado (Appx + registro Uninstall) ──────
$installed = [System.Collections.ArrayList]@()

$appxPkgs = $null
try { $appxPkgs = Get-AppxPackage -AllUsers -ErrorAction Stop } catch { $appxPkgs = $null }
if (-not $appxPkgs) {
    # -AllUsers requiere admin — sin eso, cae a los paquetes del usuario actual
    # (mejor que quedar en cero; INICIAR.bat corre elevado en uso real).
    try { $appxPkgs = Get-AppxPackage -ErrorAction SilentlyContinue } catch { $appxPkgs = @() }
}
foreach ($pkg in @($appxPkgs)) {
    $null = $installed.Add([pscustomobject]@{ Name = $pkg.Name; Publisher = $null; SizeMB = 0 })
}

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($k in $uninstallKeys) {
    Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | ForEach-Object {
        $sizeMB = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 1) } else { 0 }
        $null = $installed.Add([pscustomobject]@{ Name = $_.DisplayName; Publisher = $_.Publisher; SizeMB = $sizeMB })
    }
}
$installed = @($installed | Sort-Object Name -Unique)
Write-Status "Software detectado" "$($installed.Count) entradas" 'INFO'

# ── 2. Clasificar contra el catálogo UNIVERSAL (nunca el local) ────
# Matching aproximado (*contains*) — es solo para el reporte informativo.
# La remoción real usa el matching preciso de Test-PackageInstalled en
# 02-debloat.ps1, esto no la reemplaza.
$universalBloat = Get-Content "$scriptRoot\data\universal-bloatware.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$universalNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($pfn in $universalBloat.policy_msix.package_family_names) { [void]$universalNames.Add(($pfn -split '_')[0]) }
foreach ($grp in $universalBloat.blockA.groups.PSObject.Properties) {
    foreach ($id in $grp.Value) { [void]$universalNames.Add($id) }
}

$universalMatches = 0
$unrecognized = [System.Collections.ArrayList]@()
foreach ($app in $installed) {
    $isUniversal = $false
    foreach ($u in $universalNames) {
        if ($app.Name -like "*$u*") { $isUniversal = $true; break }
    }
    if ($isUniversal) { $universalMatches++ } else { $null = $unrecognized.Add($app) }
}

Write-Status "Coincide con catálogo universal" "$universalMatches" 'OK'
Write-Status "No reconocido (se deja intacto, siempre)" "$($unrecognized.Count)" 'INFO'

# ── 3. Reporte — nunca se actúa sobre lo no reconocido ─────────────
$unrecognizedSorted = @($unrecognized | Sort-Object SizeMB -Descending)
$unrecognizedSample = @($unrecognizedSorted | Select-Object -First 50 | ForEach-Object {
    [pscustomobject]@{ name = $_.Name; publisher = $_.Publisher; size_mb = $_.SizeMB }
})

[pscustomobject]@{
    timestamp          = (Get-Date).ToString('o')
    installed_count     = $installed.Count
    universal_matches   = $universalMatches
    unrecognized_count  = $unrecognized.Count
    unrecognized_sample = $unrecognizedSample
} | ConvertTo-Json -Depth 6 | Set-Content -Path "$scriptRoot\data\discovery-report.json" -Encoding UTF8
Write-Status "Reporte" "guardado en data\discovery-report.json" 'OK'

# ── 4. Encuesta breve — da contexto, nunca autoriza tocar lo desconocido ──
$interactive = $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected
$survey = @{}

if ($interactive) {
    Write-Host ""
    Write-Host "  ── Unas preguntas rápidas para ajustar las recomendaciones ──" -ForegroundColor DarkCyan
    Write-Host "  (esto no borra ni cambia nada — solo da contexto)" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  Uso principal de esta PC — [1] Oficina [2] Desarrollo [3] Gaming [4] Familiar [5] Diseño: " -NoNewline
    $usageMap = @{ '1' = 'oficina'; '2' = 'desarrollo'; '3' = 'gaming'; '4' = 'familiar'; '5' = 'diseño' }
    $usageAns = Read-Host
    $survey.usage_type = if ($usageMap.ContainsKey($usageAns)) { $usageMap[$usageAns] } else { 'general' }

    Write-Host "  ¿Hay chicos que usan esta PC? [Y/N]: " -NoNewline
    $survey.has_kids = (Read-Host) -match '^[Yy]'

    $browsers = @($installed | Where-Object { $_.Name -match 'Chrome|Firefox|Edge|Brave|Opera|Vivaldi' } | Select-Object -ExpandProperty Name -Unique)
    if ($browsers.Count -gt 1) {
        Write-Host "  Detecté varios navegadores ($($browsers -join ', ')). ¿Cuál es tu principal?: " -NoNewline
        $survey.primary_browser = Read-Host
    }

    if ($unrecognizedSample.Count -gt 5) {
        $top5 = @($unrecognizedSample | Select-Object -First 5)
        Write-Host ""
        Write-Host "  Encontré $($unrecognized.Count) programas que no reconozco. Los 5 más pesados:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $top5.Count; $i++) { Write-Host "    [$($i+1)] $($top5[$i].name) (~$($top5[$i].size_mb)MB)" -ForegroundColor Gray }
        Write-Host "  ¿Cuáles usás activamente? (números separados por coma, ENTER si ninguno): " -NoNewline
        $sel = Read-Host
        $idxs = @($sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 })
        $survey.confirmed_active_apps = @($idxs | Where-Object { $_ -ge 0 -and $_ -lt $top5.Count } | ForEach-Object { $top5[$_].name })
    }

    Write-Host ""
    Write-Status "Encuesta" "guardada — se usa para priorizar recomendaciones" 'OK'
}

# ── 5. Guardar contexto en profile-local.json (crea el archivo si no existe) ──
if ($survey.Count -gt 0) {
    $profileLocalPath = "$scriptRoot\data\profile-local.json"
    if (Test-Path $profileLocalPath) {
        $existing = Get-Content $profileLocalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $existing = [pscustomobject]@{
            _meta = [pscustomobject]@{ profile = 'generado por encuesta'; origin = 'survey'; updated = (Get-Date).ToString('yyyy-MM-dd') }
        }
    }
    $existing | Add-Member -NotePropertyName 'survey' -NotePropertyValue ([pscustomobject]$survey) -Force
    $existing | ConvertTo-Json -Depth 10 | Set-Content -Path $profileLocalPath -Encoding UTF8
    Write-Status "Perfil local" "actualizado con contexto de la encuesta" 'OK'
}

Write-Host ""
Wait-KeyIfInteractive -Auto:$Auto
