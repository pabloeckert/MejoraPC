@echo off
:: MejoraPC - Optimización Extrema de Kernel, Servicios y MSI
:: Click derecho -> "Ejecutar como administrador"
title MejoraPC - Optimizacion de Kernel, Servicios y MSI
cd /d "%~dp0"

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  =============================================================
    echo    Se requieren permisos de Administrador.
    echo    Solicitando elevacion UAC...
    echo  =============================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo.
echo  =============================================================
echo    Ejecutando Optimizacion Extrema de Kernel y Servicios...
echo  =============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0modules\20-kernel-performance.ps1" -Elevated -Auto
echo.
echo  Optimizacion completada. Presiona cualquier tecla para cerrar.
pause >nul
