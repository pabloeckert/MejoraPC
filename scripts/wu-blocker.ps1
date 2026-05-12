# ============================================================
# WINDOWS UPDATE BLOCKER - Pausar/reanudar actualizaciones
# ============================================================
# Útil para: sesiones de trabajo intensivo, gaming, presentaciones
# Windows Update consume RAM, CPU y disco en background.
# ============================================================

param(
    [ValidateSet("block", "unblock", "status")]
    [string]$Action = "status"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

$WUStateFile = Join-Path $RescueDir "wu_blocker_state.json"

function Get-WUStatus {
    if (Test-Path $WUStateFile) {
        $state = Get-Content $WUStateFile -Raw | ConvertFrom-Json
        return $state
    }
    return $null
}

function Save-WUState {
    param([bool]$Blocked)
    @{
        Blocked = $Blocked
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    } | ConvertTo-Json -Depth 3 | Out-File $WUStateFile -Encoding UTF8
}

# ============================================================
# BLOQUEAR WINDOWS UPDATE
# ============================================================
function Block-WU {
    Write-Header "🔒 BLOQUEANDO WINDOWS UPDATE"
    Write-Host ""
    Write-Host "  Esto va a:" -ForegroundColor White
    Write-Host "    1. Detener el servicio Windows Update" -ForegroundColor Gray
    Write-Host "    2. Desactivar el servicio" -ForegroundColor Gray
    Write-Host "    3. Pausar actualizaciones via registro" -ForegroundColor Gray
    Write-Host "    4. Bloquear reinicios automáticos" -ForegroundColor Gray
    Write-Host ""
    Write-Info "Para revertir: .\wu-blocker.ps1 -Action unblock"
    Write-Host ""
    
    $steps = 0
    $errors = 0
    
    # 1. Detener y desactivar servicio WU
    Write-Step 1 "Deteniendo servicio Windows Update..."
    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Set-Service wuauserv -StartupType Disabled -ErrorAction Stop
        Write-Success "Servicio Windows Update desactivado"
        $steps++
    } catch {
        Write-Error "Error al detener WU: $_"
        $errors++
    }
    
    # 2. Detener y desactivar Update Orchestrator
    Write-Step 2 "Deteniendo Update Orchestrator..."
    try {
        Stop-Service UsoSvc -Force -ErrorAction SilentlyContinue
        Set-Service UsoSvc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Success "Update Orchestrator desactivado"
        $steps++
    } catch {
        Write-Warn "Update Orchestrator no se pudo desactivar (puede que no exista)"
    }
    
    # 3. Pausar actualizaciones via registro
    Write-Step 3 "Pausando actualizaciones via registro..."
    try {
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (!(Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
        Set-RegProperty $auPath -Name "NoAutoUpdate" -Value 1
        Set-RegProperty $auPath -Name "AUOptions" -Value 2  # Notify before download
        
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
        Set-RegProperty $wuPath -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value 1
        Set-RegProperty $wuPath -Name "DisableWindowsUpdateAccess" -Value 1
        
        Write-Success "Actualizaciones pausadas via registro"
        $steps++
    } catch {
        Write-Error "Error al pausar via registro: $_"
        $errors++
    }
    
    # 4. Bloquear reinicios automáticos
    Write-Step 4 "Bloqueando reinicios automáticos..."
    try {
        $rebootPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        Set-RegProperty $rebootPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1
        Set-RegProperty $rebootPath -Name "AUPowerManagement" -Value 0
        
        Write-Success "Reinicios automáticos bloqueados"
        $steps++
    } catch {
        Write-Error "Error al bloquear reinicios: $_"
        $errors++
    }
    
    # Guardar estado
    Save-WUState -Blocked $true
    
    Write-Host ""
    Write-Header "✅ WINDOWS UPDATE BLOQUEADO ($steps pasos)"
    Write-Warn "Las actualizaciones NO se descargarán ni instalarán."
    Write-Info "Para reanudar: .\wu-blocker.ps1 -Action unblock"
    Show-LogPath
    Log "Windows Update bloqueado: $steps pasos, $errors errores"
}

# ============================================================
# DESBLOQUEAR WINDOWS UPDATE
# ============================================================
function Unblock-WU {
    Write-Header "🔓 DESBLOQUEANDO WINDOWS UPDATE"
    Write-Host ""
    
    $steps = 0
    $errors = 0
    
    # 1. Reactivar servicio WU
    Write-Step 1 "Reactivando servicio Windows Update..."
    try {
        Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Write-Success "Servicio Windows Update reactivado"
        $steps++
    } catch {
        Write-Error "Error al reactivar WU: $_"
        $errors++
    }
    
    # 2. Reactivar Update Orchestrator
    Write-Step 2 "Reactivando Update Orchestrator..."
    try {
        Set-Service UsoSvc -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service UsoSvc -ErrorAction SilentlyContinue
        Write-Success "Update Orchestrator reactivado"
        $steps++
    } catch {
        Write-Warn "Update Orchestrator no se pudo reactivar"
    }
    
    # 3. Eliminar restricciones de registro
    Write-Step 3 "Eliminando restricciones de registro..."
    try {
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $auPath) {
            Remove-ItemProperty $auPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty $auPath -Name "AUOptions" -ErrorAction SilentlyContinue
            Remove-ItemProperty $auPath -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
            Remove-ItemProperty $auPath -Name "AUPowerManagement" -ErrorAction SilentlyContinue
        }
        
        $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (Test-Path $wuPath) {
            Remove-ItemProperty $wuPath -Name "DoNotConnectToWindowsUpdateInternetLocations" -ErrorAction SilentlyContinue
            Remove-ItemProperty $wuPath -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
        }
        
        Write-Success "Restricciones eliminadas"
        $steps++
    } catch {
        Write-Error "Error al eliminar restricciones: $_"
        $errors++
    }
    
    # Eliminar estado
    Remove-Item $WUStateFile -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Header "✅ WINDOWS UPDATE DESBLOQUEADO ($steps pasos)"
    Write-Success "Windows Update funciona normalmente."
    Write-Info "Podés buscar actualizaciones manualmente en: Configuración → Windows Update"
    Show-LogPath
    Log "Windows Update desbloqueado: $steps pasos, $errors errores"
}

# ============================================================
# STATUS
# ============================================================
function Show-WUStatus {
    Write-Header "📊 WINDOWS UPDATE STATUS"
    
    # Estado guardado
    $state = Get-WUStatus
    if ($state -and $state.Blocked) {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🔒 BLOQUEADO" -ForegroundColor Red
        Write-Host "  Bloqueado desde: $($state.Timestamp)" -ForegroundColor Gray
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🔓 ACTIVO" -ForegroundColor Green
    }
    
    # Estado actual del servicio
    Write-Host ""
    $wuSvc = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wuSvc) {
        $statusColor = if ($wuSvc.Status -eq "Running") { "Green" } else { "Red" }
        $startColor = if ($wuSvc.StartType -eq "Disabled") { "Red" } elseif ($wuSvc.StartType -eq "Manual") { "Yellow" } else { "Green" }
        Write-Host "  Servicio:     $($wuSvc.Status)" -ForegroundColor $statusColor
        Write-Host "  Startup:      $($wuSvc.StartType)" -ForegroundColor $startColor
    }
    
    $usoSvc = Get-Service UsoSvc -ErrorAction SilentlyContinue
    if ($usoSvc) {
        Write-Host "  Orchestrator: $($usoSvc.Status) ($($usoSvc.StartType))" -ForegroundColor Gray
    }
    
    # Restricciones de registro
    Write-Host ""
    $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $noAuto = (Get-ItemProperty $auPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue).NoAutoUpdate
    $noReboot = (Get-ItemProperty $auPath -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue).NoAutoRebootWithLoggedOnUsers
    
    Write-Host "  Auto-update:  $(if($noAuto -eq 1){'❌ Bloqueado'}else{'✅ Activo'})" -ForegroundColor $(if($noAuto -eq 1){"Red"}else{"Green"})
    Write-Host "  Auto-reboot:  $(if($noReboot -eq 1){'❌ Bloqueado'}else{'✅ Activo'})" -ForegroundColor $(if($noReboot -eq 1){"Red"}else{"Green"})
    
    Write-Host ""
    Write-Host "  Bloquear:    .\wu-blocker.ps1 -Action block" -ForegroundColor Gray
    Write-Host "  Desbloquear: .\wu-blocker.ps1 -Action unblock" -ForegroundColor Gray
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "block"   { Block-WU }
    "unblock" { Unblock-WU }
    "status"  { Show-WUStatus }
}
