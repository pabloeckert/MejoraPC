@echo off
:: MejoraPC - Launcher
:: Click derecho -> Ejecutar como administrador

echo.
echo  ╔═══════════════════════════════════════════════════════╗
echo  ║                     M E J O R A P C                    ║
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

:: Ejecutar PowerShell
powershell -ExecutionPolicy Bypass -File "%~dp0run.ps1"
pause
