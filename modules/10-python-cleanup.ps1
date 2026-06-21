[CmdletBinding()]
param()

# ── MejoraPC — modules/10-python-cleanup.ps1 ───────────────────────
# Detecta versiones de Python, conserva 3.14, ofrece eliminar el resto
# si no hay dependencia en C:\Github\. Exporta pip list antes de borrar.

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$backupDir = "$scriptRoot\backups"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force $backupDir | Out-Null }
$date = (Get-Date).ToString('yyyy-MM-dd')

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         10 - PYTHON CLEANUP                      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── 1. Detectar versiones instaladas ───────────────────────────────
Write-Host "  Detectando instalaciones de Python..." -ForegroundColor DarkGray
$pythons = [System.Collections.ArrayList]@()
try {
    $launcher = py -0p 2>&1 | Out-String
    foreach ($line in ($launcher -split "`n")) {
        if ($line -match '-V:(\d+\.\d+).*?\s+(\S:\\.*python\.exe)') {
            $ver = $Matches[1]; $path = $Matches[2].Trim()
            $size = 0
            $dir = Split-Path $path -Parent
            if (Test-Path $dir) { $size = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
            $null = $pythons.Add([pscustomobject]@{ Version = $ver; Path = $path; Dir = $dir; Size = $size })
        }
    }
} catch { }

if ($pythons.Count -eq 0) {
    # fallback: winget list
    Write-Host "  (py launcher no disponible — usando winget list)" -ForegroundColor DarkGray
    $wl = winget list --id Python.Python 2>&1 | Out-String
    Write-Host $wl -ForegroundColor Gray
}

Write-Host ""
Write-Host "  ── Versiones detectadas" -ForegroundColor DarkCyan
foreach ($p in $pythons) {
    Write-Status "Python $($p.Version)" "$($p.Path) ($(ConvertTo-HumanReadable $p.Size))" 'INFO'
}
Write-Host ""

# ── 2. Cuál usa Claude Code ────────────────────────────────────────
$claudePy = $null
$claudeCfg = "$env:APPDATA\Claude"
if (Test-Path $claudeCfg) { Write-Host "  Config Claude detectada en $claudeCfg" -ForegroundColor DarkGray }
$pathPy = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($pathPy) { Write-Host "  python en PATH -> $pathPy" -ForegroundColor DarkGray }

# ── 3. Escanear dependencias de proyectos (rápido, con timeout) ────
# Mismo enfoque que 02-debloat.ps1: todo el escaneo corre en un job con
# corte duro a los 10s. Solo primer nivel de C:\Github\ (no recursivo) y
# solo archivos en la raíz de cada proyecto. Si se cuelga, se asume que no
# hay dependencias específicas y se continúa.
$pinned   = [System.Collections.ArrayList]@()
$ghRoot   = 'C:\Github\'
$timedOut = $false

$scanBlock = {
    param($root)
    $versions = @()
    if (Test-Path $root) {
        foreach ($proj in (Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue)) {
            foreach ($file in '.python-version', 'pyproject.toml', 'requirements.txt') {
                $f = Join-Path $proj.FullName $file
                if (Test-Path $f) {
                    $c = Get-Content $f -Raw -ErrorAction SilentlyContinue
                    foreach ($m in [regex]::Matches($c, '3\.(\d+)')) {
                        $versions += "3.$($m.Groups[1].Value)"
                    }
                }
            }
        }
    }
    ,($versions | Select-Object -Unique)
}

$job = Start-Job -ScriptBlock $scanBlock -ArgumentList $ghRoot
if (Wait-Job $job -Timeout 10) {
    foreach ($v in (Receive-Job $job)) {
        if ($pinned -notcontains $v) { $null = $pinned.Add($v) }
    }
} else {
    $timedOut = $true
    Stop-Job $job -ErrorAction SilentlyContinue
}
Remove-Job $job -Force -ErrorAction SilentlyContinue

if ($timedOut) {
    Write-Host "  Escaneo de proyectos excedió 10s — se asume sin dependencias específicas." -ForegroundColor DarkYellow
} elseif ($pinned.Count -gt 0) {
    Write-Host "  Versiones referenciadas en proyectos: $($pinned -join ', ')" -ForegroundColor Yellow
}
Write-Host ""

# ── 4/5/7/8. Conservar 3.14, ofrecer eliminar el resto ─────────────
$toConsider = @($pythons | Where-Object { $_.Version -ne '3.14' })
if ($toConsider.Count -eq 0) {
    Write-Host "  [+] Solo está 3.14 (o no se detectaron otras). Nada que limpiar." -ForegroundColor Green
} else {
    foreach ($p in $toConsider) {
        $ver = $p.Version
        if ($pinned -contains $ver) {
            Write-Host "  [!] Python $ver está referenciado en un proyecto — se conserva." -ForegroundColor Yellow
            continue
        }
        Write-Host "  Python $ver no parece tener dependencias. ¿Eliminar? [Y/N]: " -NoNewline -ForegroundColor White
        $ans = Read-Host
        if ($ans -match '^[Yy]') {
            # 6. exportar pip list
            $pkgFile = Join-Path $backupDir "python-packages-$ver-$date.txt"
            try { & py "-$ver" -m pip list 2>&1 | Out-File -FilePath $pkgFile -Encoding utf8; Write-Host "      pip list -> $pkgFile" -ForegroundColor DarkGray } catch { }
            # 8. desinstalar via winget
            $wid = "Python.Python.$ver"
            Write-Host "      Desinstalando $wid ..." -ForegroundColor DarkGray
            winget uninstall --id $wid --silent --accept-source-agreements 2>&1 | Out-Null
            Write-Host "  [OK] Python $ver eliminado." -ForegroundColor Green
        }
    }
}

# ── 9. Limpiar PATH huérfano (informativo) ─────────────────────────
Write-Host ""
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$orphans = ($userPath -split ';') | Where-Object { $_ -match 'Python3(11|12|13)' -and -not (Test-Path $_) }
if ($orphans) {
    Write-Host "  Entradas PATH huérfanas detectadas:" -ForegroundColor Yellow
    $orphans | ForEach-Object { Write-Host "       $_" -ForegroundColor Gray }
    $clean = ($userPath -split ';' | Where-Object { $_ -and (Test-Path $_) -or $_ -notmatch 'Python' }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $clean, 'User')
    Write-Host "  [OK] PATH de usuario limpiado." -ForegroundColor Green
}

# ── 10. Verificar ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  Verificación final:" -ForegroundColor DarkCyan
try { $v = python --version 2>&1; Write-Host "  $v" -ForegroundColor Green } catch { }

Write-Host ""
Write-Host "  Presioná ENTER para volver..." -ForegroundColor DarkGray
$null = Read-Host
