[CmdletBinding()]
param()

$scriptRoot = $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         02 - OPTIMIZACIÓN DE SERVICIOS          ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$candidatos = @(
    @{ Name = 'SysMain';          Desc = 'Superfetch — innecesario con SSD' }
    @{ Name = 'WSearch';          Desc = 'Windows Search — deshabilitá si no usás búsqueda' }
    @{ Name = 'DiagTrack';        Desc = 'Telemetría — Connected User Experiences' }
    @{ Name = 'XblGameSave';      Desc = 'Xbox Game Save — innecesario sin Xbox' }
    @{ Name = 'RetailDemo';       Desc = 'Retail Demo — solo para exhibición' }
    @{ Name = 'MapsBroker';       Desc = 'Mapas offline — innecesario generalmente' }
    @{ Name = 'Fax';              Desc = 'Fax — casi nunca se usa' }
    @{ Name = 'lfsvc';            Desc = 'Geolocalización' }
    @{ Name = 'WMPNetworkSvc';    Desc = 'Windows Media Player Network' }
    @{ Name = 'WerSvc';           Desc = 'Reporte de errores de Windows' }
)

Write-Host "  Servicios candidatos a deshabilitar:" -ForegroundColor Gray
Write-Host ""

foreach ($svc in $candidatos) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        $status = $service.Status
        $color = if ($status -eq 'Running') { 'Yellow' } else { 'Green' }
        Write-Host "  [$status] $($svc.Name.PadRight(18)) $($svc.Desc)" -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "  Para deshabilitar un servicio:" -ForegroundColor DarkGray
Write-Host "  Set-Service -Name 'NombreServicio' -StartupType Disabled" -ForegroundColor DarkGray
Write-Host "  Stop-Service -Name 'NombreServicio' -Force" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
