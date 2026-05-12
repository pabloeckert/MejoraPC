# ============================================================
# SERVICES OPTIMIZER - Optimizar servicios de Windows
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🔧 SERVICES OPTIMIZER"

# Auto rescue point
Write-Info "Creando rescue point de seguridad..."
& "$PSScriptRoot\rescue.ps1" -Action create -Name "pre-services" | Out-Null
Write-Host ""

# Info de tipo de disco
if ($Global:IsSSD) {
    Write-Info "SSD detectado — Superfetch e Indexación se desactivarán."
} else {
    Write-Info "HDD detectado — Superfetch se mantendrá activo."
}
Write-Host ""

Write-Host "  Analizando servicios..." -ForegroundColor White
Write-Host ""

$optimized = 0
$alreadyOk = 0
$failed = 0

# Poner en Manual (lista centralizada en config.ps1)
$totalSvc = $Global:ServicesToManual.Count + $Global:ServicesToDisable.Count
$processed = 0

foreach ($svcInfo in $Global:ServicesToManual) {
    $processed++
    Write-Progress -Activity "Optimizando servicios" -Status "$processed/$totalSvc — $($svcInfo.Desc)" -PercentComplete ([math]::Round(($processed/$totalSvc)*100,0))
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and ($svc.StartType -eq "Automatic" -or $svc.StartType -eq "Automatic (Delayed Start)")) {
        Write-Host "  📋 $($svcInfo.Desc)... " -NoNewline
        try {
            Set-ServiceState -Name $svcInfo.Name -StartupType Manual -Stop ($svc.Status -eq "Running")
            # Validar
            if ($Global:DryRun -or (Confirm-ServiceState -Name $svcInfo.Name -ExpectedStartType "Manual")) {
                Write-Host "Manual ✅" -ForegroundColor Green
                $optimized++
                Log "Servicio a Manual: $($svcInfo.Name)"
            } else {
                Write-Host "⚠️ Parcial" -ForegroundColor Yellow
                $failed++
                Log "WARN: Servicio $($svcInfo.Name) no quedó en Manual"
            }
        } catch {
            Write-Host "Error ❌" -ForegroundColor Red
            $failed++
        }
    } else {
        $alreadyOk++
    }
}

# Desactivar (lista centralizada en config.ps1)
foreach ($svcInfo in $Global:ServicesToDisable) {
    $processed++
    Write-Progress -Activity "Optimizando servicios" -Status "$processed/$totalSvc — $($svcInfo.Desc)" -PercentComplete ([math]::Round(($processed/$totalSvc)*100,0))
    # En HDD, no desactivar SysMain
    if ($svcInfo.Name -eq "SysMain" -and !$Global:IsSSD) {
        Write-Info "SysMain mantenido (HDD detectado)"
        $alreadyOk++
        continue
    }
    
    $svc = Get-Service -Name $svcInfo.Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -ne "Disabled") {
        Write-Host "  🔴 $($svcInfo.Desc)... " -NoNewline
        try {
            Set-ServiceState -Name $svcInfo.Name -StartupType Disabled -Stop $true
            # Validar
            if ($Global:DryRun -or (Confirm-ServiceState -Name $svcInfo.Name -ExpectedStartType "Disabled")) {
                Write-Host "Desactivado ✅" -ForegroundColor Green
                $optimized++
                Log "Servicio desactivado: $($svcInfo.Name)"
            } else {
                Write-Host "⚠️ Parcial" -ForegroundColor Yellow
                $failed++
                Log "WARN: Servicio $($svcInfo.Name) no quedó en Disabled"
            }
        } catch {
            Write-Host "Error ❌" -ForegroundColor Red
            $failed++
        }
    } else {
        $alreadyOk++
    }
}

Write-Progress -Activity "Optimizando servicios" -Completed
Write-Host ""
Write-Success "Servicios optimizados: $optimized"
if ($failed -gt 0) { Write-Warn "Con errores: $failed" }
Write-Info "Ya estaban OK: $alreadyOk"
Write-Info "Los servicios se pueden restaurar con rescue.ps1"
Show-LogPath
Log "Services optimizer completado: $optimized optimizados, $failed errores"
