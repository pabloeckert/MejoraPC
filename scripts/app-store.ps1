# ============================================================
# APP STORE - Reinstalar apps desinstaladas por Debloater
# ============================================================
# Muestra apps que fueron desinstaladas y permite reinstalarlas
# desde Microsoft Store o winget.
# ============================================================

param(
    [ValidateSet("list", "reinstall", "search")]
    [string]$Action = "list",
    [string]$AppName = ""
)

. "$PSScriptRoot\config.ps1"
Assert-Admin

# Usar listas centralizadas de config.ps1
$DebloaterApps = $Global:BloatwareApps
$AppDescriptions = $Global:AppDescriptions

function Get-FriendlyName {
    param([string]$PackageId)
    if ($AppDescriptions.ContainsKey($PackageId)) {
        return $AppDescriptions[$PackageId]
    }
    return $PackageId
}

# ============================================================
# LISTAR APPS DESINSTALADAS
# ============================================================
function List-Apps {
    Write-Header "📋 APPS DISPONIBLES PARA REINSTALAR"
    
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $missing = $DebloaterApps | Where-Object { $_ -notin $installed }
    
    if ($missing.Count -eq 0) {
        Write-Success "Todas las apps del listado están instaladas."
        return
    }
    
    Write-Host "  Apps que fueron desinstaladas:" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $missing.Count; $i++) {
        $name = Get-FriendlyName $missing[$i]
        Write-Host "    [$($i+1)] $name" -ForegroundColor Cyan
        Write-Host "        $($missing[$i])" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "  Total: $($missing.Count) apps desinstaladas" -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Para reinstalar: .\app-store.ps1 -Action reinstall"
    Write-Info "Para buscar: .\app-store.ps1 -Action search -Name 'spotify'"
}

# ============================================================
# REINSTALAR APPS
# ============================================================
function Reinstall-Apps {
    Write-Header "📥 REINSTALAR APPS"
    
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $missing = $DebloaterApps | Where-Object { $_ -notin $installed }
    
    if ($missing.Count -eq 0) {
        Write-Success "Todas las apps están instaladas."
        return
    }
    
    Write-Host "  Apps disponibles para reinstalar:" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $missing.Count; $i++) {
        $name = Get-FriendlyName $missing[$i]
        Write-Host "    [$($i+1)] $name" -ForegroundColor Cyan
    }
    Write-Host "    [A] Reinstalar TODAS" -ForegroundColor Green
    Write-Host "    [0] Cancelar" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "  Seleccioná apps (números separados por coma, o A para todas)"
    
    if ($choice -eq "0") {
        Write-Info "Cancelado."
        return
    }
    
    $toReinstall = @()
    if ($choice -eq "A" -or $choice -eq "a") {
        $toReinstall = $missing
    } else {
        $indices = $choice -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
        foreach ($idx in $indices) {
            if ($idx -ge 0 -and $idx -lt $missing.Count) {
                $toReinstall += $missing[$idx]
            }
        }
    }
    
    if ($toReinstall.Count -eq 0) {
        Write-Error "Selección inválida."
        return
    }
    
    Write-Host ""
    Write-Warn "Se van a reinstalar $($toReinstall.Count) apps."
    $confirm = Read-Host "  ¿Confirmar? (SI para confirmar)"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    
    Write-Host ""
    $reinstalled = 0
    $failed = 0
    
    # Intentar con winget primero (más confiable)
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    
    foreach ($pkg in $toReinstall) {
        $name = Get-FriendlyName $pkg
        Write-Host "  Instalando: $name... " -NoNewline
        
        try {
            if ($hasWinget) {
                # Buscar en winget
                $wingetId = $pkg -replace 'Microsoft\.', '' -replace '\..*', ''
                $result = winget install --id $pkg --accept-source-agreements --accept-package-agreements 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅" -ForegroundColor Green
                    $reinstalled++
                } else {
                    # Fallback: Microsoft Store
                    Start-Process "ms-windows-store://pdp/?productid=$pkg"
                    Write-Host "📦 (abriendo Store)" -ForegroundColor Yellow
                    $reinstalled++
                }
            } else {
                # Sin winget: abrir Microsoft Store
                Start-Process "ms-windows-store://pdp/?productid=$pkg"
                Write-Host "📦 (abriendo Store)" -ForegroundColor Yellow
                $reinstalled++
            }
        } catch {
            Write-Host "❌" -ForegroundColor Red
            $failed++
            Log "Error al reinstalar $pkg : $_"
        }
    }
    
    Write-Host ""
    Write-Success "Reinstaladas: $reinstalled"
    if ($failed -gt 0) { Write-Warn "Errores: $failed" }
    Write-Info "Algunas apps pueden necesitar reinicio para aparecer."
    
    Log "App store: $reinstalled reinstaladas, $failed errores"
}

# ============================================================
# BUSCAR APPS
# ============================================================
function Search-Apps {
    if (!$AppName) {
        $AppName = Read-Host "  ¿Qué app buscás?"
    }
    
    Write-Header "🔍 BUSCANDO: $AppName"
    
    # Buscar en el listado local
    $found = $DebloaterApps | Where-Object { $_ -match $AppName -or (Get-FriendlyName $_) -match $AppName }
    
    if ($found.Count -gt 0) {
        Write-Host "  Encontradas en el listado:" -ForegroundColor Green
        foreach ($f in $found) {
            $name = Get-FriendlyName $f
            $isInstalled = Get-AppxPackage -Name $f -AllUsers -ErrorAction SilentlyContinue
            $status = if ($isInstalled) { "✅ Instalada" } else { "❌ Desinstalada" }
            $statusColor = if ($isInstalled) { "Green" } else { "Red" }
            Write-Host "    $name" -ForegroundColor White
            Write-Host "      $f — $status" -ForegroundColor $statusColor
        }
    } else {
        Write-Info "No se encontró '$AppName' en el listado de apps conocidas."
    }
    
    # Buscar en winget si está disponible
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if ($hasWinget) {
        Write-Host ""
        Write-Host "  Buscando en winget..." -ForegroundColor Gray
        $wingetResults = winget search "$AppName" --accept-source-agreements 2>&1
        if ($wingetResults) {
            Write-Host "  Resultados de winget:" -ForegroundColor Cyan
            $wingetResults | Select-Object -First 10 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
    }
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "list"       { List-Apps }
    "reinstall"  { Reinstall-Apps }
    "search"     { Search-Apps }
}
