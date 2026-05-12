# ============================================================
# UPDATER - Auto-actualizar MejoraNotebook desde GitHub
# ============================================================
# Verifica si hay nuevas versiones en GitHub y actualiza
# el programa automáticamente. Rescata configuración.
# ============================================================

param(
    [ValidateSet("check", "update", "status")]
    [string]$Action = "check"
)

. "$PSScriptRoot\config.ps1"

$RepoUrl = "https://github.com/pabloeckert/MejoraNotebook"
$RawUrl = "https://raw.githubusercontent.com/pabloeckert/MejoraNotebook/main"

function Get-LocalVersion {
    $readme = Get-Content (Join-Path $ScriptRoot "README.md") -Raw -ErrorAction SilentlyContinue
    if ($readme -match 'v(\d+\.\d+\.\d+)') {
        return $Matches[1]
    }
    return "0.0.0"
}

function Get-RemoteVersion {
    try {
        $readmeContent = (Invoke-WebRequest -Uri "$RawUrl/README.md" -UseBasicParsing -TimeoutSec 10).Content
        if ($readmeContent -match 'v(\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Compare-Versions {
    param([string]$Local, [string]$Remote)
    $localParts = $Local -split '\.' | ForEach-Object { [int]$_ }
    $remoteParts = $Remote -split '\.' | ForEach-Object { [int]$_ }
    
    for ($i = 0; $i -lt 3; $i++) {
        if ($remoteParts[$i] -gt $localParts[$i]) { return "newer" }
        if ($remoteParts[$i] -lt $localParts[$i]) { return "older" }
    }
    return "same"
}

# ============================================================
# CHECK
# ============================================================
function Check-Update {
    Write-Header "🔍 VERIFICANDO ACTUALIZACIONES"
    
    $localVer = Get-LocalVersion
    Write-Host "  Versión local:    v$localVer" -ForegroundColor White
    
    Write-Host "  Consultando GitHub..." -ForegroundColor Gray
    $remoteVer = Get-RemoteVersion
    
    if (!$remoteVer) {
        Write-Error "No se pudo conectar a GitHub."
        Write-Info "Verificá tu conexión a internet."
        return
    }
    
    Write-Host "  Versión remota:   v$remoteVer" -ForegroundColor White
    Write-Host ""
    
    $comparison = Compare-Versions -Local $localVer -Remote $remoteVer
    
    switch ($comparison) {
        "newer" {
            Write-Host "  📥 ¡HAY UNA ACTUALIZACIÓN DISPONIBLE!" -ForegroundColor Green
            Write-Host ""
            Write-Host "    Local:  v$localVer" -ForegroundColor Yellow
            Write-Host "    Nueva:  v$remoteVer" -ForegroundColor Green
            Write-Host ""
            Write-Info "Para actualizar: .\updater.ps1 -Action update"
        }
        "same" {
            Write-Success "Ya tenés la última versión (v$localVer)"
        }
        "older" {
            Write-Info "Tu versión (v$localVer) es más reciente que GitHub (v$remoteVer)"
            Write-Info "¿Estás en una rama de desarrollo?"
        }
    }
}

# ============================================================
# UPDATE
# ============================================================
function Update-Program {
    Write-Header "📥 ACTUALIZANDO MEJORANOTEBOOK"
    
    $localVer = Get-LocalVersion
    $remoteVer = Get-RemoteVersion
    
    if (!$remoteVer) {
        Write-Error "No se pudo conectar a GitHub."
        return
    }
    
    $comparison = Compare-Versions -Local $localVer -Remote $remoteVer
    
    if ($comparison -ne "newer") {
        Write-Success "Ya tenés la última versión (v$localVer). No hay nada que actualizar."
        return
    }
    
    Write-Host "  Versión actual: v$localVer" -ForegroundColor Yellow
    Write-Host "  Nueva versión:  v$remoteVer" -ForegroundColor Green
    Write-Host ""
    Write-Warn "Esto va a actualizar todos los scripts."
    Write-Info "Tu configuración (logs, rescue points, perfiles) NO se toca."
    Write-Host ""
    $confirm = Read-Host "  ¿Actualizar? (SI para confirmar)"
    if ($confirm -ne "SI") {
        Write-Info "Cancelado."
        return
    }
    
    Write-Host ""
    Write-Step 1 "Descargando archivos..."
    
    # Crear directorio temporal
    $tempDir = Join-Path $env:TEMP "mejoranotebook_update_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Descargar ZIP del repo
        $zipUrl = "https://github.com/pabloeckert/MejoraNotebook/archive/refs/heads/main.zip"
        $zipFile = Join-Path $tempDir "update.zip"
        
        if (!$Global:DryRun) {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 60
            Write-Success "ZIP descargado"
            
            # Extraer
            Write-Step 2 "Extrayendo archivos..."
            Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
            $extractedDir = Join-Path $tempDir "MejoraNotebook-main"
            Write-Success "Archivos extraídos"
        } else {
            Write-Info "[DRY-RUN] Descargando de: $zipUrl"
        }
        
        # Backup de archivos actuales
        Write-Step 3 "Creando backup..."
        $backupDir = Join-Path $ScriptRoot "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if (!$Global:DryRun) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            # Backup solo scripts y docs (no logs, rescue, profiles)
            Copy-Item (Join-Path $ScriptRoot "*.ps1") $backupDir -ErrorAction SilentlyContinue
            Copy-Item (Join-Path $ScriptRoot "*.md") $backupDir -ErrorAction SilentlyContinue
            Copy-Item (Join-Path $ScriptRoot "*.bat") $backupDir -ErrorAction SilentlyContinue
            Copy-Item (Join-Path $ScriptRoot "scripts") (Join-Path $backupDir "scripts") -Recurse -ErrorAction SilentlyContinue
            Write-Success "Backup creado: $backupDir"
        }
        
        # Actualizar archivos
        Write-Step 4 "Actualizando archivos..."
        if (!$Global:DryRun) {
            # Copiar scripts
            Copy-Item (Join-Path $extractedDir "scripts\*") (Join-Path $ScriptRoot "scripts") -Force -Recurse
            # Copiar docs
            Copy-Item (Join-Path $extractedDir "*.md") $ScriptRoot -Force
            Copy-Item (Join-Path $extractedDir "*.bat") $ScriptRoot -Force
            Copy-Item (Join-Path $extractedDir "*.ps1") $ScriptRoot -Force
            Copy-Item (Join-Path $extractedDir "push.sh") $ScriptRoot -Force -ErrorAction SilentlyContinue
            Write-Success "Archivos actualizados"
        }
        
        # Verificar
        Write-Step 5 "Verificando..."
        $newVer = Get-LocalVersion
        if (!$Global:DryRun) {
            if ($newVer -eq $remoteVer) {
                Write-Success "Actualización verificada: v$newVer"
            } else {
                Write-Warn "Versión después de actualizar: v$newVer (esperado: v$remoteVer)"
            }
        }
        
        # Limpiar
        Write-Step 6 "Limpiando..."
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Limpieza completada"
        
        Write-Host ""
        Write-Header "✅ ACTUALIZACIÓN COMPLETADA"
        Write-Host "  De: v$localVer" -ForegroundColor Yellow
        Write-Host "  A:  v$newVer" -ForegroundColor Green
        Write-Host ""
        Write-Info "Backup guardado en: $backupDir"
        Write-Info "Podés eliminar el backup si todo funciona bien."
        Write-Host ""
        Write-Info "Reiniciá el script para usar la nueva versión."
        
        Log "Actualización completada: v$localVer → v$newVer"
        
    } catch {
        Write-Error "Error durante la actualización: $_"
        Write-Info "El backup está en: $backupDir"
        Write-Info "Podés restaurar manualmente si es necesario."
        Log "Error en actualización: $_"
    }
}

# ============================================================
# STATUS
# ============================================================
function Show-UpdaterStatus {
    Write-Header "📊 UPDATER STATUS"
    
    $localVer = Get-LocalVersion
    Write-Host "  Versión local: v$localVer" -ForegroundColor White
    Write-Host "  Repo: $RepoUrl" -ForegroundColor Gray
    
    # Verificar si hay backup
    $backups = Get-ChildItem $ScriptRoot -Directory -Filter "backup_*" -ErrorAction SilentlyContinue
    if ($backups.Count -gt 0) {
        Write-Host ""
        Write-Host "  Backups encontrados: $($backups.Count)" -ForegroundColor Yellow
        foreach ($b in $backups) {
            Write-Host "    • $($b.Name)" -ForegroundColor Gray
        }
        Write-Info "Podés eliminar backups antiguos para liberar espacio."
    }
    
    Write-Host ""
    Write-Info "Verificar updates: .\updater.ps1 -Action check"
    Write-Info "Actualizar: .\updater.ps1 -Action update"
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "check"   { Check-Update }
    "update"  { Update-Program }
    "status"  { Show-UpdaterStatus }
}
