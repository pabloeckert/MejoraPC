# ============================================================
# STARTUP CLEANER - Limpiar programas de inicio
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "⚡ STARTUP CLEANER"

# Programas de inicio conocidos que se pueden desactivar
$SafeToDisable = @(
    "OneDrive",
    "MicrosoftEdgeAutoLaunch",
    "Spotify",
    "Discord",
    "Steam",
    "EpicGamesLauncher",
    "CCXProcess",
    "AdobeGCInvoker",
    "AdobeAAMUpdater",
    "GoogleDriveSync",
    "BraveSoftware",
    "Opera Browser",
    "iTunesHelper",
    "Skype",
    "Teams",
    "Cortana",
    "Copilot",
    "Clipchamp",
    "WidgetService",
    "Widgets",
    "HP",
    "Canon",
    "Epson",
    "Intel",
    "NVIDIA",
    "AMD",
    "Realtek"
)

Write-Host "  Analizando programas de inicio..." -ForegroundColor White
Write-Host ""

# Recopilar de todas las fuentes
$startupItems = @()

# 1. Carpeta Startup
$startupFolder = [Environment]::GetFolderPath("Startup")
$commonStartup = [Environment]::GetFolderPath("CommonStartup")
foreach ($folder in @($startupFolder, $commonStartup)) {
    if (Test-Path $folder) {
        Get-ChildItem $folder -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            $startupItems += [PSCustomObject]@{
                Name = $_.BaseName
                Source = "Startup Folder"
                Path = $_.FullName
                Type = "File"
            }
        }
    }
}

# 2. Registry HKCU Run
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

foreach ($regPath in $regPaths) {
    $props = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
    if ($props) {
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
            $startupItems += [PSCustomObject]@{
                Name = $_.Name
                Source = "Registry ($regPath)"
                Path = $_.Value
                Type = "Registry"
            }
        }
    }
}

# 3. Task Scheduler
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne "Disabled" } | ForEach-Object {
    if ($_.TaskPath -notmatch "\\Microsoft\\") {
        $startupItems += [PSCustomObject]@{
            Name = $_.TaskName
            Source = "Task Scheduler"
            Path = $_.TaskPath
            Type = "Task"
        }
    }
}

# Mostrar items encontrados
Write-Host "  Programas de inicio encontrados:" -ForegroundColor White
Write-Host ""

$categorized = @()
foreach ($item in $startupItems) {
    $isSafe = $false
    foreach ($pattern in $SafeToDisable) {
        if ($item.Name -match $pattern) {
            $isSafe = $true
            break
        }
    }
    $categorized += [PSCustomObject]@{
        Name = $item.Name
        Source = $item.Source
        Path = $item.Path
        Type = $item.Type
        SafeToDisable = $isSafe
    }
}

# Mostrar safe to disable
$safeItems = $categorized | Where-Object { $_.SafeToDisable }
$otherItems = $categorized | Where-Object { !$_.SafeToDisable }

if ($safeItems.Count -gt 0) {
    Write-Host "  ✅ Seguro de desactivar:" -ForegroundColor Green
    foreach ($item in $safeItems) {
        Write-Host "    • $($item.Name) ($($item.Source))" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($otherItems.Count -gt 0) {
    Write-Host "  ⚠️  Otros (revisar antes de desactivar):" -ForegroundColor DarkYellow
    foreach ($item in $otherItems) {
        Write-Host "    • $($item.Name) ($($item.Source))" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($safeItems.Count -eq 0) {
    Write-Success "No hay programas innecesarios en inicio."
    exit 0
}

Write-Host "  ¿Qué querés hacer?" -ForegroundColor White
Write-Host "    [1] Desactivar solo los seguros ($($safeItems.Count) items)" -ForegroundColor Green
Write-Host "    [2] Desactivar TODO (revisar lista primero)" -ForegroundColor Yellow
Write-Host "    [0] Cancelar" -ForegroundColor Red
Write-Host ""
$choice = Read-Host "  Opción"

if ($choice -eq "0") {
    Write-Info "Cancelado."
    exit 0
}

$toDisable = if ($choice -eq "2") { $categorized } else { $safeItems }
$disabled = 0

foreach ($item in $toDisable) {
    Write-Host "  Desactivando: $($item.Name)... " -NoNewline
    try {
        switch ($item.Type) {
            "File" {
                $backupDir = Join-Path (Split-Path $item.Path) ".disabled"
                if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                Move-Item $item.Path (Join-Path $backupDir (Split-Path $item.Path -Leaf)) -ErrorAction Stop
            }
            "Registry" {
                $regKey = if ($item.Source -match "HKCU") { "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" } else { "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
                Remove-ItemProperty -Path $regKey -Name $item.Name -ErrorAction Stop
            }
            "Task" {
                Disable-ScheduledTask -TaskName $item.Name -ErrorAction Stop | Out-Null
            }
        }
        Write-Host "✅" -ForegroundColor Green
        $disabled++
        Log "Startup desactivado: $($item.Name)"
    } catch {
        Write-Host "❌" -ForegroundColor Red
        Log "Error al desactivar startup: $($item.Name) - $_"
    }
}

Write-Host ""
Write-Success "$disabled programas desactivados del inicio."
Write-Info "Reiniciá para ver el efecto."
Log "Startup clean completado: $disabled items desactivados"
