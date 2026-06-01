[CmdletBinding()]
param([object]$AutoApply = $null)

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         04 - OPTIMIZACIÓN DE RED                ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  [1] Limpiar caché DNS" -ForegroundColor White
Write-Host "  [2] Resetear stack TCP/IP" -ForegroundColor White
Write-Host "  [3] Mostrar info de red actual" -ForegroundColor White
Write-Host "  [0] Volver" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opción: " -NoNewline
$opt = Read-Host

switch ($opt) {
    '1' {
        ipconfig /flushdns | Out-Null
        Write-Host "  [OK] Caché DNS limpiada" -ForegroundColor Green
    }
    '2' {
        Write-Host "  Reseteando stack de red..." -ForegroundColor Cyan
        netsh int ip reset | Out-Null
        netsh winsock reset | Out-Null
        Write-Host "  [OK] Stack TCP/IP reseteado. Reiniciá el equipo para aplicar." -ForegroundColor Green
    }
    '3' {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($a in $adapters) {
            $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            Write-Host "  $($a.Name): $($ip.IPAddress) | $([math]::Round($a.LinkSpeed/1MB))Mbps | MAC: $($a.MacAddress)" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
