# ============================================================
# DISK CLEANUP - Limpiar archivos temporales y basura del sistema
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🧹 DISK CLEANUP"

$cleaned = 0
$errors = 0
$totalFreed = 0

# Estado actual del disco
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeBefore = [math]::Round($disk.FreeSpace / 1GB, 2)
Write-Host "  Disco C: — Libre antes: ${freeBefore} GB" -ForegroundColor White
Write-Host ""

$totalSteps = 8
$currentStep = 0

$currentStep++

# ============================================================
# 1. Archivos temporales del usuario
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Temporales" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 1 "Limpiando temporales del usuario..."
try {
    $tempPaths = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "$env:WINDIR\Temp"
    )
    $tempFreed = 0
    foreach ($tempPath in $tempPaths) {
        if (Test-Path $tempPath) {
            $files = Get-ChildItem $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            if (!$Global:DryRun) {
                $files | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $tempFreed += $size
        }
    }
    $mbFreed = [math]::Round($tempFreed / 1MB, 1)
    Write-Success "Temporales limpiados: $mbFreed MB"
    $totalFreed += $tempFreed
    $cleaned++
} catch {
    Write-Error "Error al limpiar temporales: $_"
    $errors++
}

$currentStep++

# ============================================================
# 2. Windows Update Cache
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Windows Update" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 2 "Limpiando caché de Windows Update..."
try {
    $wuPath = "$env:WINDIR\SoftwareDistribution\Download"
    if (Test-Path $wuPath) {
        $wuFiles = Get-ChildItem $wuPath -Recurse -Force -ErrorAction SilentlyContinue
        $wuSize = ($wuFiles | Measure-Object -Property Length -Sum).Sum
        if (!$Global:DryRun) {
            # Detener servicio WU temporalmente
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            $wuFiles | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Start-Service wuauserv -ErrorAction SilentlyContinue
        }
        $wuMB = [math]::Round($wuSize / 1MB, 1)
        Write-Success "WU cache limpiado: $wuMB MB"
        $totalFreed += $wuSize
    } else {
        Write-Info "WU cache ya está vacío"
    }
    $cleaned++
} catch {
    Write-Error "Error al limpiar WU cache: $_"
    $errors++
}

$currentStep++

# ============================================================
# 3. Caché de thumbnails
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Thumbnails" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 3 "Limpiando caché de thumbnails..."
try {
    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    $thumbFiles = Get-ChildItem $thumbPath -Filter "thumbcache_*" -Force -ErrorAction SilentlyContinue
    $thumbSize = ($thumbFiles | Measure-Object -Property Length -Sum).Sum
    if (!$Global:DryRun) {
        $thumbFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    $thumbMB = [math]::Round($thumbSize / 1MB, 1)
    Write-Success "Thumbnails limpiados: $thumbMB MB"
    $totalFreed += $thumbSize
    $cleaned++
} catch {
    Write-Error "Error al limpiar thumbnails: $_"
    $errors++
}

$currentStep++

# ============================================================
# 4. Logs de Windows (Event Logs antiguos)
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Event Logs" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 4 "Limpiando logs de eventos antiguos..."
try {
    if (!$Global:DryRun) {
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | 
            Where-Object { $_.RecordCount -gt 0 -and $_.LogName -notmatch "Security|System|Application" }
        foreach ($log in $logs) {
            try {
                $log.BackupLog = $null
                [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
            } catch {}
        }
    }
    Write-Success "Logs de eventos limpiados"
    $cleaned++
} catch {
    Write-Error "Error al limpiar logs: $_"
    $errors++
}

$currentStep++

# ============================================================
# 5. Prefetch
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Prefetch" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 5 "Limpiando Prefetch..."
try {
    $prefetchPath = "$env:WINDIR\Prefetch"
    if (Test-Path $prefetchPath) {
        $pfFiles = Get-ChildItem $prefetchPath -Filter "*.pf" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
        $pfSize = ($pfFiles | Measure-Object -Property Length -Sum).Sum
        if (!$Global:DryRun) {
            $pfFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        $pfMB = [math]::Round($pfSize / 1MB, 1)
        Write-Success "Prefetch limpiado (>30 días): $pfMB MB"
        $totalFreed += $pfSize
    } else {
        Write-Info "Prefetch no accesible"
    }
    $cleaned++
} catch {
    Write-Error "Error al limpiar Prefetch: $_"
    $errors++
}

$currentStep++

# ============================================================
# 6. Papelera de reciclaje
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Papelera" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 6 "Vaciando papelera de reciclaje..."
try {
    if (!$Global:DryRun) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
    Write-Success "Papelera vaciada"
    $cleaned++
} catch {
    Write-Error "Error al vaciar papelera: $_"
    $errors++
}

$currentStep++

# ============================================================
# 7. Caché de navegadores (Chrome, Edge, Firefox)
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Navegadores" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 7 "Limpiando caché de navegadores..."
try {
    $browserPaths = @(
        # Chrome
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        # Edge
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        # Firefox
        "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    )
    $browserFreed = 0
    foreach ($bp in $browserPaths) {
        if (Test-Path $bp) {
            $files = Get-ChildItem $bp -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($files | Measure-Object -Property Length -Sum).Sum
            if (!$Global:DryRun) {
                $files | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            $browserFreed += $size
        }
    }
    $brMB = [math]::Round($browserFreed / 1MB, 1)
    Write-Success "Caché de navegadores: $brMB MB"
    $totalFreed += $browserFreed
    $cleaned++
} catch {
    Write-Error "Error al limpiar caché de navegadores: $_"
    $errors++
}

$currentStep++

# ============================================================
# 8. Caché de iconos
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Status "Paso $currentStep/$totalSteps — Iconos" -PercentComplete ([math]::Round(($currentStep/$totalSteps)*100,0))
Write-Step 8 "Limpiando caché de iconos..."
try {
    $iconDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    $iconFiles = @()
    if (Test-Path $iconDir) {
        $iconFiles = Get-ChildItem $iconDir -Filter "iconcache_*" -Force -ErrorAction SilentlyContinue
    }
    $iconSize = ($iconFiles | Measure-Object -Property Length -Sum).Sum
    if (!$Global:DryRun -and $iconFiles.Count -gt 0) {
        $iconFiles | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    $iconMB = [math]::Round($iconSize / 1MB, 1)
    Write-Success "Iconos cache limpiados: $iconMB MB"
    $totalFreed += $iconSize
    $cleaned++
} catch {
    Write-Error "Error al limpiar iconos: $_"
    $errors++
}

# ============================================================
# Resultado
# ============================================================
Write-Progress -Activity "Disk Cleanup" -Completed
Write-Host ""

if (!$Global:DryRun) {
    $diskAfter = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeAfter = [math]::Round($diskAfter.FreeSpace / 1GB, 2)
    $freedGB = [math]::Round(($freeAfter - $freeBefore), 2)
    
    Write-Header "✅ DISK CLEANUP COMPLETADO"
    Write-Host "  Libre antes:  ${freeBefore} GB" -ForegroundColor White
    Write-Host "  Libre después: ${freeAfter} GB" -ForegroundColor Green
    Write-Host "  Liberado:      +${freedGB} GB" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Header "✅ DISK CLEANUP (DRY-RUN)"
    $totalMB = [math]::Round($totalFreed / 1MB, 1)
    Write-Info "Se liberarían ~$totalMB MB"
}

Write-Success "Pasos completados: $cleaned"
if ($errors -gt 0) { Write-Warn "Errores: $errors" }
Show-LogPath
Log "Disk cleanup completado: $cleaned pasos, $errors errores, ~$([math]::Round($totalFreed/1MB,1))MB"
