# ============================================================
# NOTIFICATIONS - Notificaciones de Windows (Toast)
# ============================================================
# Muestra notificaciones toast en Windows 10/11.
# Útil para: alertas de rendimiento, recordatorios, estado.
# ============================================================

param(
    [string]$Title = "MejoraNotebook",
    [string]$Message = "Notificación de prueba",
    [string]$Icon = "info",
    [int]$Duration = 5
)

. "$PSScriptRoot\config.ps1"

function Show-Toast {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Icon = "info",
        [int]$Duration = 5
    )
    
    try {
        # Cargar assemblies necesarios
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        
        # Seleccionar icono
        $iconUri = switch ($Icon) {
            "success" { "✅" }
            "warning" { "⚠️" }
            "error"   { "❌" }
            "fire"    { "🔥" }
            "game"    { "🎮" }
            "globe"   { "🌐" }
            "chart"   { "📊" }
            default   { "ℹ️" }
        }
        
        # Crear XML del toast
        $template = @"
<toast duration="$([System.Math]::Min($Duration, 25))">
    <visual>
        <binding template="ToastGeneric">
            <text>$iconUri $Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
        
        # Crear y mostrar notificación
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        
        $app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $toast = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app)
        $notification = [Windows.UI.Notifications.ToastNotification]::new($xml)
        $toast.Show($notification)
        
        return $true
    } catch {
        # Fallback: usar msg.exe (funciona en todas las versiones)
        try {
            $durationSec = [System.Math]::Min($Duration, 120)
            msg.exe /TIME:$durationSec * "$iconUri $Title - $Message" 2>&1 | Out-Null
            return $true
        } catch {
            return $false
        }
    }
}

function Show-SystemAlert {
    param(
        [string]$Type,
        [hashtable]$Data
    )
    
    switch ($Type) {
        "ram_high" {
            Show-Toast -Title "⚠️ RAM Alta" -Message "RAM al $($Data.Percent)% — Cerrá apps o ejecutá Memory Optimizer" -Icon "warning"
        }
        "cpu_high" {
            Show-Toast -Title "⚠️ CPU Alta" -Message "CPU al $($Data.Load)% — Cerrá procesos pesados" -Icon "warning"
        }
        "disk_full" {
            Show-Toast -Title "⚠️ Disco Lleno" -Message "Disco al $($Data.Percent)% — Ejecutá Disk Cleanup" -Icon "warning"
        }
        "turbo_active" {
            Show-Toast -Title "🔥 Turbo Boost" -Message "Modo máximo rendimiento activado" -Icon "fire"
        }
        "turbo_revert" {
            Show-Toast -Title "🔄 Turbo Boost" -Message "Modo normal restaurado" -Icon "success"
        }
        "gaming_active" {
            Show-Toast -Title "🎮 Gaming Mode" -Message "Optimizado para gaming" -Icon "game"
        }
        "gaming_revert" {
            Show-Toast -Title "🔄 Gaming Mode" -Message "Modo normal restaurado" -Icon "success"
        }
        "update_available" {
            Show-Toast -Title "📥 Actualización" -Message "MejoraNotebook v$($Data.Version) disponible" -Icon "info"
        }
        "benchmark_done" {
            Show-Toast -Title "📊 Benchmark" -Message "Diagnóstico completado — RAM: $($Data.RAM)%, CPU: $($Data.CPU)%" -Icon "chart"
        }
        "network_optimized" {
            Show-Toast -Title "🌐 Red Optimizada" -Message "TCP/DNS/latencia optimizados" -Icon "globe"
        }
        "wu_blocked" {
            Show-Toast -Title "🔒 Windows Update" -Message "Actualizaciones bloqueadas temporalmente" -Icon "warning"
        }
        "wu_unblocked" {
            Show-Toast -Title "🔓 Windows Update" -Message "Actualizaciones reactivadas" -Icon "success"
        }
        default {
            Show-Toast -Title "MejoraNotebook" -Message $Type -Icon "info"
        }
    }
}

# ============================================================
# MAIN (ejecución directa)
# ============================================================
if ($Title -ne "MejoraNotebook" -or $Message -ne "Notificación de prueba") {
    # Parámetros personalizados
    Show-Toast -Title $Title -Message $Message -Icon $Icon -Duration $Duration
} else {
    # Demo
    Write-Header "🔔 NOTIFICACIONES"
    Write-Host "  Probando notificaciones de Windows..." -ForegroundColor White
    Write-Host ""
    
    $result = Show-Toast -Title "¡Funciona!" -Message "Las notificaciones están configuradas correctamente" -Icon "success"
    
    if ($result) {
        Write-Success "Notificación enviada. ¿La viste?"
    } else {
        Write-Warn "No se pudo enviar la notificación."
        Write-Info "Las notificaciones pueden estar desactivadas en Windows."
    }
    
    Write-Host ""
    Write-Info "Uso: .\notifications.ps1 -Title 'Título' -Message 'Mensaje' -Icon 'success'"
    Write-Info "Iconos: info, success, warning, error, fire, game, globe, chart"
}
