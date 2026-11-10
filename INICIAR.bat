@echo off
:: MejoraPC - Launcher
:: Doble-click o Ejecutar como administrador (se auto-eleva vía UAC si hace falta)
cd /d "%~dp0"

echo.
echo  ╔═══════════════════════════════════════════════════════╗
echo  ║                     M E J O R A P C                    ║
echo  ╚═══════════════════════════════════════════════════════╝
echo.

:: Verificar admin y auto-elevar si hace falta
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] Se requieren permisos de administrador. Solicitando elevacion UAC...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Ejecutar PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
pause
