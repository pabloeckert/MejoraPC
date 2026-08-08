[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/13-verify.ps1 ───────────────────────────────
# Verificación REAL del sistema. No confía en lo que dijeron los otros
# módulos: relee el estado directo del disco, el registry y los servicios.
#
#   1. Debloat   — Appx ausente + política escrita + binario inexistente.
#   2. Tweaks    — valor real en registry, estado de servicios, power plan.
#   3. Disco     — carpetas más pesadas leídas directo del filesystem
#                  ([System.IO.Directory], NUNCA Get-ChildItem recursivo).
#   4. Reporte   — VERIFICADO ✓ / PENDIENTE / FALLIDO ✗, honesto.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$bloatFile = "$scriptRoot\data\bloatware.json"
$tweakFile = "$scriptRoot\data\tweaks.json"

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         13 - VERIFICACIÓN REAL DEL SISTEMA       ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Acumuladores globales para el reporte final.
$script:nVerif = 0; $script:nPend = 0; $script:nFail = 0

# Imprime una fila alineada y coloreada según el estado.
function Write-Row {
    param(
        [ValidateSet('VERIFICADO','PENDIENTE','FALLIDO','INFO')] [string]$Estado,
        [string]$Item,
        [string]$Detalle = ''
    )
    switch ($Estado) {
        'VERIFICADO' { $color = 'Green';  $icon = '[OK]  ✓'; $script:nVerif++ }
        'PENDIENTE'  { $color = 'Yellow'; $icon = '[...] •'; $script:nPend++ }
        'FALLIDO'    { $color = 'Red';    $icon = '[XX]  ✗'; $script:nFail++ }
        default      { $color = 'Gray';   $icon = '[--]'    }
    }
    Write-Host ("  {0,-9} " -f $icon) -NoNewline -ForegroundColor $color
    Write-Host ("{0,-46}" -f $Item) -NoNewline -ForegroundColor White
    if ($Detalle) { Write-Host " $Detalle" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Write-Section {
    param([string]$Title)
    $rule = '─' * [Math]::Max(0, 40 - $Title.Length)
    Write-Host ""
    Write-Host "  ── $Title $rule" -ForegroundColor Cyan
    Write-Host ""
}

if (-not (Test-Path $bloatFile)) { Write-Host "  [x] Falta data/bloatware.json" -ForegroundColor Red; return }
$bloat = Get-Content $bloatFile -Raw -Encoding UTF8 | ConvertFrom-Json

# ═══════════════════════════════════════════════════════════════════
# 1. DEBLOAT — MSIX (Appx + política) y no-MSIX (registry/Programs)
# ═══════════════════════════════════════════════════════════════════
Write-Section "1. DEBLOAT — apps de Microsoft Store (CAPA 1 + 2)"

$policyBase = $bloat.policy_msix.policy_base
$pfns       = @($bloat.policy_msix.package_family_names)

foreach ($pfn in $pfns) {
    $name      = ($pfn -split '_')[0]
    $installed = [bool](Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    $subkey    = Join-Path $policyBase $pfn
    $hasPolicy = $false
    if (Test-Path $subkey) {
        $rp = (Get-ItemProperty -Path $subkey -Name 'RemovedPackage' -ErrorAction SilentlyContinue).RemovedPackage
        $hasPolicy = ($rp -eq 1)
    }

    if (-not $installed -and $hasPolicy) {
        Write-Row 'VERIFICADO' $name 'sin Appx + política activa'
    } elseif (-not $installed -and -not $hasPolicy) {
        Write-Row 'VERIFICADO' $name 'sin Appx (sin política — puede reinstalarse)'
    } elseif ($installed -and $hasPolicy) {
        Write-Row 'PENDIENTE' $name 'aún presente — la política lo elimina en el próximo login'
    } else {
        Write-Row 'FALLIDO' $name 'sigue instalado y SIN política'
    }
}

# ── No-MSIX: Bloque A (winget/Programs). Verifica registry + Program Files. ──
Write-Section "1b. DEBLOAT — apps no-MSIX (CAPA 3, Bloque A)"

$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$allUninstall = foreach ($k in $uninstallKeys) { Get-ItemProperty $k -ErrorAction SilentlyContinue }

# Programa → nombre de carpeta esperada en Program Files (best-effort).
$nonMsixGroups = @('emuladores','browsers_sin_uso','video_edicion','ftp_solapados',
                   'descargas_solapadas','redes_sin_uso','ia_local','sin_uso_confirmado')
$progFiles = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) | Where-Object { $_ }

# Palabras genéricas: el último segmento de un ID "Vendor.Producto" a veces
# es una palabra común (ej. "Flywheel.Local" -> "Local") que matchea por
# substring cualquier DisplayName no relacionado (ej. "... Localization
# Component"). Para esos casos NO se confía en el match de registry — solo
# en la carpeta exacta de Program Files (Test-Path, no substring).
$genericWords = @('local','client','service','update','updater','app','desktop',
                  'home','player','core','tools','tool','manager','helper',
                  'viewer','studio','pro','plus','online','web','cloud','sync',
                  'launcher','store','agent','host','engine','runtime')

foreach ($grp in $nonMsixGroups) {
    $items = $bloat.blockA.groups.$grp
    if (-not $items) { continue }
    foreach ($id in $items) {
        # Patrón legible: último segmento del ID/ARP path.
        $kw = $id
        if ($kw -match '\\') { $kw = ($kw -split '\\')[-1] }
        if ($kw -match '^[^\s\\]+\.[^\s\\]+$') { $kw = ($kw -split '\.')[-1] }

        $inRegistry = $false
        if ($genericWords -notcontains $kw.ToLower()) {
            $inRegistry = [bool]($allUninstall | Where-Object { $_.DisplayName -like "*$kw*" })
        }
        # Binario en disco: ¿existe una carpeta con ese nombre en Program Files?
        $onDisk = $false
        foreach ($pf in $progFiles) {
            if (Test-Path (Join-Path $pf $kw)) { $onDisk = $true; break }
        }

        if (-not $inRegistry -and -not $onDisk) {
            Write-Row 'VERIFICADO' $id 'sin entrada de registry ni carpeta en Program Files'
        } elseif ($inRegistry -or $onDisk) {
            $d = @(); if ($inRegistry) { $d += 'registry' }; if ($onDisk) { $d += 'Program Files' }
            Write-Row 'FALLIDO' $id ("sigue presente en: " + ($d -join ' + '))
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# 2. TWEAKS DE PERFORMANCE — registry, servicios, power plan
# ═══════════════════════════════════════════════════════════════════
Write-Section "2. TWEAKS DE PERFORMANCE"

if (Test-Path $tweakFile) {
    $tweaks = Get-Content $tweakFile -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($group in $tweaks.registry.PSObject.Properties) {
        foreach ($t in $group.Value) {
            $actual = $null
            if (Test-Path $t.path) {
                $actual = (Get-ItemProperty -Path $t.path -Name $t.name -ErrorAction SilentlyContinue).$($t.name)
            }
            $label = "$($group.Name) / $($t.name)"
            if ($null -eq $actual) {
                Write-Row 'PENDIENTE' $label "no escrito todavía (esperado=$($t.value))"
            } elseif ("$actual" -eq "$($t.value)") {
                Write-Row 'VERIFICADO' $label "= $actual"
            } else {
                Write-Row 'FALLIDO' $label "actual=$actual, esperado=$($t.value)"
            }
        }
    }

    # Servicios.
    foreach ($svc in $tweaks.services) {
        $startMode = (Get-CimInstance Win32_Service -Filter "Name='$($svc.name)'" -ErrorAction SilentlyContinue).StartMode
        if (-not $startMode) {
            Write-Row 'VERIFICADO' "servicio $($svc.name)" 'no existe (nada que deshabilitar)'
            continue
        }
        # StartMode reporta 'Auto'/'Manual'/'Disabled'; el tweak usa 'Disabled'/'Manual'/'Automatic'.
        $want = $svc.action
        $match = ($startMode -eq $want) -or ($startMode -eq 'Auto' -and $want -eq 'Automatic')
        if ($match) {
            Write-Row 'VERIFICADO' "servicio $($svc.name)" "StartMode=$startMode"
        } else {
            Write-Row 'PENDIENTE' "servicio $($svc.name)" "StartMode=$startMode, esperado=$want"
        }
    }
    # Startup items (Run keys / scheduled tasks deshabilitados).
    foreach ($group in $tweaks.startup_disable.PSObject.Properties) {
        $item = $group.Value
        $stillThere = $false
        foreach ($rk in $item.run_keys) {
            if (-not (Test-Path $rk)) { continue }
            $props = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -match $item.match -or "$($p.Value)" -match $item.match) { $stillThere = $true }
            }
        }
        try {
            $t = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match $item.match -and $_.State -ne 'Disabled' }
            if ($t) { $stillThere = $true }
        } catch { }
        if ($stillThere) {
            Write-Row 'PENDIENTE' "startup / $($group.Name)" 'todavía en Run keys o task activa'
        } else {
            Write-Row 'VERIFICADO' "startup / $($group.Name)" 'sin entrada de arranque'
        }
    }
} else {
    Write-Host "  [!] Falta data/tweaks.json — se omite la verificación de tweaks." -ForegroundColor Yellow
}

# Power plan activo.
try {
    $active = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    $ultActive = $active -match 'e5062635-e13c-4eac-a7e9-ec5a6fb7d65b' -or $active -match '(?i)ultimate|máximo rendimiento|maximo rendimiento'
    if ($ultActive) {
        Write-Row 'VERIFICADO' 'power plan' $active
    } else {
        Write-Row 'PENDIENTE' 'power plan' "activo: $active (no es Ultimate Performance)"
    }
} catch { Write-Row 'FALLIDO' 'power plan' "error al leer: $_" }

# Hibernate (archivo hiberfil.sys).
$hiber = Join-Path $env:SystemDrive 'hiberfil.sys'
if (Test-Path $hiber) {
    Write-Row 'PENDIENTE' 'hibernate' 'hiberfil.sys aún presente (powercfg /h off pendiente o en uso)'
} else {
    Write-Row 'VERIFICADO' 'hibernate' 'sin hiberfil.sys'
}

# ═══════════════════════════════════════════════════════════════════
# 3. DISCO — carpetas más pesadas (lectura directa del filesystem)
# ═══════════════════════════════════════════════════════════════════
Write-Section "3. DISCO — análisis directo (sin Get-ChildItem recursivo)"

# Suma el tamaño de un árbol con una pila propia y [System.IO.Directory].
# Evita Get-ChildItem -Recurse (que se cuelga con symlinks/permisos) y
# tolera accesos denegados carpeta por carpeta. Corte duro por tiempo:
# carpetas como AppData\Local con decenas de GB (caches de apps, node_modules,
# etc.) pueden tardar minutos recorridas archivo por archivo — mismo problema
# que ya se resolvió con timeouts en 02-debloat.ps1/10-python-cleanup.ps1.
function Get-DirSize {
    param([string]$Path, [int]$MaxSeconds = 8)
    $total = 0L
    $timedOut = $false
    if (-not [System.IO.Directory]::Exists($Path)) { return @{ Bytes = 0L; TimedOut = $false } }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $stack = New-Object System.Collections.Stack
    $stack.Push($Path)
    while ($stack.Count -gt 0) {
        if ($sw.Elapsed.TotalSeconds -gt $MaxSeconds) { $timedOut = $true; break }
        $dir = $stack.Pop()
        try {
            foreach ($f in [System.IO.Directory]::GetFiles($dir)) {
                try { $total += [System.IO.FileInfo]::new($f).Length } catch { }
            }
            foreach ($d in [System.IO.Directory]::GetDirectories($dir)) { $stack.Push($d) }
        } catch { }   # acceso denegado / reparse point → se ignora esa rama
    }
    return @{ Bytes = $total; TimedOut = $timedOut }
}

# Tamaños puntuales de carpetas clave.
$keyFolders = [ordered]@{
    'C:\Windows\Temp'           = 'C:\Windows\Temp'
    'AppData\Local'             = $env:LOCALAPPDATA
    'AppData\Roaming'           = $env:APPDATA
    'Program Files'             = $env:ProgramFiles
    'Program Files (x86)'       = ${env:ProgramFiles(x86)}
    'ProgramData'               = $env:ProgramData
}
Write-Host "  Carpetas clave:" -ForegroundColor DarkCyan
foreach ($kv in $keyFolders.GetEnumerator()) {
    if (-not $kv.Value) { continue }
    $r = Get-DirSize -Path $kv.Value -MaxSeconds 5
    $suffix = if ($r.TimedOut) { ' (parcial, excedió 5s)' } else { '' }
    Write-Host ("    {0,-22} {1,12}{2}" -f $kv.Key, (ConvertTo-HumanReadable $r.Bytes), $suffix) -ForegroundColor Gray
}
Write-Host ""

# TOP 20 subcarpetas más pesadas entre Program Files, ProgramData y AppData\Local.
# Presupuesto de tiempo global (no solo por carpeta): en un dev box real con
# decenas de subcarpetas pesadas (caches de apps, node_modules, etc.) esto
# puede tardar minutos. Si se excede, se corta y se informa resultado parcial.
Write-Host "  Escaneando subcarpetas (puede tardar)..." -ForegroundColor DarkGray
$roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:LOCALAPPDATA) | Where-Object { $_ }
$subdirs = [System.Collections.ArrayList]@()
$globalSw = [System.Diagnostics.Stopwatch]::StartNew()
$globalMaxSeconds = 45
$scanCut = $false
:rootsLoop foreach ($root in $roots) {
    try {
        foreach ($d in [System.IO.Directory]::GetDirectories($root)) {
            if ($globalSw.Elapsed.TotalSeconds -gt $globalMaxSeconds) { $scanCut = $true; break rootsLoop }
            $r = Get-DirSize -Path $d -MaxSeconds 5
            $null = $subdirs.Add([PSCustomObject]@{ Carpeta = $d; Bytes = $r.Bytes; Parcial = $r.TimedOut })
        }
    } catch { }
}
if ($scanCut) {
    Write-Host "  [!] Escaneo cortado a los ${globalMaxSeconds}s — resultados parciales ($($subdirs.Count) carpetas medidas)." -ForegroundColor Yellow
}

$top = $subdirs | Sort-Object Bytes -Descending | Select-Object -First 20
Write-Host ""
Write-Host "  TOP 20 subcarpetas más pesadas:" -ForegroundColor DarkCyan
$i = 1
foreach ($d in $top) {
    $human = ConvertTo-HumanReadable $d.Bytes
    # > 500MB fuera de Windows = candidato a revisar.
    $heavy = ($d.Bytes -gt 500MB) -and ($d.Carpeta -notlike "$env:SystemRoot*")
    $color = if ($heavy) { 'Yellow' } else { 'Gray' }
    Write-Host ("  {0,2}. {1,10}  " -f $i, $human) -NoNewline -ForegroundColor $color
    Write-Host $d.Carpeta -NoNewline -ForegroundColor DarkGray
    if ($d.Parcial) { Write-Host "  (parcial)" -NoNewline -ForegroundColor DarkYellow }
    Write-Host ""
    $i++
}
Write-Host ""
$bigNonSystem = @($subdirs | Where-Object { $_.Bytes -gt 500MB -and $_.Carpeta -notlike "$env:SystemRoot*" })
Write-Host "  Carpetas > 500MB que NO son del sistema: $($bigNonSystem.Count)" -ForegroundColor $(if ($bigNonSystem.Count) { 'Yellow' } else { 'Green' })

# ═══════════════════════════════════════════════════════════════════
# 4. REPORTE FINAL HONESTO
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                 REPORTE FINAL                    ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  VERIFICADO ✓ : $($script:nVerif)" -ForegroundColor Green
Write-Host "                 lo que realmente está aplicado en disco/registry" -ForegroundColor DarkGray
Write-Host "  PENDIENTE  • : $($script:nPend)" -ForegroundColor Yellow
Write-Host "                 requiere reboot o próximo login para aplicarse" -ForegroundColor DarkGray
Write-Host "  FALLIDO    ✗ : $($script:nFail)" -ForegroundColor Red
Write-Host "                 sigue presente y sin mecanismo que lo elimine" -ForegroundColor DarkGray
Write-Host ""

if ($script:nFail -gt 0) {
    Write-Host "  → Reintentá los fallidos con la opción [2r] del menú." -ForegroundColor Yellow
}
if ($script:nPend -gt 0) {
    Write-Host "  → Reiniciá (o cerrá y abrí sesión) para aplicar los pendientes." -ForegroundColor Yellow
}
Write-Host ""

[PSCustomObject]@{
    timestamp  = (Get-Date).ToString('o')
    verificado = $script:nVerif
    pendiente  = $script:nPend
    fallido    = $script:nFail
} | ConvertTo-Json | Set-Content -Path "$scriptRoot\data\last-verify.json" -Encoding UTF8

Wait-KeyIfInteractive -Auto:$Auto
