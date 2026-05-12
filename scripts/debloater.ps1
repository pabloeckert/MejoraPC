# ============================================================
# DEBLOATER - Eliminar apps basura de Windows 11
# ============================================================
. "$PSScriptRoot\config.ps1"
Assert-Admin

Write-Header "🗑️ DEBLOATER - ELIMINAR APPS BASURA"

# Lista de apps bloatware seguro de eliminar
$Bloatware = @(
    # Juegos y entretenimiento
    "king.CandyCrushSaga"
    "king.CandyCrushSodaSaga"
    "SpotifyAB.SpotifyMusic"
    "Disney.37853FC22B2CE"
    "Netflix"
    "BytedancePte.Ltd.TikTok"
    "Clipchamp.Clipchamp"
    
    # Apps de Microsoft innecesarias
    "Microsoft.3DBuilder"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.People"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Todos"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.SkypeApp"
    "Microsoft.MixedReality.Portal"
    "MicrosoftTeams"
    "Microsoft.Teams.Free"
    "MSTeams"
    
    # Bloatware de fabricantes
    "Disney.37853FC22B2CE"
    "EclipseManager"
    "PandoraMediaInc"
    "ActiproSoftwareLLC"
    "ClearChannelRadioDigital"
    "SpotifyAB.SpotifyMusic"
    "Fitbit.FitbitCoach"
    "Flipboard.Flipboard"
    "TheNewYorkTimes.NYTCrossword"
    "ThumbmunkeysLtd.PhototasticCollage"
    "TuneIn.TuneInRadio"
    "WinZipComputing.WinZipUniversal"
    "XINGAG.XING"
    "king.com.*"
    "ShazamEntertainmentLtd.Shazam"
    "Duolingo-LearnLanguagesforFree"
    "PandoraMediaInc.29680B314EFC2"
    "C27EB4BA.DropboxOEM"
    "Clipchamp.Clipchamp"
    
    # Widgets y extras
    "Microsoft.Windows.DevHome"
    "Microsoft.BingSearch"
    "Microsoft.Copilot"
    "Microsoft.Windows.Ai.Copilot.Provider"
    "Microsoft.OutlookForWindows"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.549981C3F5F10"  # Cortana
)

# Mostrar qué se va a eliminar
Write-Host "  Apps bloatware detectadas:" -ForegroundColor White
Write-Host ""
$found = @()
foreach ($app in $Bloatware) {
    $packages = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
    if ($packages) {
        foreach ($pkg in $packages) {
            $found += $pkg
            Write-Host "    🗑️  $($pkg.Name)" -ForegroundColor Red
        }
    }
}

if ($found.Count -eq 0) {
    Write-Success "No se encontró bloatware. Tu Windows ya está limpio."
    exit 0
}

Write-Host ""
Write-Host "  Total: $($found.Count) apps encontradas" -ForegroundColor Yellow
Write-Host ""
Write-Warn "Esto va a desinstalar las apps listadas arriba."
Write-Warn "Las apps del sistema (Store, Settings, etc.) NO se tocan."
Write-Host ""
$confirm = Read-Host "  Escribí SI para confirmar"

if ($confirm -ne "SI") {
    Write-Info "Cancelado. No se hizo ningún cambio."
    exit 0
}

Log "Iniciando debloat de $($found.Count) apps"

# Eliminar apps
$removed = 0
$failed = 0

foreach ($pkg in $found) {
    Write-Host "  Eliminando: $($pkg.Name)... " -NoNewline
    try {
        if ($Global:DryRun) {
            Write-Host "DRY-RUN ⏭️" -ForegroundColor Yellow
            $removed++
        } else {
            Get-AppxPackage -Name $pkg.Name -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$($pkg.Name)*" } | 
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            # Validar que se eliminó
            $stillThere = Get-AppxPackage -Name $pkg.Name -AllUsers -ErrorAction SilentlyContinue
            if ($stillThere) {
                Write-Host "⚠️ Parcial" -ForegroundColor Yellow
                $failed++
                Log "WARN: $($pkg.Name) sigue instalado después de intentar eliminar"
            } else {
                Write-Host "✅" -ForegroundColor Green
                $removed++
                Log "Eliminado: $($pkg.Name)"
            }
        }
    } catch {
        Write-Host "❌" -ForegroundColor Red
        $failed++
        Log "Error al eliminar: $($pkg.Name) - $_"
    }
}

Write-Host ""
Write-Success "Completado: $removed eliminadas, $failed errores"
Write-Info "Las apps se pueden restaurar desde Microsoft Store si las necesitás."
Show-LogPath
Log "Debloat completado: $removed eliminadas, $failed errores"
