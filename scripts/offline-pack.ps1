# ============================================================
# OFFLINE PACK - Exportar todo para uso sin internet
# ============================================================
# Crea un paquete completo que funciona sin conexión a GitHub.
# Incluye todos los scripts, docs y un instalador local.
# ============================================================

param(
    [ValidateSet("export", "import")]
    [string]$Action = "export"
)

. "$PSScriptRoot\config.ps1"

$ExportDir = Join-Path $ScriptRoot "offline-pack"

function Export-OfflinePack {
    Write-Header "📦 CREANDO PAQUETE OFFLINE"
    Write-Host ""
    Write-Host "  Esto va a crear un paquete completo que funciona" -ForegroundColor White
    Write-Host "  sin conexión a internet." -ForegroundColor White
    Write-Host ""
    
    # Crear directorio de exportación
    if (Test-Path $ExportDir) {
        Remove-Item $ExportDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
    
    # 1. Copiar scripts
    Write-Step 1 "Copiando scripts..."
    $scriptsDest = Join-Path $ExportDir "scripts"
    New-Item -ItemType Directory -Path $scriptsDest -Force | Out-Null
    Copy-Item (Join-Path $ScriptRoot "scripts\*.ps1") $scriptsDest -Force
    Write-Success "$(( Get-ChildItem $scriptsDest -Filter '*.ps1').Count) scripts copiados"
    
    # 2. Copiar docs
    Write-Step 2 "Copiando documentación..."
    Copy-Item (Join-Path $ScriptRoot "*.md") $ExportDir -Force
    Copy-Item (Join-Path $ScriptRoot "*.bat") $ExportDir -Force
    Copy-Item (Join-Path $ScriptRoot "*.ps1") $ExportDir -Force -ErrorAction SilentlyContinue
    Write-Success "Documentación copiada"
    
    # 3. Crear instalador local
    Write-Step 3 "Creando instalador local..."
    $installer = @"
@echo off
:: ============================================================
:: INSTALADOR OFFLINE - MejoraNotebook
:: ============================================================
:: Ejecutar como administrador: click derecho -> Ejecutar como administrador
:: ============================================================

echo.
echo  ╔═══════════════════════════════════════════════════════╗
echo  ║           INSTALADOR OFFLINE - MejoraNotebook        ║
echo  ╚═══════════════════════════════════════════════════════╝
echo.

:: Verificar admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  ⚠️  Se requieren permisos de administrador.
    echo  Click derecho en este archivo -^> "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

:: Verificar PowerShell
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo  ❌ PowerShell no encontrado.
    echo  Windows 10/11 incluye PowerShell por defecto.
    pause
    exit /b 1
)

echo  ✅ PowerShell encontrado
echo.
echo  Instalando MejoraNotebook...
echo.

:: Crear directorio de instalación
set "INSTALL_DIR=%USERPROFILE%\MejoraNotebook"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copiar archivos
xcopy /E /Y /I "%~dp0scripts" "%INSTALL_DIR%\scripts" >nul
xcopy /E /Y /I "%~dp0*.md" "%INSTALL_DIR%" >nul
copy /Y "%~dp0win-optimizer.ps1" "%INSTALL_DIR%" >nul
copy /Y "%~dp0INICIAR.bat" "%INSTALL_DIR%" >nul
copy /Y "%~dp0push.sh" "%INSTALL_DIR%" >nul 2>nul

echo  ✅ Archivos instalados en: %INSTALL_DIR%
echo.
echo  Para ejecutar:
echo    Click derecho en %INSTALL_DIR%\INICIAR.bat
echo    ^> "Ejecutar como administrador"
echo.
echo  ¡Listo! Presioná cualquier tecla para abrir la carpeta.
pause >nul
explorer "%INSTALL_DIR%"
"@
    $installerPath = Join-Path $ExportDir "INSTALAR_OFFLINE.bat"
    $installer | Out-File $installerPath -Encoding ASCII
    Write-Success "Instalador local creado"
    
    # 4. Crear README offline
    Write-Step 4 "Creando instrucciones..."
    $readmeOffline = @"
# 📦 MejoraNotebook — Modo Offline

## Instalación

1. Copiá esta carpeta a la PC que querés optimizar
2. Click derecho en `INSTALAR_OFFLINE.bat` → **Ejecutar como administrador**
3. Seguí las instrucciones en pantalla

## Ejecución

1. Abrí la carpeta de instalación
2. Click derecho en `INICIAR.bat` → **Ejecutar como administrador**

## Incluye

- Todos los scripts de optimización
- Documentación completa (README, TUTORIAL, MANUAL)
- Wizard guiado para principiantes
- Sin necesidad de conexión a internet

## Versión

Paquete generado: $(Get-Date -Format "yyyy-MM-dd HH:mm")
Versión: v1.7.0

## Soporte

https://github.com/pabloeckert/MejoraNotebook
"@
    $readmePath = Join-Path $ExportDir "LEEME_OFFLINE.md"
    $readmeOffline | Out-File $readmePath -Encoding UTF8
    Write-Success "Instrucciones creadas"
    
    # 5. Calcular tamaño
    Write-Step 5 "Calculando tamaño..."
    $totalSize = (Get-ChildItem $ExportDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($totalSize / 1MB, 2)
    $fileCount = (Get-ChildItem $ExportDir -Recurse -File | Measure-Object).Count
    Write-Success "Tamaño: $sizeMB MB ($fileCount archivos)"
    
    Write-Host ""
    Write-Header "✅ PAQUETE OFFLINE CREADO"
    Write-Host "  📁 Carpeta: $ExportDir" -ForegroundColor White
    Write-Host "  📦 Tamaño:  $sizeMB MB" -ForegroundColor White
    Write-Host "  📄 Archivos: $fileCount" -ForegroundColor White
    Write-Host ""
    Write-Info "Copiá la carpeta '$ExportDir' a un USB y llevála a la PC sin internet."
    Write-Info "Ejecutá 'INSTALAR_OFFLINE.bat' como administrador en la PC destino."
    
    Log "Paquete offline creado: $sizeMB MB, $fileCount archivos"
}

function Import-OfflinePack {
    Write-Header "📥 IMPORTAR PAQUETE OFFLINE"
    
    # Buscar paquete en el directorio actual o pedir ruta
    if (Test-Path (Join-Path $ScriptRoot "offline-pack")) {
        $packPath = Join-Path $ScriptRoot "offline-pack"
    } else {
        Write-Host "  Ruta del paquete offline:" -ForegroundColor White
        $packPath = Read-Host "  Ruta"
        if (!$packPath -or !(Test-Path $packPath)) {
            Write-Error "Ruta inválida o paquete no encontrado."
            return
        }
    }
    
    Write-Host "  Paquete encontrado: $packPath" -ForegroundColor Green
    Write-Host ""
    
    # Copiar scripts
    Write-Step 1 "Importando scripts..."
    $srcScripts = Join-Path $packPath "scripts"
    if (Test-Path $srcScripts) {
        Copy-Item "$srcScripts\*" (Join-Path $ScriptRoot "scripts") -Force -Recurse
        Write-Success "Scripts importados"
    }
    
    # Copiar docs
    Write-Step 2 "Importando documentación..."
    Copy-Item (Join-Path $packPath "*.md") $ScriptRoot -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $packPath "*.ps1") $ScriptRoot -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $packPath "*.bat") $ScriptRoot -Force -ErrorAction SilentlyContinue
    Write-Success "Documentación importada"
    
    Write-Host ""
    Write-Header "✅ IMPORTACIÓN COMPLETADA"
    Write-Success "MejoraNotebook actualizado desde paquete offline."
    Write-Info "Ejecutá 'INICIAR.bat' para usar."
}

# ============================================================
# MAIN
# ============================================================
switch ($Action) {
    "export" { Export-OfflinePack }
    "import" { Import-OfflinePack }
}
