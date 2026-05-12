# ============================================================
# NETWORK OPTIMIZER - Optimización avanzada de red
# ============================================================
# Optimiza TCP/UDP para menor latencia y mayor throughput.
# Ideal para: gaming, streaming, descargas grandes, videoconferencia.
# ============================================================

param(
    [ValidateSet("optimize", "revert", "status")]
    [string]$Action = "optimize"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

$NetworkStateFile = Join-Path $RescueDir "network_state.json"

function Get-NetworkStatus {
    if (Test-Path $NetworkStateFile) {
        $state = Get-Content $NetworkStateFile -Raw | ConvertFrom-Json
        return $state
    }
    return $null
}

function Save-NetworkState {
    param($OriginalValues)
    @{
        Active = $true
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        OriginalValues = $OriginalValues
    } | ConvertTo-Json -Depth 5 | Out-File $NetworkStateFile -Encoding UTF8
}

# ============================================================
# OPTIMIZAR RED
# ============================================================
function Optimize-Network {
    Write-Header "🌐 NETWORK OPTIMIZER"
    Write-Host ""
    Write-Host "  Optimizando red para:" -ForegroundColor Yellow
    Write-Host "    • Menor latencia (ping)" -ForegroundColor Gray
    Write-Host "    • Mayor throughput (descargas)" -ForegroundColor Gray
    Write-Host "    • Mejor gaming online" -ForegroundColor Gray
    Write-Host "    • Videoconferencia más estable" -ForegroundColor Gray
    Write-Host ""

    $originalValues = @{}
    $optimized = 0
    $errors = 0

    # 1. TCP Global Settings
    Write-Step 1 "Optimizando TCP global..."
    try {
        # Guardar valores originales
        $originalValues.AutoTuning = (netsh int tcp show global | Select-String "Receive Window Auto-Tuning Level" | ForEach-Object { ($_ -split ":")[1].Trim() })
        $originalValues.Chimney = (netsh int tcp show global | Select-String "Chimney Offload State" | ForEach-Object { ($_ -split ":")[1].Trim() })
        $originalValues.RSS = (netsh int tcp show global | Select-String "Receive-Side Scaling State" | ForEach-Object { ($_ -split ":")[1].Trim() })

        if (!$Global:DryRun) {
            # Auto-tuning normal (mejor para la mayoría)
            netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
            # Chimney offload (descarga trabajo de CPU a NIC)
            netsh int tcp set global chimney=enabled 2>&1 | Out-Null
            # Receive-Side Scaling (distribuye carga entre cores)
            netsh int tcp set global rss=enabled 2>&1 | Out-Null
            # Direct Cache Access (reduce latencia)
            netsh int tcp set global dca=enabled 2>&1 | Out-Null
            # Congestion provider (CTCP es más moderno)
            netsh int tcp set global congestionprovider=ctcp 2>&1 | Out-Null
        }
        Write-Success "TCP global optimizado"
        $optimized++
    } catch {
        Write-Warn "Algunos ajustes TCP no se aplicaron"
        $errors++
    }

    # 2. TCP Parameters (Registry)
    Write-Step 2 "Ajustando parámetros TCP..."
    try {
        $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

        # Guardar originales
        $originalValues.TcpAckFrequency = (Get-ItemProperty $tcpParams -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
        $originalValues.TCPNoDelay = (Get-ItemProperty $tcpParams -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay
        $originalValues.TcpDelAckTicks = (Get-ItemProperty $tcpParams -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue).TcpDelAckTicks
        $originalValues.DefaultTTL = (Get-ItemProperty $tcpParams -Name "DefaultTTL" -ErrorAction SilentlyContinue).DefaultTTL
        $originalValues.MaxFreeTcbs = (Get-ItemProperty $tcpParams -Name "MaxFreeTcbs" -ErrorAction SilentlyContinue).MaxFreeTcbs
        $originalValues.MaxUserPort = (Get-ItemProperty $tcpParams -Name "MaxUserPort" -ErrorAction SilentlyContinue).MaxUserPort

        if (!$Global:DryRun) {
            # TCP Ack Frequency (1 = ack cada paquete, reduce latencia)
            Set-RegProperty $tcpParams -Name "TcpAckFrequency" -Value 1
            # TCP No Delay (desactiva Nagle's algorithm)
            Set-RegProperty $tcpParams -Name "TCPNoDelay" -Value 1
            # Tcp Del Ack Ticks (0 = ack inmediato)
            Set-RegProperty $tcpParams -Name "TcpDelAckTicks" -Value 0
            # Default TTL (128 es el óptimo)
            Set-RegProperty $tcpParams -Name "DefaultTTL" -Value 128
            # Max Free Tcbs (más conexiones simultáneas)
            Set-RegProperty $tcpParams -Name "MaxFreeTcbs" -Value 65536
            # Max User Port (más puertos disponibles)
            Set-RegProperty $tcpParams -Name "MaxUserPort" -Value 65534
            # TcpTimedWaitDelay (libera puertos más rápido)
            Set-RegProperty $tcpParams -Name "TcpTimedWaitDelay" -Value 30
        }
        Write-Success "Parámetros TCP optimizados"
        $optimized++
    } catch {
        Write-Warn "Error al ajustar parámetros TCP: $_"
        $errors++
    }

    # 3. DNS Optimizer
    Write-Step 3 "Optimizando DNS..."
    try {
        # DNS públicos más rápidos (Cloudflare + Google)
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            if (!$Global:DryRun) {
                # Guardar DNS original
                $originalDNS = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
                $originalValues."DNS_$($adapter.Name)" = $originalDNS.ServerAddresses

                # Configurar Cloudflare (1.1.1.1) + Google (8.8.8.8)
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @("1.1.1.1", "8.8.8.8") -ErrorAction SilentlyContinue
            }
        }
        Write-Success "DNS optimizado (Cloudflare + Google)"
        $optimized++
    } catch {
        Write-Warn "Error al optimizar DNS: $_"
        $errors++
    }

    # 4. Network Throttling (Windows limita ancho de banda para multimedia)
    Write-Step 4 "Desactivando throttling de red..."
    try {
        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (!$Global:DryRun -and !(Test-Path $mmPath)) { New-Item -Path $mmPath -Force | Out-Null }
        Set-RegProperty $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff
        Set-RegProperty $mmPath -Name "SystemResponsiveness" -Value 0

        # Gaming profile
        $gamePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        if (!$Global:DryRun -and !(Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
        Set-RegProperty $gamePath -Name "GPU Priority" -Value 8
        Set-RegProperty $gamePath -Name "Priority" -Value 6
        Set-RegProperty $gamePath -Name "Scheduling Category" -Value "High"
        Set-RegProperty $gamePath -Name "SFIO Priority" -Value "High"

        Write-Success "Throttling desactivado + Gaming profile aplicado"
        $optimized++
    } catch {
        Write-Warn "Error al desactivar throttling: $_"
        $errors++
    }

    # 5. NIC Optimizations
    Write-Step 5 "Optimizando adaptadores de red..."
    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            if (!$Global:DryRun) {
                # Desactivar interrupt moderation (menor latencia)
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
                # Desactivar flow control
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
                # RSS queues
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Maximum Number of RSS Queues" -DisplayValue "4" -ErrorAction SilentlyContinue
            }
        }
        Write-Success "Adaptadores de red optimizados"
        $optimized++
    } catch {
        Write-Warn "Algunos ajustes de NIC no se aplicaron (normal si no están disponibles)"
    }

    # 6. Flush DNS y reset
    Write-Step 6 "Limpiando caché de red..."
    try {
        if (!$Global:DryRun) {
            ipconfig /flushdns 2>&1 | Out-Null
            netsh winsock reset 2>&1 | Out-Null
        }
        Write-Success "Caché de red limpiada"
        $optimized++
    } catch {
        Write-Warn "Error al limpiar caché: $_"
    }

    # Guardar estado
    Save-NetworkState -OriginalValues $originalValues

    Write-Host ""
    Write-Header "✅ NETWORK OPTIMIZER COMPLETADO"
    Write-Success "$optimized optimizaciones aplicadas"
    if ($errors -gt 0) { Write-Warn "Errores: $errors" }
    Write-Info "Se recomienda REINICIAR para aplicar todos los cambios."
    Show-LogPath
    Log "Network optimizer completado: $optimized tweaks, $errors errores"
    Send-Notification -Title "🌐 Red Optimizada" -Message "TCP/DNS/latencia optimizados" -Icon "globe"
}

# ============================================================
# REVERTIR
# ============================================================
function Revert-Network {
    $state = Get-NetworkStatus
    if (!$state -or !$state.Active) {
        Write-Info "Network Optimizer no está activo."
        return
    }

    Write-Header "🔄 REVIRTIENDO NETWORK OPTIMIZER"
    Write-Host "  Optimizado desde: $($state.Timestamp)" -ForegroundColor Gray
    Write-Host ""

    $reverted = 0

    # 1. Restaurar TCP global
    Write-Step 1 "Restaurando TCP global..."
    try {
        netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
        netsh int tcp set global chimney=disabled 2>&1 | Out-Null
        netsh int tcp set global rss=enabled 2>&1 | Out-Null
        netsh int tcp set global congestionprovider=default 2>&1 | Out-Null
        Write-Success "TCP global restaurado"
        $reverted++
    } catch {
        Write-Warn "Error al restaurar TCP global"
    }

    # 2. Restaurar parámetros TCP
    Write-Step 2 "Restaurando parámetros TCP..."
    try {
        $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Remove-ItemProperty $tcpParams -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "DefaultTTL" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "MaxFreeTcbs" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "MaxUserPort" -ErrorAction SilentlyContinue
        Remove-ItemProperty $tcpParams -Name "TcpTimedWaitDelay" -ErrorAction SilentlyContinue
        Write-Success "Parámetros TCP restaurados"
        $reverted++
    } catch {
        Write-Warn "Error al restaurar parámetros TCP"
    }

    # 3. Restaurar DNS
    Write-Step 3 "Restaurando DNS..."
    try {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        Write-Success "DNS restaurado (automático)"
        $reverted++
    } catch {
        Write-Warn "Error al restaurar DNS"
    }

    # 4. Restaurar throttling
    Write-Step 4 "Restaurando throttling..."
    try {
        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-RegProperty $mmPath -Name "NetworkThrottlingIndex" -Value 10
        Set-RegProperty $mmPath -Name "SystemResponsiveness" -Value 20
        Write-Success "Throttling restaurado"
        $reverted++
    } catch {
        Write-Warn "Error al restaurar throttling"
    }

    # 5. Flush DNS
    Write-Step 5 "Limpiando caché..."
    try {
        ipconfig /flushdns 2>&1 | Out-Null
        Write-Success "Caché limpiada"
        $reverted++
    } catch {}

    # Eliminar estado
    Remove-Item $NetworkStateFile -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Success "Network Optimizer revertido ($reverted pasos)"
    Write-Info "Reiniciá para aplicar los cambios."
    Log "Network optimizer revertido: $reverted pasos"
}

# ============================================================
# STATUS
# ============================================================
function Show-NetworkStatus {
    Write-Header "📊 NETWORK STATUS"

    $state = Get-NetworkStatus
    if ($state -and $state.Active) {
        Write-Host "  Estado: " -NoNewline
        Write-Host "🌐 OPTIMIZADO" -ForegroundColor Green
        Write-Host "  Optimizado desde: $($state.Timestamp)" -ForegroundColor Gray
    } else {
        Write-Host "  Estado: " -NoNewline
        Write-Host "⚙️ POR DEFECTO" -ForegroundColor Yellow
    }

    # Info actual
    Write-Host ""
    Write-Host "  ─── TCP GLOBAL ───" -ForegroundColor Gray
    $tcpGlobal = netsh int tcp show global 2>&1
    foreach ($line in $tcpGlobal) {
        if ($line -match "^\s+(.+?)\s*:\s*(.+)$") {
            Write-Host "    $($Matches[1].Trim()): $($Matches[2].Trim())" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host "  ─── DNS ───" -ForegroundColor Gray
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
        Write-Host "    $($adapter.Name): $($dns.ServerAddresses -join ', ')" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  ─── PING ───" -ForegroundColor Gray
    $ping = Test-NetConnection -ComputerName "1.1.1.1" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($ping) {
        $pingColor = if ($ping.PingReplyDetails.RoundtripTime -lt 30) { "Green" } elseif ($ping.PingReplyDetails.RoundtripTime -lt 100) { "Yellow" } else { "Red" }
        Write-Host "    1.1.1.1: $($ping.PingReplyDetails.RoundtripTime) ms" -ForegroundColor $pingColor
    } else {
        Write-Host "    Sin conexión" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "  Optimizar:  .\network-optimizer.ps1 -Action optimize" -ForegroundColor Gray
    Write-Host "  Revertir:   .\network-optimizer.ps1 -Action revert" -ForegroundColor Gray
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "optimize" { Optimize-Network }
    "revert"   { Revert-Network }
    "status"   { Show-NetworkStatus }
}
