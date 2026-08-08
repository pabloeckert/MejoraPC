[CmdletBinding()]
param()

# ── MejoraPC — modules/14-post-reboot-verify.ps1 ───────────────────
# Corre UNA vez en el próximo login para confirmar que lo que quedó
# PENDIENTE en 13-verify.ps1 (ej. Microsoft.Copilot, que la política CAPA 1
# recién saca en el próximo login) ya se resolvió. Pensado para dispararse
# solo vía la scheduled task "MejoraPC-PostRebootVerify" — invisible,
# sin ventana — y se autoelimina al terminar (no repite en cada login).
#
# También se puede correr a mano (opción 14 del menú) para chequear en
# cualquier momento sin esperar un login; en ese caso NO borra la task
# (detecta solo si la disparó la scheduled task o una corrida manual).

$scriptRoot = Split-Path -Parent $PSScriptRoot
$logDir     = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$logFile    = Join-Path $logDir "post-reboot-verify-$((Get-Date).ToString('yyyy-MM-dd')).log"
$monitorLog = "$scriptRoot\data\monitor.log"
$taskName   = 'MejoraPC-PostRebootVerify'

# Margen tras el login: la remoción por política (CAPA 1) y el resto de
# servicios de Windows pueden tardar un rato en asentarse recién logueado.
$isTaskTrigger = [bool](Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
if ($isTaskTrigger) { Start-Sleep -Seconds 45 }

# *>&1 (no 2>&1): 13-verify.ps1 imprime casi todo con Write-Host, que va al
# stream de Information (6), no al de error (2) — con 2>&1 el log queda vacío.
$output = & "$scriptRoot\modules\13-verify.ps1" *>&1 | Out-String
Add-Content -Path $logFile -Value "=== post-reboot-verify $(Get-Date -Format s) ===" -Encoding utf8
Add-Content -Path $logFile -Value $output -Encoding utf8

$verif = 0; $pend = 0; $fail = 0
if ($output -match 'VERIFICADO\s+\S\s*:\s*(\d+)') { $verif = [int]$Matches[1] }
if ($output -match 'PENDIENTE\s+\S\s*:\s*(\d+)')  { $pend  = [int]$Matches[1] }
if ($output -match 'FALLIDO\s+\S\s*:\s*(\d+)')    { $fail  = [int]$Matches[1] }

$summary = "[post-reboot-verify] VERIFICADO=$verif PENDIENTE=$pend FALLIDO=$fail -> $logFile"
try { Add-Content -Path $monitorLog -Value "$(Get-Date -Format s)  $summary" -Encoding utf8 } catch { }

# Tarea de un solo uso: si nos disparó la scheduled task, se borra a sí misma
# para no volver a correr en cada login futuro.
if ($isTaskTrigger) {
    schtasks /Delete /F /TN $taskName 2>$null | Out-Null
}

if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected) {
    Write-Host ""
    Write-Host "  Verificación post-reinicio: VERIFICADO=$verif  PENDIENTE=$pend  FALLIDO=$fail" -ForegroundColor $(if ($pend -eq 0 -and $fail -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "  Log completo: $logFile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
    $null = Read-Host
}
