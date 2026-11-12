@echo off
:: MejoraPC - Optimizador Inteligente 1-Click
:: Ejecuta Limpieza de Disco, Windows DISM, Antivirus, Antirobo y Optimizacion
cd /d "%~dp0"

echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║         M E J O R A P C  —  O P T I M I Z A C I O N       ║
echo  ║                     1 - C L I C K                         ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.

:: Verificar admin y auto-elevar si hace falta
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] Se requieren permisos de administrador. Solicitando elevacion UAC...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo  [1/4] Ejecutando Mantenimiento Inteligente, Limpieza y Antirobo...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0modules\17-smart-maintenance.ps1" -Auto

echo.
echo  [2/4] Aplicando Optimizaciones de Kernel y Rendimiento...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0modules\03-performance.ps1" -Auto

echo.
echo  [3/4] Actualizando Telemetria y Estado de Hardware...
py "%~dp0monitor\scan.py" 2>nul || python "%~dp0monitor\scan.py"

echo.
echo  [4/4] Generando Informe Visual y Dashboard...
py "%~dp0monitor\html_report.py" 2>nul || python "%~dp0monitor\html_report.py"

echo.
echo  ===============================================================
echo   [OK] OPTIMIZACION 1-CLICK COMPLETADA CON EXITO.
echo  ===============================================================
echo.
pause
