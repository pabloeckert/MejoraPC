[CmdletBinding()]
param(
    [string]$OutDir = "$PSScriptRoot\..\dist\MejoraPC-portable"
)

# ── MejoraPC — installer/build-package.ps1 ─────────────────────────
# Empaqueta el repo para llevar a otra PC (USB, OneDrive compartido, etc).
# Corre en la PC de Pablo, ANTES de trasladarlo — no se distribuye con el
# paquete. Excluye todo lo que es historial/datos personales de esta
# máquina: el paquete resultante arranca "limpio" en cualquier PC, y
# modules/00-discover.ps1 genera su propio data/profile-local.json ahí
# (nunca el de Pablo). Genera tanto la carpeta portable como un .zip listo
# para copiar/sincronizar.

$scriptRoot = Split-Path -Parent $PSScriptRoot
$zipPath = "$scriptRoot\dist\MejoraPC.zip"

Write-Host ""
Write-Host "  Empaquetando MejoraPC para USB..." -ForegroundColor Cyan
Write-Host "  Origen:  $scriptRoot" -ForegroundColor DarkGray
Write-Host "  Destino: $OutDir" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $OutDir) {
    Write-Host "  Limpiando destino previo..." -ForegroundColor DarkGray
    Remove-Item -Path $OutDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Archivos con datos/historial personal de ESTA máquina — nunca viajan.
$excludeFiles = @(
    'mejorapc.db', 'profile-local.json', 'status.json',
    'last-verify.json', 'discovery-report.json', 'monitor.log',
    'last-hardware-check.json', 'last-startup-audit.json',
    'hardware-profile.json', 'recommendations.json', 'smart-recommendations.json',
    'reporte_limpieza_resultado.csv', 'reporte_limpieza_resultado.txt'
)
# Carpetas de runtime/historial + control de versiones/estado local.
$excludeDirs = @('logs', 'backups', 'rescue', '__pycache__', '.git', '.claude', 'dist')

$robocopyArgs = @($scriptRoot, $OutDir, '/E', '/XD') + $excludeDirs + @('/XF') + $excludeFiles + @('/NFL', '/NDL', '/NJH', '/NJS')
robocopy @robocopyArgs | Out-Null

# robocopy usa 0-7 como "éxito" (bitmask de qué hizo); solo >=8 es error real.
if ($LASTEXITCODE -ge 8) {
    Write-Host "  [x] robocopy devolvió código $LASTEXITCODE — revisar." -ForegroundColor Red
    exit 1
}

# Marca de versión — para saber exactamente qué código corrió en una PC
# ajena al leer un diagnóstico enviado de vuelta (ver Get-DiagnosticHeader).
$gitHash = $null
try { $gitHash = (git -C $scriptRoot rev-parse --short HEAD 2>$null) } catch { }
$buildInfo = if ($gitHash) {
    "commit $gitHash — empaquetado $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
} else {
    "empaquetado $(Get-Date -Format 'yyyy-MM-dd HH:mm') (sin info de git)"
}
Set-Content -Path "$OutDir\data\build-version.txt" -Value $buildInfo -Encoding UTF8

# Verificación: ninguno de los archivos excluidos debe existir en destino.
$leaked = @()
foreach ($f in $excludeFiles) {
    $hits = Get-ChildItem -Path $OutDir -Recurse -Filter $f -ErrorAction SilentlyContinue
    if ($hits) { $leaked += $hits.FullName }
}
if ($leaked.Count -gt 0) {
    Write-Host "  [x] ALERTA: archivos personales terminaron en el paquete:" -ForegroundColor Red
    $leaked | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    exit 1
}

Write-Host "  [+] Paquete listo en: $OutDir" -ForegroundColor Green
Write-Host "  [+] Verificado: sin datos personales en el paquete." -ForegroundColor Green
Write-Host ""

# ── Comprimir a .zip, listo para USB, OneDrive, etc ─────────────────
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path "$OutDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

if (-not (Test-Path $zipPath)) {
    Write-Host "  [x] No se pudo crear el .zip." -ForegroundColor Red
    exit 1
}

Write-Host "  [+] Zip listo en: $zipPath" -ForegroundColor Green
Write-Host ""
Write-Host "  Copiá ese .zip a la PC destino (USB, carpeta de OneDrive" -ForegroundColor DarkGray
Write-Host "  compartida, etc), descomprimilo ahí, y hacé doble-click en" -ForegroundColor DarkGray
Write-Host "  Setup.bat. Se auto-eleva a administrador y corre todo solo:" -ForegroundColor DarkGray
Write-Host "  descubrimiento de esa PC + optimización + monitor invisible." -ForegroundColor DarkGray
Write-Host ""
exit 0
