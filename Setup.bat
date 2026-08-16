@echo off
:: MejoraPC - Setup
:: Instala MejoraPC en esta PC y la deja lista para usar.
:: Doble-click (se auto-eleva a administrador si hace falta).
::
:: Deja un log de sus propios pasos (setup-log.txt, misma carpeta que este
:: .bat) INDEPENDIENTE del diagnostico de run.ps1 -- si algo falla ANTES de
:: llegar a lanzar run.ps1 (elevacion denegada, robocopy, politica de
:: ejecucion), este log es lo unico que va a quedar registrado.

set "SETUPLOG=%~dp0setup-log.txt"
echo [%date% %time%] Setup.bat iniciado > "%SETUPLOG%"

echo.
echo  ================================================
echo              M E J O R A P C  -  S E T U P
echo  ================================================
echo.

:: Verificar admin, re-lanzar elevado si hace falta.
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [%date% %time%] No es admin todavia -- relanzando elevado >> "%SETUPLOG%"
    echo  Se necesitan permisos de administrador. Elevando...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    echo [%date% %time%] Ventana original: exit /b tras disparar la elevacion >> "%SETUPLOG%"
    exit /b
)

echo [%date% %time%] Corriendo como administrador -- OK >> "%SETUPLOG%"

set "SRC=%~dp0"
set "DEST=%LOCALAPPDATA%\MejoraPC"

echo  Instalando en: %DEST%
echo.

robocopy "%SRC%." "%DEST%" /E /XD logs backups rescue __pycache__ .git .claude dist installer /XF Setup.bat setup-log.txt /NFL /NDL /NJH /NJS >nul
echo [%date% %time%] robocopy codigo de salida: %ERRORLEVEL% >> "%SETUPLOG%"

if not exist "%DEST%\run.ps1" (
    echo [%date% %time%] ERROR: %DEST%\run.ps1 no existe despues de la copia >> "%SETUPLOG%"
    echo  [ERROR] La copia fallo. Revisa permisos y volve a intentar.
    pause
    exit /b 1
)

echo [%date% %time%] Copia OK, %DEST%\run.ps1 existe >> "%SETUPLOG%"
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
echo [%date% %time%] Acceso directo del Escritorio: codigo %ERRORLEVEL% >> "%SETUPLOG%"
del "%SHORTCUT_PS%" >nul 2>&1

echo  [OK] Acceso directo creado en el Escritorio.
echo.
echo  Iniciando MejoraPC por primera vez (descubrimiento + optimizacion)...
echo  Esto va a escanear la PC, hacerte unas preguntas breves, y optimizar.
echo.
timeout /t 3 >nul

echo [%date% %time%] Lanzando run.ps1 -- ExecutionPolicy Bypass, ver PowerShell: >> "%SETUPLOG%"
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" >> "%SETUPLOG%" 2>&1
powershell -ExecutionPolicy Bypass -File "%DEST%\run.ps1"
echo [%date% %time%] run.ps1 termino -- codigo de salida: %ERRORLEVEL% >> "%SETUPLOG%"
echo [%date% %time%] Setup.bat completo >> "%SETUPLOG%"
pause
