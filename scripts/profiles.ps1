# ============================================================
# PROFILES - Guardar/cargar perfiles de optimización
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

param(
    [ValidateSet("save", "load", "list", "delete")]
    [string]$Action = "list",
    [string]$Name = ""
)

$ProfilesDir = Join-Path $ScriptRoot "profiles"

if (!(Test-Path $ProfilesDir)) {
    New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
}

# ============================================================
# CAPTURAR ESTADO ACTUAL
# ============================================================
function Get-CurrentProfile {
    $profile = @{}
    
    # Servicios
    $services = Get-Service | Select-Object Name, Status, StartType
    $profile.Services = $services | ForEach-Object {
        @{ Name = $_.Name; Status = $_.Status.ToString(); StartType = $_.StartType.ToString() }
    }
    
    # Efectos visuales
    $visualFx = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ErrorAction SilentlyContinue
    $personalize = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
    $dwm = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -ErrorAction SilentlyContinue
    $profile.VisualEffects = @{
        VisualFXSetting = $visualFx.VisualFXSetting
        EnableTransparency = $personalize.EnableTransparency
        EnableAeroPeek = $dwm.EnableAeroPeek
    }
    
    # Background apps
    $bgApps = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -ErrorAction SilentlyContinue
    $profile.BackgroundApps = @{
        GlobalUserDisabled = $bgApps.GlobalUserDisabled
    }
    
    # Telemetría
    $telemetry = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue
    $profile.Telemetry = @{
        AllowTelemetry = $telemetry.AllowTelemetry
    }
    
    # Plan de energía
    $powerPlan = powercfg /getactivescheme 2>&1
    if ($powerPlan -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
        $profile.PowerPlan = $Matches[1]
    }
    
    # Startup
    $startupItems = @()
    $regRun = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
    if ($regRun) {
        $regRun.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
            $startupItems += @{ Name = $_.Name; Value = $_.Value; Source = "HKCU" }
        }
    }
    $profile.Startup = $startupItems
    
    # Timestamp
    $profile.Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $profile.DriveType = if ($Global:IsSSD) { "SSD" } else { "HDD" }
    
    return $profile
}

# ============================================================
# APLICAR PERFIL
# ============================================================
function Apply-Profile {
    param($profile)
    
    $applied = 0
    $errors = 0
    
    # 1. Servicios
    Write-Step 1 "Restaurando servicios..."
    $svcApplied = 0
    foreach ($svc in $profile.Services) {
        try {
            $current = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($current) {
                if ($current.StartType.ToString() -ne $svc.StartType) {
                    Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction SilentlyContinue
                }
                if ($svc.Status -eq "Running" -and $current.Status -ne "Running") {
                    Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
                }
                $svcApplied++
            }
        } catch {}
    }
    Write-Success "$svcApplied servicios restaurados"
    $applied++
    
    # 2. Efectos visuales
    Write-Step 2 "Restaurando efectos visuales..."
    try {
        if ($null -ne $profile.VisualEffects.VisualFXSetting) {
            Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
                -Name "VisualFXSetting" -Value $profile.VisualEffects.VisualFXSetting
        }
        if ($null -ne $profile.VisualEffects.EnableTransparency) {
            Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
                -Name "EnableTransparency" -Value $profile.VisualEffects.EnableTransparency
        }
        if ($null -ne $profile.VisualEffects.EnableAeroPeek) {
            Set-RegProperty "HKCU:\Software\Microsoft\Windows\DWM" `
                -Name "EnableAeroPeek" -Value $profile.VisualEffects.EnableAeroPeek
        }
        Write-Success "Efectos visuales restaurados"
        $applied++
    } catch {
        Write-Error "Error al restaurar efectos visuales: $_"
        $errors++
    }
    
    # 3. Background apps
    Write-Step 3 "Restaurando background apps..."
    try {
        if ($null -ne $profile.BackgroundApps.GlobalUserDisabled) {
            if ($profile.BackgroundApps.GlobalUserDisabled -eq 1) {
                Set-RegProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
                    -Name "GlobalUserDisabled" -Value 1
            } else {
                Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
                    -Name "GlobalUserDisabled" -ErrorAction SilentlyContinue
            }
        }
        Write-Success "Background apps restauradas"
        $applied++
    } catch {
        Write-Error "Error al restaurar background apps: $_"
        $errors++
    }
    
    # 4. Telemetría
    Write-Step 4 "Restaurando telemetría..."
    try {
        if ($null -ne $profile.Telemetry.AllowTelemetry) {
            $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-RegProperty $path -Name "AllowTelemetry" -Value $profile.Telemetry.AllowTelemetry
        }
        Write-Success "Telemetría restaurada"
        $applied++
    } catch {
        Write-Error "Error al restaurar telemetría: $_"
        $errors++
    }
    
    # 5. Plan de energía
    Write-Step 5 "Restaurando plan de energía..."
    try {
        if ($profile.PowerPlan) {
            powercfg /setactive $profile.PowerPlan 2>&1 | Out-Null
        }
        Write-Success "Plan de energía restaurado"
        $applied++
    } catch {
        Write-Error "Error al restaurar plan: $_"
        $errors++
    }
    
    Write-Host ""
    Write-Success "Perfil aplicado: $applied pasos, $errors errores"
}

# ============================================================
# ACCIONES
# ============================================================

switch ($Action) {
    "save" {
        if (!$Name) {
            Write-Host ""
            $Name = Read-Host "  Nombre del perfil"
        }
        if (!$Name) {
            Write-Error "Nombre requerido."
            exit 1
        }
        
        # Sanitizar nombre
        $safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
        $profileFile = Join-Path $ProfilesDir "$safeName.json"
        
        Write-Header "💾 GUARDANDO PERFIL: $safeName"
        
        $profile = Get-CurrentProfile
        $profile.Name = $Name
        $profile | ConvertTo-Json -Depth 10 | Out-File $profileFile -Encoding UTF8
        
        Write-Success "Perfil guardado en: $profileFile"
        Write-Info "Servicios guardados: $($profile.Services.Count)"
        Write-Info "Startup items: $($profile.Startup.Count)"
        Write-Info "Plan de energía: $($profile.PowerPlan)"
        Log "Perfil guardado: $safeName"
    }
    
    "load" {
        $profiles = Get-ChildItem $ProfilesDir -Filter "*.json" -ErrorAction SilentlyContinue
        if ($profiles.Count -eq 0) {
            Write-Error "No hay perfiles guardados."
            exit 0
        }
        
        if ($Name) {
            $safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
            $profileFile = Join-Path $ProfilesDir "$safeName.json"
            if (!(Test-Path $profileFile)) {
                Write-Error "Perfil '$Name' no encontrado."
                exit 1
            }
        } else {
            Write-Header "📂 CARGAR PERFIL"
            Write-Host "  Perfiles disponibles:" -ForegroundColor White
            Write-Host ""
            for ($i = 0; $i -lt $profiles.Count; $i++) {
                $p = Get-Content $profiles[$i].FullName -Raw | ConvertFrom-Json
                Write-Host "    [$($i+1)] $($p.Name) — $($p.Timestamp)" -ForegroundColor Cyan
            }
            Write-Host "    [0] Cancelar" -ForegroundColor Red
            Write-Host ""
            $choice = Read-Host "  Seleccioná un perfil"
            if ($choice -eq "0" -or $choice -eq "") { exit 0 }
            
            $idx = [int]$choice - 1
            if ($idx -lt 0 -or $idx -ge $profiles.Count) {
                Write-Error "Selección inválida."
                exit 1
            }
            $profileFile = $profiles[$idx].FullName
        }
        
        $profile = Get-Content $profileFile -Raw | ConvertFrom-Json
        
        Write-Header "📂 CARGANDO PERFIL: $($profile.Name)"
        Write-Info "Guardado: $($profile.Timestamp)"
        Write-Info "Servicios: $($profile.Services.Count)"
        Write-Host ""
        
        $confirm = Read-Host "  Escribí SI para confirmar"
        if ($confirm -ne "SI") {
            Write-Info "Cancelado."
            exit 0
        }
        
        # Rescue point antes
        & "$ScriptsDir\rescue.ps1" -Action create -Name "pre-profile-$($profile.Name)"
        Write-Host ""
        
        Apply-Profile -profile $profile
        
        Write-Host ""
        Write-Info "Se recomienda reiniciar para aplicar todos los cambios."
        Log "Perfil cargado: $($profile.Name)"
    }
    
    "list" {
        Write-Header "📋 PERFILES GUARDADOS"
        
        $profiles = Get-ChildItem $ProfilesDir -Filter "*.json" -ErrorAction SilentlyContinue
        if ($profiles.Count -eq 0) {
            Write-Info "No hay perfiles guardados."
            Write-Host ""
            Write-Info "Para guardar un perfil actual: .\profiles.ps1 -Action save -Name 'mi-perfil'"
            exit 0
        }
        
        foreach ($profileFile in $profiles) {
            $p = Get-Content $profileFile.FullName -Raw | ConvertFrom-Json
            Write-Host "  📁 $($p.Name)" -ForegroundColor Cyan
            Write-Host "     Guardado: $($p.Timestamp)" -ForegroundColor Gray
            Write-Host "     Servicios: $($($p.Services).Count) | Startup: $($($p.Startup).Count) | Disco: $($p.DriveType)" -ForegroundColor Gray
            Write-Host "     Plan: $($p.PowerPlan)" -ForegroundColor Gray
            Write-Host "     Archivo: $($profileFile.Name)" -ForegroundColor DarkGray
            Write-Host ""
        }
        
        Write-Info "Cargar: .\profiles.ps1 -Action load"
        Write-Info "Guardar: .\profiles.ps1 -Action save -Name 'nombre'"
    }
    
    "delete" {
        $profiles = Get-ChildItem $ProfilesDir -Filter "*.json" -ErrorAction SilentlyContinue
        if ($profiles.Count -eq 0) {
            Write-Info "No hay perfiles para eliminar."
            exit 0
        }
        
        Write-Header "🗑️ ELIMINAR PERFIL"
        for ($i = 0; $i -lt $profiles.Count; $i++) {
            $p = Get-Content $profiles[$i].FullName -Raw | ConvertFrom-Json
            Write-Host "    [$($i+1)] $($p.Name)" -ForegroundColor Cyan
        }
        Write-Host "    [0] Cancelar" -ForegroundColor Red
        Write-Host ""
        $choice = Read-Host "  Seleccioná perfil a eliminar"
        if ($choice -eq "0" -or $choice -eq "") { exit 0 }
        
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $profiles.Count) {
            Write-Error "Selección inválida."
            exit 1
        }
        
        $confirm = Read-Host "  ¿Eliminar '$($profiles[$idx].BaseName)'? SI para confirmar"
        if ($confirm -ne "SI") {
            Write-Info "Cancelado."
            exit 0
        }
        
        Remove-Item $profiles[$idx].FullName -Force
        Write-Success "Perfil eliminado."
        Log "Perfil eliminado: $($profiles[$idx].BaseName)"
    }
}
