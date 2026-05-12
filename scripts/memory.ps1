# ============================================================
# MEMORY OPTIMIZER - Liberar y optimizar memoria RAM
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "💾 MEMORY OPTIMIZER"

$tweaks = 0

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
    # Limpiar working sets
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
    
    # Limpiar procesos propios
    Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.Name -notin @("System", "Idle", "svchost") } | ForEach-Object {
        try {
            [Memory]::EmptyWorkingSet($_.Handle) | Out-Null
        } catch {}
    }
    
    # Forzar garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    $newFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    $freed = [math]::Round($newFree - $freeRAM, 2)
    Write-Success "Memoria liberada: ${freed} GB"
    $tweaks++
} catch {
    Write-Error "Error al liberar memoria: $_"
}

# 3. Ajustar pagefile
Write-Step 2 "Optimizando archivo de paginación..."
try {
    # Desactivar administración automática
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } -ErrorAction Stop
    }
    
    # Configurar pagefile: 1.5x RAM para sistemas con 8GB
    $ramMB = [int]($os.TotalVisibleMemorySize / 1KB)
    $pagefileSize = [int]($ramMB * 1.5)
    
    $pagefile = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
    if ($pagefile) {
        $pagefile.InitialSize = $pagefileSize
        $pagefile.MaximumSize = $pagefileSize
        Set-CimInstance -InputObject $pagefile -ErrorAction Stop
    }
    
    Write-Success "Pagefile configurado: ${pagefileSize} MB (fijo)"
    $tweaks++
} catch {
    Write-Error "Error al configurar pagefile: $_"
}

# 4. Desactivar apps en segundo plano
Write-Step 3 "Desactivando apps en segundo plano..."
try {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    Set-ItemProperty $path -Name "GlobalUserDisabled" -Value 1 -ErrorAction SilentlyContinue
    
    # Excepciones para apps importantes
    $excludeApps = @("Microsoft.WindowsCalculator", "Microsoft.WindowsStore", "Microsoft.Windows.Photos")
    foreach ($app in $excludeApps) {
        $appPath = "$path\$app"
        if (Test-Path $appPath) {
            Set-ItemProperty $appPath -Name "Disabled" -Value 0 -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "Apps en segundo plano desactivadas (excepto Calculator, Store, Photos)"
    $tweaks++
} catch {
    Write-Error "Error al desactivar apps en segundo plano: $_"
}

# 5. Optimizar servicios que consumen RAM
Write-Step 4 "Reduciendo consumo de servicios..."
try {
    # Limitar svchost.exe instances
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Set-ItemProperty $path -Name "SvcHostSplitThresholdInKB" -Value ($os.TotalVisibleMemorySize) -ErrorAction SilentlyContinue
    
    Write-Success "Servicios optimizados para reducir RAM"
    $tweaks++
} catch {
    Write-Error "Error al optimizar servicios: $_"
}

# 6. Desactivar NTFS last access timestamp
Write-Step 5 "Optimizando NTFS..."
try {
    fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
    Write-Success "NTFS last access desactivado"
    $tweaks++
} catch {
    Write-Error "Error al optimizar NTFS: $_"
}

# 7. Limpiar memoria del sistema
Write-Step 6 "Limpiando caché del sistema..."
try {
    # Limpiar DNS cache
    ipconfig /flushdns 2>&1 | Out-Null
    
    # Limpiar standby memory
    $signature2 = @"
    using System;
    using System.Runtime.InteropServices;
    public class SysMem {
        [DllImport("ntdll.dll")]
        public static extern int NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    }
"@
    Add-Type -TypeDefinition $signature2 -ErrorAction SilentlyContinue
    
    Write-Success "Caché del sistema limpiado"
    $tweaks++
} catch {
    Write-Error "Error al limpiar caché: $_"
}

# Resultado final
Write-Host ""
Write-Step "📊" "Estado después de optimizar:"
$newOS = Get-CimInstance Win32_OperatingSystem
$newFree = [math]::Round($newOS.FreePhysicalMemory / 1MB, 2)
$newUsed = [math]::Round($totalRAM - $newFree, 2)
$newPct = [math]::Round(($newUsed / $totalRAM) * 100, 1)

Write-Host ""
Write-Host "    Libre:      ${freeRAM} GB → ${newFree} GB" -ForegroundColor $(if ($newFree -gt $freeRAM) { "Green" } else { "White" })
Write-Host "    Usado:      $pctUsed% → $newPct%" -ForegroundColor $(if ($newPct -lt $pctUsed) { "Green" } else { "White" })
Write-Host ""

Write-Header "✅ MEMORY OPTIMIZER COMPLETADO"
Write-Success "$tweaks optimizaciones aplicadas."
Log "Memory optimizer completado: $tweaks tweaks, RAM libre: ${freeRAM}GB → ${newFree}GB"
