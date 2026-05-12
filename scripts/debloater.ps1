# ============================================================
# DEBLOATER - Eliminar apps basura de Windows 11
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🗑️ DEBLOATER - ELIMINAR APPS BASURA"

# Usar lista centralizada de config.ps1
$Bloatware = $Global:BloatwareApps

# Mostrar qué se va a eliminar
Write-Host "  Apps bloatware detectadas:" -ForegroundColor White
Write-Host ""
$found = @()
foreach ($app in $Bloatware) {
    $packages = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
    if ($packages) {
        foreach ($pkg in $packages) {
            $found += $pkg
            Write-Host "    🗑️  $($pkg.Name)" -ForegroundColor Red
        }
    }
}

if ($found.Count -eq 0) {
    Write-Success "No se encontró bloatware. Tu Windows ya está limpio."
    exit 0
}

Write-Host ""
Write-Host "  Total: $($found.Count) apps encontradas" -ForegroundColor Yellow
Write-Host ""
Write-Warn "Esto va a desinstalar las apps listadas arriba."
Write-Warn "Las apps del sistema (Store, Settings, etc.) NO se tocan."
Write-Host ""
$confirm = Read-Host "  Escribí SI para confirmar"

if ($confirm -ne "SI") {
    Write-Info "Cancelado. No se hizo ningún cambio."
    exit 0
}

Log "Iniciando debloat de $($found.Count) apps"

# Eliminar apps
$removed = 0
$failed = 0
$total = $found.Count

foreach ($pkg in $found) {
    $pct = [math]::Round((($removed + $failed) / $total) * 100, 0)
    Write-Progress -Activity "Eliminando bloatware" -Status "$($removed+$failed)/$total — $($pkg.Name)" -PercentComplete $pct
    Write-Host "  Eliminando: $($pkg.Name)... " -NoNewline
    try {
        if ($Global:DryRun) {
            Write-Host "DRY-RUN ⏭️" -ForegroundColor Yellow
            $removed++
        } else {
            Get-AppxPackage -Name $pkg.Name -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$($pkg.Name)*" } | 
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            # Validar que se eliminó
            $stillThere = Get-AppxPackage -Name $pkg.Name -AllUsers -ErrorAction SilentlyContinue
            if ($stillThere) {
                Write-Host "⚠️ Parcial" -ForegroundColor Yellow
                $failed++
                Log "WARN: $($pkg.Name) sigue instalado después de intentar eliminar"
            } else {
                Write-Host "✅" -ForegroundColor Green
                $removed++
                Log "Eliminado: $($pkg.Name)"
            }
        }
    } catch {
        Write-Host "❌" -ForegroundColor Red
        $failed++
        Log "Error al eliminar: $($pkg.Name) - $_"
    }
}

Write-Progress -Activity "Eliminando bloatware" -Completed
Write-Host ""
Write-Success "Completado: $removed eliminadas, $failed errores"
Write-Info "Las apps se pueden restaurar desde Microsoft Store si las necesitás."
Show-LogPath
Log "Debloat completado: $removed eliminadas, $failed errores"
