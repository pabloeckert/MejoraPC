[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/16-startup-audit.ps1 ────────────────────────
# Auditoría de TODO lo que puede arrancar solo con Windows, no solo lo que
# cubre el catálogo startup_disable (Run keys clásicas) de
# Get-MergedTweaksCatalog. Cubre los puntos de persistencia que un chequeo
# superficial se salta:
#   1. Run/RunOnce (HKCU/HKLM, incl. WOW6432Node)
#   2. Carpetas Startup (usuario + todos los usuarios), con ocultos
#   3. Tareas programadas con trigger Logon/Boot
#   4. Winlogon Shell/Userinit + AppInit_DLLs (vectores clásicos de malware)
#   5. StartupTask de apps UWP/MSIX — HKCU:\...\AppModel\SystemAppData —
#      invisible para los 4 puntos anteriores (ver profile-local.json →
#      startup_disable_uwp, descubierto el 2026-08-14)
#
# Política: los hallazgos YA aprobados en profile-local.json
# (startup_disable_uwp.applied_*) se re-imponen solos si drifearon (ídem
# startup_disable clásico en 03-performance.ps1 — decisión ya tomada, se
# reafirma). Todo lo NUEVO se reporta para que Pablo lo confirme — nunca se
# toca sin que él lo vea primero.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   16 - AUDITORÍA DE ARRANQUE (todos los mecanismos) ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$findings = [System.Collections.ArrayList]@()
$nuevos   = [System.Collections.ArrayList]@()

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ── $Title ──────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
}

$profilePath = "$scriptRoot\data\profile-local.json"
$profile = $null
if (Test-Path $profilePath) { $profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json }
$knownUwp = @()
if ($profile -and $profile.startup_disable_uwp) {
    foreach ($p in $profile.startup_disable_uwp.PSObject.Properties) {
        if ($p.Name -like 'applied_*') { $knownUwp += $p.Value }
    }
}
$knownUwpKeys = $knownUwp | ForEach-Object { "$($_.package)\$($_.task_id)" }

# ═══════════════════════════════════════════════════════════════════
# 1. Run / RunOnce
# ═══════════════════════════════════════════════════════════════════
Write-Section "1. Run / RunOnce"
$runKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($rk in $runKeys) {
    $props = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
    if (-not $props) { continue }
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -like 'PS*') { continue }
        Write-Status -Label "$rk" -Value "$($p.Name) = $($p.Value)" -Status INFO
        $null = $findings.Add([PSCustomObject]@{ tipo = 'run_key'; ubicacion = $rk; nombre = $p.Name; valor = "$($p.Value)" })
    }
}

# ═══════════════════════════════════════════════════════════════════
# 2. Carpetas Startup
# ═══════════════════════════════════════════════════════════════════
Write-Section "2. Carpetas Startup"
foreach ($dir in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\StartUp", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp")) {
    $items = Get-ChildItem $dir -Force -ErrorAction SilentlyContinue
    if (-not $items) { continue }
    foreach ($i in $items) {
        Write-Status -Label $dir -Value $i.Name -Status INFO
        $null = $findings.Add([PSCustomObject]@{ tipo = 'startup_folder'; ubicacion = $dir; nombre = $i.Name; valor = '' })
    }
}
if ($findings.Count -eq 0) { Write-Status -Label 'Startup folders' -Value 'vacías' -Status OK }

# ═══════════════════════════════════════════════════════════════════
# 3. Tareas programadas con trigger Logon/Boot
# ═══════════════════════════════════════════════════════════════════
Write-Section "3. Tareas programadas (Logon/Boot)"
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
foreach ($t in $tasks) {
    $trig = @($t.Triggers | ForEach-Object { $_.CimClass.CimClassName })
    if ($trig -notmatch 'Logon|Boot') { continue }
    $esMicrosoft = $t.TaskPath -like '\Microsoft\*'
    $status = if ($esMicrosoft) { 'OK' } else { 'WARN' }
    Write-Status -Label "$($t.TaskPath)$($t.TaskName)" -Value "trigger=$($trig -join ',') estado=$($t.State)" -Status $status
    if (-not $esMicrosoft) {
        $null = $nuevos.Add([PSCustomObject]@{ tipo = 'tarea_no_microsoft'; nombre = "$($t.TaskPath)$($t.TaskName)"; detalle = "trigger=$($trig -join ',')" })
    }
}

# ═══════════════════════════════════════════════════════════════════
# 4. Winlogon Shell/Userinit + AppInit_DLLs
# ═══════════════════════════════════════════════════════════════════
Write-Section "4. Vectores clásicos de persistencia"
$winlogon = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
if ($winlogon) {
    $shellOk = $winlogon.Shell -eq 'explorer.exe'
    $userinitOk = $winlogon.Userinit -match '(?i)^C:\\Windows\\system32\\userinit\.exe,?$'
    Write-Status -Label 'Winlogon Shell' -Value $winlogon.Shell -Status $(if ($shellOk) { 'OK' } else { 'ERROR' })
    Write-Status -Label 'Winlogon Userinit' -Value $winlogon.Userinit -Status $(if ($userinitOk) { 'OK' } else { 'ERROR' })
    if (-not $shellOk -or -not $userinitOk) {
        $null = $nuevos.Add([PSCustomObject]@{ tipo = 'winlogon_alterado'; nombre = 'Shell/Userinit'; detalle = "Shell=$($winlogon.Shell) Userinit=$($winlogon.Userinit)" })
    }
}
$appInit = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -ErrorAction SilentlyContinue
$hasAppInit = $appInit -and $appInit.AppInit_DLLs -and "$($appInit.AppInit_DLLs)".Trim() -ne ''
Write-Status -Label 'AppInit_DLLs' -Value $(if ($hasAppInit) { $appInit.AppInit_DLLs } else { 'vacío' }) -Status $(if ($hasAppInit) { 'ERROR' } else { 'OK' })
if ($hasAppInit) { $null = $nuevos.Add([PSCustomObject]@{ tipo = 'appinit_dlls'; nombre = 'AppInit_DLLs'; detalle = "$($appInit.AppInit_DLLs)" }) }

$restartApps = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).RestartApps
Write-Status -Label "'Reabrir apps al iniciar sesión' (RestartApps)" -Value $(if ($restartApps -eq 1) { 'activado' } else { 'desactivado' }) -Status INFO

# ═══════════════════════════════════════════════════════════════════
# 5. StartupTask de apps UWP/MSIX — reafirma lo conocido, reporta lo nuevo
# ═══════════════════════════════════════════════════════════════════
Write-Section "5. StartupTask de apps de Microsoft Store (UWP/MSIX)"
$base = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
$pkgs = Get-ChildItem $base -ErrorAction SilentlyContinue
foreach ($pkg in $pkgs) {
    Get-ChildItem $pkg.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
        $state = (Get-ItemProperty $_.PSPath -Name State -ErrorAction SilentlyContinue).State
        if ($state -ne 2) { return }  # 2 = habilitado; solo interesa lo que está activo
        $key = "$($pkg.PSChildName)\$($_.PSChildName)"
        if ($knownUwpKeys -contains $key) {
            # Ya aprobado por Pablo como "apagar" — si volvió a 2 (ej. update de la app), se reafirma.
            Set-ItemProperty -Path $_.PSPath -Name State -Value 1 -Type DWord
            Write-Status -Label $key -Value 'había vuelto a habilitarse solo — reafirmado a deshabilitado' -Status WARN
        } else {
            Write-Status -Label $key -Value 'StartupTask activo, sin decisión previa' -Status INFO
            $null = $nuevos.Add([PSCustomObject]@{ tipo = 'uwp_startup_nuevo'; nombre = $key; detalle = 'no está en startup_disable_uwp — no se tocó' })
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# 6. REPORTE FINAL
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                 REPORTE FINAL                    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
if ($nuevos.Count -gt 0) {
    Write-Host "  [!] $($nuevos.Count) hallazgo(s) nuevo(s) sin decisión previa — revisar antes de tocar:" -ForegroundColor Yellow
    foreach ($n in $nuevos) { Write-Host "      - [$($n.tipo)] $($n.nombre) — $($n.detalle)" -ForegroundColor Yellow }
} else {
    Write-Host "  [+] Nada nuevo — todo lo activo ya está reconocido/aprobado." -ForegroundColor Green
}
Write-Host ""

$logDir = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" | Set-Content -Path "$logDir\startup-audit-$(Get-Date -Format 'yyyy-MM-dd').log" -Encoding UTF8
$findings | ForEach-Object { "[$($_.tipo)] $($_.ubicacion) -> $($_.nombre) = $($_.valor)" } | Add-Content -Path "$logDir\startup-audit-$(Get-Date -Format 'yyyy-MM-dd').log" -Encoding UTF8

[PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    nuevos    = $nuevos
    total_run_keys = @($findings | Where-Object { $_.tipo -eq 'run_key' }).Count
} | ConvertTo-Json -Depth 5 | Set-Content -Path "$scriptRoot\data\last-startup-audit.json" -Encoding UTF8

Wait-KeyIfInteractive -Auto:$Auto
