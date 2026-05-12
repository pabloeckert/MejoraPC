# ============================================================
# SERVICES OPTIMIZER - Optimizar servicios de Windows
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🔧 SERVICES OPTIMIZER"

Write-Host "  Analizando servicios..." -ForegroundColor White
Write-Host ""

$optimized = 0
$alreadyOk = 0

# Poner en Manual (lista centralizada en config.ps1)
foreach ($svcInfo in $Global:ServicesToManual) {
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -eq "Automatic") {
        Write-Host "  📋 $($svcInfo.Desc)... " -NoNewline
        try {
            Set-Service -Name $svcInfo.Name -StartupType Manual -ErrorAction Stop
            if ($svc.Status -eq "Running") {
                Stop-Service -Name $svcInfo.Name -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Manual ✅" -ForegroundColor Green
            $optimized++
            Log "Servicio a Manual: $($svcInfo.Name)"
        } catch {
            Write-Host "Error ❌" -ForegroundColor Red
        }
    } else {
        $alreadyOk++
    }
}

# Desactivar (lista centralizada en config.ps1)
foreach ($svcInfo in $Global:ServicesToDisable) {
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -ne "Disabled") {
        Write-Host "  🔴 $($svcInfo.Desc)... " -NoNewline
        try {
            Stop-Service -Name $svcInfo.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svcInfo.Name -StartupType Disabled -ErrorAction Stop
            Write-Host "Desactivado ✅" -ForegroundColor Green
            $optimized++
            Log "Servicio desactivado: $($svcInfo.Name)"
        } catch {
            Write-Host "Error ❌" -ForegroundColor Red
        }
    } else {
        $alreadyOk++
    }
}

Write-Host ""
Write-Success "Servicios optimizados: $optimized"
Write-Info "Ya estaban OK: $alreadyOk"
Write-Info "Los servicios se pueden restaurar con rescue.ps1"
Log "Services optimizer completado: $optimized optimizados"
