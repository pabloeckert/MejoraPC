# ============================================================
# SERVICES OPTIMIZER - Optimizar servicios de Windows
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🔧 SERVICES OPTIMIZER"

# Servicios seguros de poner en Manual (no se desactivan, solo no arrancan solos)
$ServicesToManual = @(
    # Telemetría y diagnósticos
    @{ Name = "DiagTrack"; Desc = "Telemetría de Microsoft" }
    @{ Name = "diagnosticshub.standardcollector.service"; Desc = "Collector de diagnósticos" }
    @{ Name = "diagsvc"; Desc = "Servicio de diagnósticos" }
    @{ Name = "DPS"; Desc = "Directivas de diagnóstico" }
    @{ Name = "WdiServiceHost"; Desc = "Host de diagnóstico" }
    @{ Name = "WdiSystemHost"; Desc = "Sistema de diagnóstico" }
    
    # Servicios de terceros innecesarios
    @{ Name = "AdobeARMservice"; Desc = "Adobe Acrobat Update" }
    @{ Name = "brave"; Desc = "Brave Update" }
    @{ Name = "bravem"; Desc = "Brave Update (med)" }
    @{ Name = "edgeupdate"; Desc = "Edge Update" }
    @{ Name = "edgeupdatem"; Desc = "Edge Update (med)" }
    @{ Name = "gupdate"; Desc = "Google Update" }
    @{ Name = "gupdatem"; Desc = "Google Update (med)" }
    @{ Name = "GoogleChromeElevationService"; Desc = "Chrome Elevation" }
    @{ Name = "CapCutServiceLS"; Desc = "CapCut Service" }
    @{ Name = "DFWSIDService"; Desc = "Wondershare WSID" }
    @{ Name = "DSAService"; Desc = "Intel Driver Assistant" }
    @{ Name = "DSAUpdateService"; Desc = "Intel Driver Assistant Updater" }
    @{ Name = "AESMService"; Desc = "Intel SGX AESM" }
    
    # Windows features innecesarias
    @{ Name = "MapsBroker"; Desc = "Mapas descargados" }
    @{ Name = "lfsvc"; Desc = "Geolocalización" }
    @{ Name = "SharedAccess"; Desc = "Internet Connection Sharing" }
    @{ Name = "RemoteRegistry"; Desc = "Registro remoto" }
    @{ Name = "RetailDemo"; Desc = "Modo demostración" }
    @{ Name = "WMPNetworkSvc"; Desc = "Windows Media Player Sharing" }
    @{ Name = "WerSvc"; Desc = "Windows Error Reporting" }
    @{ Name = "XblAuthManager"; Desc = "Xbox Auth" }
    @{ Name = "XblGameSave"; Desc = "Xbox Game Save" }
    @{ Name = "XboxGipSvc"; Desc = "Xbox Accessory" }
    @{ Name = "XboxNetApiSvc"; Desc = "Xbox Live Networking" }
    @{ Name = "SEMgrSvc"; Desc = "Pagos y NFC/SE" }
    @{ Name = "PhoneSvc"; Desc = "Servicio telefónico" }
    @{ Name = "TapiSrv"; Desc = "Telephony" }
    @{ Name = "MessagingService"; Desc = "Mensajería" }
    @{ Name = "PimIndexMaintenanceSvc"; Desc = "Contactos" }
    @{ Name = "BcastDVRUserService"; Desc = "Game DVR" }
    @{ Name = "wisvc"; Desc = "Windows Insider" }
    @{ Name = "dmwappushservice"; Desc = "WAP Push" }
)

# Servicios que se pueden desactivar completamente (solo si no los usás)
$ServicesToDisable = @(
    @{ Name = "SysMain"; Desc = "Superfetch (con SSD es innecesario)" }
    @{ Name = "WSearch"; Desc = "Windows Search Indexer (come RAM y CPU)" }
)

Write-Host "  Analizando servicios..." -ForegroundColor White
Write-Host ""

$optimized = 0
$alreadyOk = 0

# Poner en Manual
foreach ($svcInfo in $ServicesToManual) {
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

# Desactivar
foreach ($svcInfo in $ServicesToDisable) {
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
