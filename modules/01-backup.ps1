[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/01-backup.ps1 ───────────────────────────────
# Punto de restauración + exportación de claves de registro clave.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$backupDir = "$scriptRoot\backups"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force $backupDir | Out-Null }
$stamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')

Clear-HostSafe
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         01 - BACKUP                              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Punto de restauración del sistema (requiere admin)
Write-Host "  Creando punto de restauración del sistema..." -ForegroundColor DarkGray
try {
    Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "MejoraPC $stamp" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    # Verificación real: Windows limita a 1 restore point cada 24h (registro
    # SystemRestorePointCreationFrequency) y cuando bloquea la creación por eso
    # emite un WARNING, no una excepción -- Checkpoint-Computer "no falla" pero
    # tampoco crea nada nuevo. Sin este chequeo se reportaba "creado" como falso
    # positivo (descubierto el 2026-09-04 comparando contra el dashboard, que
    # mostraba "no se encontró punto de restauración" pese al "[OK] creado").
    Start-Sleep -Milliseconds 500
    $rp = Get-ComputerRestorePoint -ErrorAction Stop | Sort-Object SequenceNumber -Descending | Select-Object -First 1
    if ($rp) {
        $created = [Management.ManagementDateTimeConverter]::ToDateTime($rp.CreationTime)
        $ageMin  = (New-TimeSpan -Start $created -End (Get-Date)).TotalMinutes
        if ($ageMin -le 5) {
            Write-Status "Restore point" "creado ahora ($($created.ToString('yyyy-MM-dd HH:mm')))" 'OK'
        } else {
            Write-Status "Restore point" "ya existía uno reciente ($($created.ToString('yyyy-MM-dd HH:mm')), <24h) — Windows no permite crear otro" 'OK'
        }
    } else {
        Write-Status "Restore point" "Checkpoint-Computer no tiró error pero no se encontró ninguno — revisar manualmente" 'WARN'
    }
} catch {
    Write-Status "Restore point" "no disponible (admin/políticas): $_" 'WARN'
}

# Exportar claves de registro que tocan los módulos
Write-Host ""
Write-Host "  Exportando claves de registro relevantes..." -ForegroundColor DarkGray
$keys = @(
    'HKCU\Software\Microsoft\GameBar',
    'HKCU\System\GameConfigStore',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects',
    'HKCU\Control Panel\Desktop',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($k in $keys) {
    $safe = ($k -replace '[\\: ]', '_')
    $out  = Join-Path $backupDir "$safe-$stamp.reg"
    $regOut = reg export $k $out /y 2>&1
    if ($LASTEXITCODE -eq 0 -and (Test-Path $out)) {
        Write-Status (Split-Path $k -Leaf) "exportado" 'OK'
    } else {
        Write-Status (Split-Path $k -Leaf) "error: $regOut" 'ERROR'
    }
}

Write-Host ""
Write-Host "  Backups guardados en: $backupDir" -ForegroundColor DarkGray
Write-Host ""
Wait-KeyIfInteractive -Auto:$Auto
