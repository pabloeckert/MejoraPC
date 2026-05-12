# ============================================================
# MEMORY OPTIMIZER - Liberar y optimizar memoria RAM
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "💾 MEMORY OPTIMIZER"

$tweaks = 0
$errors = 0

# 1. Estado actual de la memoria
Write-Step "📊" "Estado actual de memoria:"
$os = Get-CimInstance Win32_OperatingSystem
$totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
$pctUsed = [math]::Round(($usedRAM / $totalRAM) * 100, 1)

Write-Host ""
Write-Host "    Total:      ${totalRAM} GB" -ForegroundColor White
Write-Host "    Usado:      ${usedRAM} GB ($pctUsed%)" -ForegroundColor $(if ($pctUsed -gt 80) { "Red" } elseif ($pctUsed -gt 60) { "Yellow" } else { "Green" })
Write-Host "    Libre:      ${freeRAM} GB" -ForegroundColor $(if ($freeRAM -lt 1) { "Red" } else { "Green" })
Write-Host ""

if ($pctUsed -gt 90) {
    Write-Warn "¡Memoria crítica! Menos del 10% libre."
    Write-Host ""
}

# 2. Liberar memoria inmediatamente
Write-Step 1 "Liberando memoria RAM..."
try {
    if ($Global:DryRun) {
        Write-Info "[DRY-RUN] Liberar memoria (EmptyWorkingSet + GC.Collect)"
    } else {
        $signature = @"
    using System;
    using System.Runtime.InteropServices;
    public class Memory {
        [DllImport("kernel32.dll")]
        public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
        [DllImport("psapi.dll")]
        public static extern int EmptyWorkingSet(IntPtr hwProc);
    }
"@
        Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
        
        Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.Name -notin @("System", "Idle", "svchost") } | ForEach-Object {
            try {
                [Memory]::EmptyWorkingSet($_.Handle) | Out-Null
            } catch {}
        }
        
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        $newFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
        $freed = [math]::Round($newFree - $freeRAM, 2)
        Write-Success "Memoria liberada: ${freed} GB"
    }
    $tweaks++
} catch {
    Write-Error "Error al liberar memoria: $_"
    $errors++
}

# 3. Ajustar pagefile
Write-Step 2 "Optimizando archivo de paginación..."
try {
    if ($Global:DryRun) {
        Write-Info "[DRY-RUN] Configurar pagefile a 1.5x RAM (fijo)"
    } else {
        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.AutomaticManagedPagefile) {
            Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } -ErrorAction Stop
        }
        
        $ramMB = [int]($os.TotalVisibleMemorySize / 1KB)
        $pagefileSize = [int]($ramMB * 1.5)
        
        $pagefile = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
        if ($pagefile) {
            $pagefile.InitialSize = $pagefileSize
            $pagefile.MaximumSize = $pagefileSize
            Set-CimInstance -InputObject $pagefile -ErrorAction Stop
        }
        Write-Success "Pagefile configurado: ${pagefileSize} MB (fijo)"
    }
    $tweaks++
} catch {
    Write-Error "Error al configurar pagefile: $_"
    $errors++
}

# 4. Desactivar apps en segundo plano
Write-Step 3 "Desactivando apps en segundo plano..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    Set-RegProperty $path -Name "GlobalUserDisabled" -Value 1
    
    $excludeApps = @("Microsoft.WindowsCalculator", "Microsoft.WindowsStore", "Microsoft.Windows.Photos")
    foreach ($app in $excludeApps) {
        $appPath = "$path\$app"
        if (Test-Path $appPath) {
            Set-RegProperty $appPath -Name "Disabled" -Value 0
        }
    }
    
    # Validar
    if (!$Global:DryRun) {
        $val = (Get-ItemProperty $path -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue).GlobalUserDisabled
        if ($val -eq 1) {
            Write-Success "Apps en segundo plano desactivadas (excepto Calculator, Store, Photos)"
        } else {
            Write-Warn "El registro no se aplicó correctamente"
            $errors++
        }
    } else {
        Write-Success "Apps en segundo plano (dry-run)"
    }
    $tweaks++
} catch {
    Write-Error "Error al desactivar apps en segundo plano: $_"
    $errors++
}

# 5. Optimizar servicios que consumen RAM
Write-Step 4 "Reduciendo consumo de servicios..."
try {
    Set-RegProperty "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value ($os.TotalVisibleMemorySize)
    Write-Success "Servicios optimizados para reducir RAM"
    $tweaks++
} catch {
    Write-Error "Error al optimizar servicios: $_"
    $errors++
}

# 6. Desactivar NTFS last access timestamp
Write-Step 5 "Optimizando NTFS..."
try {
    if (!$Global:DryRun) {
        fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    } else {
        Write-Info "[DRY-RUN] fsutil behavior set disablelastaccess 1"
    }
    Write-Success "NTFS last access desactivado"
    $tweaks++
} catch {
    Write-Error "Error al optimizar NTFS: $_"
    $errors++
}

# 7. Limpiar memoria del sistema
Write-Step 6 "Limpiando caché del sistema..."
try {
    if (!$Global:DryRun) {
        ipconfig /flushdns 2>&1 | Out-Null
        Write-Success "Caché del sistema limpiado"
    } else {
        Write-Info "[DRY-RUN] ipconfig /flushdns"
    }
    $tweaks++
} catch {
    Write-Error "Error al limpiar caché: $_"
    $errors++
}

# Resultado final
Write-Host ""
Write-Step "📊" "Estado después de optimizar:"
if (!$Global:DryRun) {
    $newOS = Get-CimInstance Win32_OperatingSystem
    $newFree = [math]::Round($newOS.FreePhysicalMemory / 1MB, 2)
    $newUsed = [math]::Round($totalRAM - $newFree, 2)
    $newPct = [math]::Round(($newUsed / $totalRAM) * 100, 1)

    Write-Host ""
    Write-Host "    Libre:      ${freeRAM} GB → ${newFree} GB" -ForegroundColor $(if ($newFree -gt $freeRAM) { "Green" } else { "White" })
    Write-Host "    Usado:      $pctUsed% → $newPct%" -ForegroundColor $(if ($newPct -lt $pctUsed) { "Green" } else { "White" })
    Write-Host ""
} else {
    Write-Info "[DRY-RUN] Estado final no disponible en modo simulación"
}

Write-Header "✅ MEMORY OPTIMIZER COMPLETADO"
Write-Success "$tweaks optimizaciones aplicadas."
if ($errors -gt 0) { Write-Warn "Errores: $errors" }
Show-LogPath
Log "Memory optimizer completado: $tweaks tweaks, $errors errores, RAM libre: ${freeRAM}GB"
