[CmdletBinding()]
param()

# ── MejoraPC — modules/05-rescate.ps1 ──────────────────────────────
# Restauración desde backups: registry, packages, servicios, power plan.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$backupDir = "$scriptRoot\backups"
$logDir    = "$scriptRoot\logs"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         05 - RESCATE / RESTAURAR                 ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Reinstalar paquetes eliminados (debloat-removed-*.txt)" -ForegroundColor White
Write-Host "  [2] Restaurar registry desde un .reg" -ForegroundColor White
Write-Host "  [3] Restaurar servicios deshabilitados (desde log performance)" -ForegroundColor White
Write-Host "  [4] Restaurar power plan (Balanced)" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

switch ($opt) {
    '1' {
        $files = @(Get-ChildItem -Path $backupDir -Filter 'debloat-removed-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($files.Count -eq 0) { Write-Host "`n  No hay backups de debloat." -ForegroundColor Yellow; break }
        Write-Host ""
        for ($i = 0; $i -lt $files.Count; $i++) { Write-Host "  [$($i+1)] $($files[$i].Name)" -ForegroundColor Gray }
        Write-Host "`n  Elegí backup: " -NoNewline; $sel = Read-Host
        $idx = [int]$sel - 1
        if ($idx -lt 0 -or $idx -ge $files.Count) { Write-Host "  Inválido." -ForegroundColor Red; break }
        $ids = Get-Content $files[$idx].FullName | Where-Object { $_ -and $_ -notmatch '^#' }
        Write-Host "`n  Reinstalando $($ids.Count) paquetes via winget...`n" -ForegroundColor DarkGray
        foreach ($id in $ids) {
            Write-Host "  $id ... " -NoNewline -ForegroundColor Gray
            $out = winget install --id $id --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
            if ($out -match 'Successfully installed|instalad') { Write-Host "OK" -ForegroundColor Green }
            else { Write-Host "no disponible (puede ser MSIX de Store)" -ForegroundColor DarkYellow }
        }
    }
    '2' {
        $regs = @(Get-ChildItem -Path $backupDir -Filter '*.reg' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($regs.Count -eq 0) { Write-Host "`n  No hay .reg en backups\." -ForegroundColor Yellow; break }
        Write-Host ""
        for ($i = 0; $i -lt $regs.Count; $i++) { Write-Host "  [$($i+1)] $($regs[$i].Name)" -ForegroundColor Gray }
        Write-Host "`n  Elegí .reg: " -NoNewline; $sel = Read-Host
        $idx = [int]$sel - 1
        if ($idx -lt 0 -or $idx -ge $regs.Count) { Write-Host "  Inválido." -ForegroundColor Red; break }
        reg import $regs[$idx].FullName
        Write-Host "  [OK] Registry restaurado." -ForegroundColor Green
    }
    '3' {
        $logs = @(Get-ChildItem -Path $logDir -Filter 'performance-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($logs.Count -eq 0) { Write-Host "`n  No hay logs de performance." -ForegroundColor Yellow; break }
        $lines = Get-Content $logs[0].FullName | Where-Object { $_ -match 'SVC\s+\S+\s+:\s+(\S+)\s+->' }
        foreach ($l in $lines) {
            if ($l -match 'SVC\s+(\S+)\s+:\s+(\S+)\s+->') {
                $svc = $Matches[1]; $oldState = $Matches[2]
                if ($oldState -and $oldState -ne 'Disabled') {
                    try {
                        Set-Service -Name $svc -StartupType $oldState -ErrorAction Stop
                        Write-Host "  [OK] $svc -> $oldState" -ForegroundColor Green
                    } catch { Write-Host "  [x] $svc : $_" -ForegroundColor Red }
                }
            }
        }
    }
    '4' {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>&1 | Out-Null
        Write-Host "  [OK] Power plan restaurado a Balanced." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
