# ============================================================
# RESCUE POINT - Sistema de respaldo y restauración
# ============================================================

param(
    [string]$Action = "create",
    [string]$Name = "manual"
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

function Create-RescuePoint {
    param([string]$Name = "auto")
    
    $rescueId = "${Name}_$Timestamp"
    $rescuePath = Join-Path $RescueDir $rescueId
    New-Item -ItemType Directory -Path $rescuePath -Force | Out-Null
    
    Write-Header "💾 CREANDO RESCUE POINT: $rescueId"
    Log "Creando rescue point: $rescueId"
    
    # 1. Programas de inicio
    Write-Step 1 "Guardando programas de inicio..."
    $startup = @()
    $startup += Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
    $regRun = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    $regRunLM = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    @{
        StartupCommands = $startup
        HKCU_Run = $regRun
        HKLM_Run = $regRunLM
    } | ConvertTo-Json -Depth 5 | Out-File (Join-Path $rescuePath "startup.json") -Encoding UTF8
    Write-Success "Startup guardado"
    
    # 2. Servicios
    Write-Step 2 "Guardando estado de servicios..."
    Get-Service | Select-Object Name, DisplayName, Status, StartType | 
        Export-Csv (Join-Path $rescuePath "services.csv") -NoTypeInformation
    Write-Success "Servicios guardados"
    
    # 3. Efectos visuales
    Write-Step 3 "Guardando efectos visuales..."
    $visualFx = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ErrorAction SilentlyContinue
    $dwm = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue
    @{
        VisualEffects = $visualFx
        DWM = $dwm
    } | ConvertTo-Json -Depth 3 | Out-File (Join-Path $rescuePath "visual.json") -Encoding UTF8
    Write-Success "Efectos visuales guardados"
    
    # 4. Plan de energía
    Write-Step 4 "Guardando plan de energía..."
    $powerPlan = powercfg /getactivescheme 2>&1
    $powerPlan | Out-File (Join-Path $rescuePath "powerplan.txt") -Encoding UTF8
    Write-Success "Plan de energía guardado"
    
    # 5. Apps instaladas
    Write-Step 5 "Guardando lista de apps instaladas..."
    $apps = Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName, InstallLocation
    $apps | Export-Csv (Join-Path $rescuePath "apps.csv") -NoTypeInformation
    Write-Success "Apps guardadas ($($apps.Count) paquetes)"
    
    # 6. Variables de entorno del sistema
    Write-Step 6 "Guardando configuración del sistema..."
    @{
        PageFile = (Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage)
        Environment = [Environment]::GetEnvironmentVariables("Machine")
    } | ConvertTo-Json -Depth 3 | Out-File (Join-Path $rescuePath "system.json") -Encoding UTF8
    Write-Success "Configuración guardada"
    
    Write-Host ""
    Write-Success "Rescue point creado en: $rescuePath"
    Log "Rescue point completado: $rescueId"
    return $rescuePath
}

function Restore-RescuePoint {
    Write-Header "🔄 RESTAURAR RESCUE POINT"
    
    $rescueDirs = Get-ChildItem $RescueDir -Directory | Sort-Object Name -Descending
    if ($rescueDirs.Count -eq 0) {
        Write-Error "No hay rescue points disponibles."
        return
    }
    
    Write-Host "  Rescue points disponibles:" -ForegroundColor White
    for ($i = 0; $i -lt $rescueDirs.Count; $i++) {
        Write-Host "    [$($i+1)] $($rescueDirs[$i].Name)" -ForegroundColor Cyan
    }
    Write-Host "    [0] Cancelar" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "  Seleccioná un rescue point"
    if ($choice -eq "0" -or $choice -eq "") { return }
    
    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $rescueDirs.Count) {
        Write-Error "Selección inválida."
        return
    }
    
    $selected = $rescueDirs[$idx].FullName
    Write-Host ""
    Write-Warn "Esto va a restaurar la configuración de: $($rescueDirs[$i].Name)"
    $confirm = Read-Host "  ¿Confirmar? (SI para confirmar)"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    
    Log "Restaurando rescue point: $($rescueDirs[$idx].Name)"
    
    # Restaurar servicios
    $servicesFile = Join-Path $selected "services.csv"
    if (Test-Path $servicesFile) {
        Write-Step 1 "Restaurando servicios..."
        $savedServices = Import-Csv $servicesFile
        foreach ($svc in $savedServices) {
            $current = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($current -and $current.StartType -ne $svc.StartType) {
                Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction SilentlyContinue
            }
        }
        Write-Success "Servicios restaurados"
    }
    
    # Restaurar plan de energía
    $powerFile = Join-Path $selected "powerplan.txt"
    if (Test-Path $powerFile) {
        Write-Step 2 "Restaurando plan de energía..."
        $savedPlan = Get-Content $powerFile
        if ($savedPlan -match "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})") {
            powercfg /setactive $Matches[1] 2>&1 | Out-Null
        }
        Write-Success "Plan de energía restaurado"
    }
    
    # Restaurar efectos visuales
    $visualFile = Join-Path $selected "visual.json"
    if (Test-Path $visualFile) {
        Write-Step 3 "Restaurando efectos visuales..."
        $savedVisual = Get-Content $visualFile -Raw | ConvertFrom-Json
        if ($savedVisual.VisualEffects) {
            Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
                -Name "VisualFXSetting" -Value $savedVisual.VisualEffects.VisualFXSetting -ErrorAction SilentlyContinue
        }
        Write-Success "Efectos visuales restaurados"
    }
    
    # Restaurar apps desinstaladas
    $appsFile = Join-Path $selected "apps.csv"
    if (Test-Path $appsFile) {
        Write-Step 4 "Restaurando apps desinstaladas..."
        $savedApps = Import-Csv $appsFile
        $currentApps = Get-AppxPackage -AllUsers | Select-Object -ExpandProperty Name
        $missing = $savedApps | Where-Object { $_.Name -notin $currentApps }
        if ($missing.Count -gt 0) {
            Write-Warn "Se encontraron $($missing.Count) apps que fueron removidas."
            Write-Info "Para restaurar apps de Microsoft Store, ejecutá:"
            Write-Info '  Get-AppxPackage -AllUsers | foreach {Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml"}'
        }
        Write-Success "Verificación de apps completada"
    }
    
    Write-Host ""
    Write-Success "Restauración completada. Se recomienda reiniciar."
    Log "Restauración completada desde: $($rescueDirs[$idx].Name)"
}

# Ejecutar
switch ($Action) {
    "create"  { Create-RescuePoint -Name $Name }
    "restore" { Restore-RescuePoint }
    default   { Create-RescuePoint -Name $Name }
}
