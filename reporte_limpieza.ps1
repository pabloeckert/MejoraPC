# Ejecutar como Administrador
# Uso: powershell -ExecutionPolicy Bypass -File C:\Github\Herramientas\MejoraPC\reporte_limpieza.ps1

$report = @()
$threshold = 100MB

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "   ANALISIS DE DISCO C: - REPORTE LIMPIEZA" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. CARPETAS TEMP Y CACHE CONOCIDAS ---
Write-Host "[1/4] Escaneando carpetas temporales y cache..." -ForegroundColor Yellow

$cleanTargets = @(
    @{ Path = "C:\Windows\Temp";                                                    Category = "Windows Temp" }
    @{ Path = "$env:LOCALAPPDATA\Temp";                                             Category = "User Temp" }
    @{ Path = "C:\Windows\SoftwareDistribution\Download";                           Category = "Windows Update Cache" }
    @{ Path = "C:\Windows\Prefetch";                                                Category = "Prefetch" }
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache";                      Category = "IE/Edge Cache" }
    @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache";            Category = "Chrome Cache" }
    @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache";       Category = "Chrome Code Cache" }
    @{ Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles";                         Category = "Firefox Cache" }
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache";           Category = "Edge Cache" }
    @{ Path = "C:\Windows.old";                                                     Category = "Windows.old (instalacion anterior)" }
    @{ Path = "$env:USERPROFILE\Downloads";                                         Category = "Descargas usuario" }
    @{ Path = "C:\ProgramData\Microsoft\Windows Defender\Scans\History";            Category = "Defender Scan History" }
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer";                       Category = "Thumbnail Cache" }
    @{ Path = "$env:APPDATA\Microsoft\Teams\Cache";                                 Category = "Teams Cache" }
    @{ Path = "$env:APPDATA\Discord\Cache";                                         Category = "Discord Cache" }
    @{ Path = "$env:LOCALAPPDATA\npm-cache";                                        Category = "NPM Cache" }
    @{ Path = "$env:LOCALAPPDATA\pip\cache";                                        Category = "Python PIP Cache" }
    @{ Path = "C:\ProgramData\Package Cache";                                       Category = "Visual Studio Package Cache" }
)

foreach ($t in $cleanTargets) {
    if (Test-Path $t.Path) {
        $size = (Get-ChildItem $t.Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 2)
        $report += [PSCustomObject]@{
            Tipo      = "Carpeta limpiable"
            Categoria = $t.Category
            Ruta      = $t.Path
            TamanoMB  = $sizeMB
            Accion    = "LIMPIAR"
            Riesgo    = "BAJO"
        }
        Write-Host "  OK  $($t.Category): $sizeMB MB" -ForegroundColor Green
    }
}

# --- 2. ARCHIVOS GRANDES EN C: (>100MB) ---
Write-Host ""
Write-Host "[2/4] Buscando archivos grandes (>100MB)... puede tardar varios minutos..." -ForegroundColor Yellow

$excludePaths = @(
    "C:\Windows\WinSxS",
    "C:\hiberfil.sys",
    "C:\pagefile.sys",
    "C:\swapfile.sys",
    "C:\System Volume Information"
)

try {
    Get-ChildItem C:\ -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { !$_.PSIsContainer -and $_.Length -gt $threshold } |
        Where-Object {
            $path = $_.FullName
            -not ($excludePaths | Where-Object { $path -like "$_*" })
        } |
        ForEach-Object {
            $report += [PSCustomObject]@{
                Tipo      = "Archivo grande"
                Categoria = "Archivo >100MB"
                Ruta      = $_.FullName
                TamanoMB  = [math]::Round($_.Length / 1MB, 2)
                Accion    = "REVISAR"
                Riesgo    = "MEDIO"
            }
        }
} catch {}

Write-Host "  OK  Archivos grandes encontrados: $(($report | Where-Object {$_.Tipo -eq 'Archivo grande'}).Count)" -ForegroundColor Green

# --- 3. ARCHIVOS SISTEMA ESPECIALES ---
Write-Host ""
Write-Host "[3/4] Analizando archivos de sistema especiales..." -ForegroundColor Yellow

$sysFiles = @(
    @{ Path = "C:\hiberfil.sys";  Label = "Hibernacion (hiberfil.sys)" }
    @{ Path = "C:\pagefile.sys";  Label = "Memoria virtual (pagefile.sys)" }
    @{ Path = "C:\swapfile.sys";  Label = "Swap moderno (swapfile.sys)" }
)

foreach ($f in $sysFiles) {
    if (Test-Path $f.Path -ErrorAction SilentlyContinue) {
        try {
            $sz = [math]::Round((Get-Item $f.Path -Force -ErrorAction Stop).Length / 1MB, 2)
        } catch { $sz = 0 }
        $report += [PSCustomObject]@{
            Tipo      = "Archivo sistema"
            Categoria = $f.Label
            Ruta      = $f.Path
            TamanoMB  = $sz
            Accion    = "REVISAR (requiere decision)"
            Riesgo    = "ALTO"
        }
        Write-Host "  OK  $($f.Label): $sz MB" -ForegroundColor Green
    }
}

# --- 4. PAPELERA ---
Write-Host ""
Write-Host "[4/4] Revisando Papelera de reciclaje..." -ForegroundColor Yellow

$recycleBin = "C:\`$RECYCLE.BIN"
if (Test-Path $recycleBin) {
    $sz = (Get-ChildItem $recycleBin -Recurse -Force -ErrorAction SilentlyContinue |
           Measure-Object -Property Length -Sum).Sum
    $report += [PSCustomObject]@{
        Tipo      = "Papelera"
        Categoria = "Recycle Bin"
        Ruta      = $recycleBin
        TamanoMB  = [math]::Round($sz / 1MB, 2)
        Accion    = "VACIAR"
        Riesgo    = "BAJO"
    }
    Write-Host "  OK  Papelera: $([math]::Round($sz / 1MB, 2)) MB" -ForegroundColor Green
}

# --- GUARDAR REPORTE CSV ---
$outCSV = "C:\Github\Herramientas\MejoraPC\reporte_limpieza_resultado.csv"
$report | Export-Csv -Path $outCSV -NoTypeInformation -Encoding UTF8

# --- GUARDAR REPORTE TXT LEGIBLE ---
$outTXT = "C:\Github\Herramientas\MejoraPC\reporte_limpieza_resultado.txt"
$totalLimpiar  = ($report | Where-Object { $_.Accion -eq "LIMPIAR" } | Measure-Object TamanoMB -Sum).Sum
$totalRevisar  = ($report | Where-Object { $_.Accion -eq "REVISAR" } | Measure-Object TamanoMB -Sum).Sum
$totalVaciar   = ($report | Where-Object { $_.Accion -eq "VACIAR"  } | Measure-Object TamanoMB -Sum).Sum
$totalGeneral  = $totalLimpiar + $totalRevisar + $totalVaciar

$txt = @"
===========================================
   REPORTE DE LIMPIEZA - DISCO C:
   Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
===========================================

RESUMEN GENERAL
---------------
Espacio recuperable directo (LIMPIAR): $([math]::Round($totalLimpiar,2)) MB
Espacio a revisar (REVISAR):           $([math]::Round($totalRevisar,2)) MB
Papelera (VACIAR):                     $([math]::Round($totalVaciar,2)) MB
TOTAL POTENCIAL:                       $([math]::Round($totalGeneral,2)) MB

===========================================
DETALLE POR CATEGORIA
===========================================

$($report | Sort-Object TamanoMB -Descending | ForEach-Object {
"[$($_.Accion)] [$($_.Riesgo)] $($_.Categoria)
   Ruta:   $($_.Ruta)
   Tamano: $($_.TamanoMB) MB
"
} | Out-String)
"@

$txt | Out-File -FilePath $outTXT -Encoding UTF8

# --- MOSTRAR RESUMEN EN PANTALLA ---
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "   RESUMEN FINAL" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Espacio recuperable directo (LIMPIAR):  $([math]::Round($totalLimpiar,2)) MB" -ForegroundColor Green
Write-Host "Espacio a revisar (REVISAR):             $([math]::Round($totalRevisar,2)) MB" -ForegroundColor Yellow
Write-Host "Papelera (VACIAR):                       $([math]::Round($totalVaciar,2)) MB" -ForegroundColor Red
Write-Host "TOTAL POTENCIAL:                         $([math]::Round($totalGeneral,2)) MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "Top 10 mas pesados:" -ForegroundColor Cyan
$report | Sort-Object TamanoMB -Descending | Select-Object -First 10 | Format-Table Categoria, TamanoMB, Accion, Riesgo -AutoSize
Write-Host ""
Write-Host "Reportes guardados en:" -ForegroundColor Green
Write-Host "  $outCSV" -ForegroundColor White
Write-Host "  $outTXT" -ForegroundColor White
Write-Host ""
Write-Host "Abre el TXT y pegalo a Claude para el analisis completo." -ForegroundColor Cyan
Write-Host ""
Write-Host "Pega el contenido de reporte_limpieza_resultado.txt a Claude para el analisis completo." -ForegroundColor Cyan
