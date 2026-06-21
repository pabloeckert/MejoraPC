[CmdletBinding()]
param()

# ── MejoraPC — modules/01-backup.ps1 ───────────────────────────────
# Punto de restauración + exportación de claves de registro clave.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$backupDir = "$scriptRoot\backups"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force $backupDir | Out-Null }
$stamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')

Clear-Host
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
    Write-Status "Restore point" "creado" 'OK'
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
    reg export $k $out /y 2>&1 | Out-Null
    if (Test-Path $out) { Write-Status (Split-Path $k -Leaf) "exportado" 'OK' }
}

Write-Host ""
Write-Host "  Backups guardados en: $backupDir" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
