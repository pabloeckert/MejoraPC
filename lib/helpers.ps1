# Funciones compartidas para todos los módulos de MejoraPC

# winget vive como App Execution Alias en
# %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe. Windows inyecta esa
# carpeta al PATH dinámicamente por cada sesión de escritorio (explorer.exe),
# NO vive en la variable PATH persistente del registro (HKCU/HKLM) — por
# eso no aparece ahí ni en una máquina sana. El problema real es que
# cualquier proceso que NO desciende de esa inyección de sesión (una
# scheduled task, un entorno de automatización/CI, una consola lanzada por
# una cadena de procesos que no la propaga) no tiene "winget" en el PATH,
# y Get-Command/CommandNotFoundException fallan igual de silencioso que si
# winget no estuviera instalado — descubierto el 2026-09-05 corriendo
# run.ps1 desde una sesión así: 56+ de 57 "errores capturados" del
# diagnóstico eran consecuencia indirecta de esto. Se agrega el directorio
# al $env:PATH del proceso actual (no toca nada persistente del sistema)
# si el ejecutable existe físicamente pero el comando no resuelve.
function Repair-WingetPath {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
    $wingetDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (Test-Path (Join-Path $wingetDir 'winget.exe')) {
        # AL FINAL del PATH, no al principio: esa misma carpeta también tiene
        # el stub placeholder de "python.exe" (y otros) de la Microsoft Store.
        # Anteponerla le robaba prioridad a instalaciones reales ya presentes
        # en el PATH (ej. C:\Python314\python.exe) — un "python" en cualquier
        # módulo empezaba a resolver al stub roto en vez del real. Al agregar
        # al final, se sigue usando la instalación real si existe, y el stub
        # solo entra en juego si NINGÚN OTRO PATH tiene ese comando (mismo
        # comportamiento nativo de Windows). Descubierto el 2026-09-05:
        # 10-python-cleanup.ps1 rompió apenas se agregó esta función.
        $env:PATH = "$env:PATH;$wingetDir"
        return [bool](Get-Command winget -ErrorAction SilentlyContinue)
    }
    return $false
}

# En Windows PowerShell 5.1 (Desktop CLR), Get-Package/Import-Module auto-cargan
# el módulo PackageManagement buscando en $env:PSModulePath en orden. Si la
# carpeta de PowerShell 7 (Core) quedó antes que las carpetas nativas de
# WindowsPowerShell (pasa cuando pwsh7 se instaló y se agregó al PSModulePath
# persistente), PS 5.1 encuentra ahí la copia para pwsh7 — sin la subcarpeta
# "fullclr" que el Desktop CLR necesita — y Get-Package falla con
# FileNotFoundException aunque el paquete buscado sí exista. Descubierto el
# 2026-09-07: Find-InstalledPackage en 02-debloat.ps1 ensuciaba $Error con 2
# excepciones por corrida pese a su propio try/catch, porque el fallo real es
# al importar el módulo, no al buscar el paquete — el catch nunca llega a
# ejecutarse para esa causa. Solo se toca en Desktop edition: si este script
# corre directo bajo pwsh7, esa carpeta es la correcta y no se toca.
function Repair-PSModulePath {
    if ($PSVersionTable.PSEdition -ne 'Desktop') { return }
    $env:PSModulePath = ($env:PSModulePath -split ';' | Where-Object {
        $_ -notlike '*\PowerShell\7\Modules*'
    }) -join ';'
}

function Write-Status {
    param(
        [string]$Label,
        [string]$Value,
        [ValidateSet('OK','WARN','ERROR','INFO')]
        [string]$Status = 'INFO'
    )
    $icon  = switch ($Status) { 'OK' { '[+]' }; 'WARN' { '[!]' }; 'ERROR' { '[x]' }; default { '[·]' } }
    $color = switch ($Status) { 'OK' { 'Green' }; 'WARN' { 'Yellow' }; 'ERROR' { 'Red' }; default { 'Gray' } }
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$($Label): " -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}

function ConvertTo-HumanReadable {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return '{0:N2} TB' -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Get-TemperatureStatus {
    param([double]$Temp, [string]$Component = 'CPU')
    $thresholds = @{
        CPU  = @{ OK = 70; WARN = 85 }
        GPU  = @{ OK = 75; WARN = 90 }
        Disk = @{ OK = 45; WARN = 55 }
    }
    $t = if ($thresholds[$Component]) { $thresholds[$Component] } else { $thresholds['CPU'] }
    if ($Temp -le $t.OK)   { return 'OK'    }
    if ($Temp -le $t.WARN) { return 'WARN'  }
    return 'ERROR'
}

function Get-MergedBloatCatalog {
    # Universal (cualquier Windows 11) + data/profile-local.json si existe
    # (perfil de esta máquina: nunca viaja en el paquete USB).
    param([string]$ScriptRoot)
    $u = Get-Content "$ScriptRoot\data\universal-bloatware.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $pPath = "$ScriptRoot\data\profile-local.json"
    if (Test-Path $pPath) {
        $p = Get-Content $pPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($p.blockA_extra -and $p.blockA_extra.groups) {
            foreach ($g in $p.blockA_extra.groups.PSObject.Properties) {
                $u.blockA.groups | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.blockB) { $u | Add-Member -NotePropertyName 'blockB' -NotePropertyValue $p.blockB -Force }
        if ($p.keep_always) { $u | Add-Member -NotePropertyName 'keep_always' -NotePropertyValue $p.keep_always -Force }
    }
    return $u
}

function Get-MergedTweaksCatalog {
    # Universal (cualquier Windows 11) + data/profile-local.json si existe
    # (perfil de esta máquina: nunca viaja en el paquete USB).
    param([string]$ScriptRoot)
    $u = Get-Content "$ScriptRoot\data\universal-tweaks.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $pPath = "$ScriptRoot\data\profile-local.json"
    if (Test-Path $pPath) {
        $p = Get-Content $pPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($p.registry) {
            foreach ($g in $p.registry.PSObject.Properties) {
                $u.registry | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.startup_disable) {
            foreach ($g in $p.startup_disable.PSObject.Properties) {
                $u.startup_disable | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
        }
        if ($p.ram_recoverable_estimate) {
            foreach ($g in $p.ram_recoverable_estimate.PSObject.Properties) {
                $u.ram_recoverable_estimate | Add-Member -NotePropertyName $g.Name -NotePropertyValue $g.Value -Force
            }
            $sum = 0
            foreach ($g in $u.ram_recoverable_estimate.PSObject.Properties) {
                if ($g.Name -ne 'total_mb') { $sum += [int]$g.Value }
            }
            $u.ram_recoverable_estimate | Add-Member -NotePropertyName 'total_mb' -NotePropertyValue $sum -Force
        }
    }
    return $u
}

function Get-DiagnosticHeader {
    # Encabezado de contexto para logs/ultimo-diagnostico.txt — info del
    # equipo/entorno que ayuda a diagnosticar remotamente un run.ps1 corrido
    # en una PC ajena (sin acceso directo a esa máquina).
    param([string]$ScriptRoot)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

    $pyVersion = 'no detectado'
    foreach ($c in @('python', 'py')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) {
            try { $pyVersion = (& $c --version 2>&1 | Out-String).Trim() } catch { }
            break
        }
    }

    $buildFile = "$ScriptRoot\data\build-version.txt"
    $build = if (Test-Path $buildFile) { (Get-Content $buildFile -Raw).Trim() } else { 'desarrollo local (sin data\build-version.txt)' }
    $onOneDrive = $ScriptRoot -match 'OneDrive'

    $ramGB = if ($cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { '?' }

    return @"
═══════════════════════════════════════════════════════════
  MejoraPC — Diagnóstico completo
═══════════════════════════════════════════════════════════
Fecha/hora:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Build instalado:   $build
Equipo:            $($cs.Manufacturer) $($cs.Model) — $env:COMPUTERNAME
Windows:           $($os.Caption) $($os.Version) (Build $($os.BuildNumber))
PowerShell:        $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))
Corriendo como admin: $isAdmin
Ruta de ejecución: $ScriptRoot
  ¿Carpeta sincronizada por OneDrive?: $onOneDrive
Python:            $pyVersion
CPU/RAM:           $($cs.NumberOfLogicalProcessors) núcleos lógicos, ${ramGB}GB RAM
═══════════════════════════════════════════════════════════

"@
}

function Wait-KeyIfInteractive {
    param([switch]$Auto)
    if (-not $Auto -and $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected) {
        Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
        $null = Read-Host
    }
}

function Clear-HostSafe {
    # Envuelve Clear-Host: en un host sin buffer de consola real (PowerShell
    # 7/pwsh corriendo con salida redirigida, sesión remota, automatización
    # sin pty) Clear-Host lanza SetValueInvocationException al intentar
    # mover el cursor ("Controlador no válido") y aborta el script entero
    # en su primera línea -- visto el 2026-09-07: tiró abajo 7 de 9 módulos
    # del pipeline (01-backup, 02-debloat, 03-performance, 04-estetica,
    # 06-seguridad, 10-python-cleanup, 13-verify) sin ejecutar nada de su
    # lógica real. Es puramente estético (limpiar pantalla), así que un
    # fallo acá nunca debe frenar el módulo.
    try { Clear-Host } catch { if ($Error.Count -gt 0) { $Error.RemoveAt(0) } }
}

function Ensure-DataDirectory {
    param([string]$ScriptRoot)
    foreach ($dir in @("$ScriptRoot\data", "$ScriptRoot\logs", "$ScriptRoot\logs\usage")) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    }
}
