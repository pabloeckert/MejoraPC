@echo off
:: MejoraPC - Setup
:: Instala MejoraPC en esta PC y la deja lista para usar.
:: Doble-click (se auto-eleva a administrador si hace falta).

echo.
echo  ================================================
echo              M E J O R A P C  -  S E T U P
echo  ================================================
echo.

:: Verificar admin, re-lanzar elevado si hace falta.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  Se necesitan permisos de administrador. Elevando...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SRC=%~dp0"
set "DEST=%LOCALAPPDATA%\MejoraPC"

echo  Instalando en: %DEST%
echo.

robocopy "%SRC%." "%DEST%" /E /XD logs backups rescue __pycache__ .git .claude dist installer /XF Setup.bat /NFL /NDL /NJH /NJS >nul

if not exist "%DEST%\run.ps1" (
    echo  [ERROR] La copia fallo. Revisa permisos y volve a intentar.
    pause
    exit /b 1
)

echo  [OK] Archivos copiados.
echo.

set "SHORTCUT_PS=%TEMP%\mejorapc_shortcut.ps1"
> "%SHORTCUT_PS%" echo $s = (New-Object -ComObject WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\MejoraPC.lnk')
>> "%SHORTCUT_PS%" echo $s.TargetPath = 'powershell.exe'
>> "%SHORTCUT_PS%" echo $s.Arguments = '-ExecutionPolicy Bypass -File "%DEST%\run.ps1"'
>> "%SHORTCUT_PS%" echo $s.WorkingDirectory = '%DEST%'
>> "%SHORTCUT_PS%" echo $s.IconLocation = 'shell32.dll,21'
>> "%SHORTCUT_PS%" echo $s.Save()
powershell -NoProfile -ExecutionPolicy Bypass -File "%SHORTCUT_PS%"
del "%SHORTCUT_PS%" >nul 2>&1

echo  [OK] Acceso directo creado en el Escritorio.
echo.
echo  Iniciando MejoraPC por primera vez (descubrimiento + optimizacion)...
echo  Esto va a escanear la PC, hacerte unas preguntas breves, y optimizar.
echo.
timeout /t 3 >nul

powershell -ExecutionPolicy Bypass -File "%DEST%\run.ps1"
pause
