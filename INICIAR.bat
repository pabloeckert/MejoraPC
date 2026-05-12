@echo off
:: Win Optimizer v3.0.0 - Launcher
:: Click derecho -> Ejecutar como administrador

echo.
echo  ╔═══════════════════════════════════════════════════════╗
echo  ║                                                       ║
echo  ║   ██╗   ██╗██╗███╗   ██╗     ██████╗ ██████╗████████╗║
echo  ║   ██║   ██║██║████╗  ██║    ██╔════╝██╔══██╚══██╔══╝║
echo  ║   ██║   ██║██║██╔██╗ ██║    ██║     ██████╔╝  ██║   ║
echo  ║   ╚██╗ ██╔╝██║██║╚██╗██║    ██║     ██╔══██╗  ██║   ║
echo  ║    ╚████╔╝ ██║██║ ╚████║    ╚██████╗██║  ██║  ██║   ║
echo  ║     ╚═══╝  ╚═╝╚═╝  ╚═══╝     ╚═════╝╚═╝  ╚═╝  ╚═╝   ║
echo  ║                                                       ║
echo  ║          O P T I M I Z E R   v3.0.0                  ║
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
powershell -ExecutionPolicy Bypass -File "%~dp0win-optimizer.ps1"
pause
