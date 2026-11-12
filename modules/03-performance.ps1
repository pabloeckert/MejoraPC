[CmdletBinding()]
param([switch]$Auto)

# ── MejoraPC — modules/03-performance.ps1 ──────────────────────────
# Aplica todos los tweaks de bajo riesgo automáticamente.
# Cada tweak loguea valor anterior y nuevo en logs/performance-YYYY-MM-DD.log

$scriptRoot = Split-Path -Parent $PSScriptRoot
. "$scriptRoot\lib\helpers.ps1"

$dataFile = "$scriptRoot\data\universal-tweaks.json"
$logDir   = "$scriptRoot\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
$logFile  = Join-Path $logDir "performance-$((Get-Date).ToString('yyyy-MM-dd')).log"

function Write-Log { param([string]$Msg) Add-Content -Path $logFile -Value "$(Get-Date -Format 'HH:mm:ss')  $Msg" -Encoding UTF8 }

function Set-RegTweak {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        $old = $null
        try {
            $prop = Get-ItemProperty -Path $Path -ErrorAction Stop
            if ($prop -and $prop.PSObject.Properties[$Name]) {
                $old = $prop.$Name
            }
        } catch { }
        # -ErrorAction Stop: sin esto, un "acceso denegado" en HKLM (ej. sin admin)
        # es un error NO terminante — cae de largo a las líneas de abajo y reporta
        # OK aunque el valor no se haya escrito. Con Stop, el catch lo agarra bien.
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Log "REG  $Path\$Name : '$old' -> '$Value'"
        Write-Status "$Name" "$old -> $Value" 'OK'
    } catch {
        Write-Log "REG  FAIL $Path\$Name : $_"
        Write-Status "$Name" "error: $_" 'ERROR'
    }
}

if (-not (Test-Path $dataFile)) {
    Write-Host "  [x] No se encuentra data/universal-tweaks.json" -ForegroundColor Red
    return
}
$tweaks = Get-MergedTweaksCatalog -ScriptRoot $scriptRoot

Clear-HostSafe
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         03 - PERFORMANCE + TWEAKS                ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Log "=== INICIO PERFORMANCE ==="

# ── Tweaks de registro agrupados ───────────────────────────────────
foreach ($group in $tweaks.registry.PSObject.Properties) {
    Write-Host "  ── $($group.Name)" -ForegroundColor DarkCyan
    foreach ($t in $group.Value) {
        Set-RegTweak -Path $t.path -Name $t.name -Value $t.value -Type $t.type
    }
    Write-Host ""
}

# ── UserPreferencesMask (animaciones off, binario) ─────────────────
Write-Host "  ── animaciones (UserPreferencesMask)" -ForegroundColor DarkCyan
try {
    $upm = $tweaks.user_preferences_mask
    if (-not (Test-Path $upm.path)) { New-Item -Path $upm.path -Force -ErrorAction Stop | Out-Null }
    $bytes = for ($i = 0; $i -lt $upm.value_hex.Length; $i += 2) { [Convert]::ToByte($upm.value_hex.Substring($i, 2), 16) }
    $old = $null
    try {
        $upmProp = Get-ItemProperty -Path $upm.path -ErrorAction Stop
        if ($upmProp -and $upmProp.PSObject.Properties[$upm.name]) { $old = $upmProp.$($upm.name) }
    } catch { }
    Set-ItemProperty -Path $upm.path -Name $upm.name -Value ([byte[]]$bytes) -Type Binary -Force -ErrorAction Stop
    Write-Log "REG  UserPreferencesMask actualizado (old bytes: $($old -join ','))"
    Write-Status "UserPreferencesMask" "aplicado" 'OK'
} catch { Write-Status "UserPreferencesMask" "error: $_" 'ERROR' }
Write-Host ""

# ── Servicios ──────────────────────────────────────────────────────
Write-Host "  ── servicios" -ForegroundColor DarkCyan
foreach ($svc in $tweaks.services) {
    try {
        $s = Get-Service -Name $svc.name -ErrorAction SilentlyContinue
        if ($s) {
            $oldStart = (Get-CimInstance Win32_Service -Filter "Name='$($svc.name)'" -ErrorAction SilentlyContinue).StartMode
            Set-Service -Name $svc.name -StartupType $svc.action -ErrorAction Stop
            if ($svc.stop -and $s.Status -eq 'Running') { Stop-Service -Name $svc.name -Force -ErrorAction SilentlyContinue }
            Write-Log "SVC  $($svc.name) : $oldStart -> $($svc.action)"
            Write-Status $svc.name "$oldStart -> $($svc.action)" 'OK'
        } else {
            Write-Status $svc.name "no existe" 'INFO'
        }
    } catch { Write-Status $svc.name "error: $_" 'ERROR' }
}
Write-Host ""

# ── Startup items (deshabilitar arranque, no desinstala nada) ──────
Write-Host "  ── startup (arranque con Windows)" -ForegroundColor DarkCyan
foreach ($group in $tweaks.startup_disable.PSObject.Properties) {
    $item  = $group.Value
    $found = $false
    foreach ($rk in $item.run_keys) {
        if (Test-Path $rk) {
            $props = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -match $item.match -or "$($p.Value)" -match $item.match) {
                    $found = $true
                    try {
                        Remove-ItemProperty -Path $rk -Name $p.Name -ErrorAction Stop
                        # Verificar de verdad: releer la key de forma segura sin arrojar excepción si no existe
                        $stillHere = $false
                        try {
                            $recheckProp = Get-ItemProperty -Path $rk -ErrorAction Stop
                            if ($recheckProp -and $recheckProp.PSObject.Properties[$p.Name]) { $stillHere = $true }
                        } catch { }
                        if ($stillHere) {
                            Write-Log "STARTUP  FAIL (sigue presente tras Remove) $rk\$($p.Name)"
                            Write-Status "Run\$($p.Name)" "no se pudo remover (¿admin?)" 'ERROR'
                        } else {
                            Write-Log "STARTUP  removido $rk\$($p.Name)"
                            Write-Status "Run\$($p.Name)" "removido de startup" 'OK'
                        }
                    } catch {
                        Write-Log "STARTUP  FAIL $rk\$($p.Name) : $_"
                        Write-Status "Run\$($p.Name)" "error: $_" 'ERROR'
                    }
                }
            }
        }
    }
    # Scheduled tasks
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match $item.match -and $_.State -ne 'Disabled' } | ForEach-Object {
            # Capturar el objeto ANTES del try/catch: dentro de un catch, $_ pasa
            # a ser el ErrorRecord, no la tarea del pipeline — usar $task adentro.
            $task  = $_
            $found = $true
            # Tareas bajo el perfil de OTRO usuario (TaskPath \...\<SID>\) no se pueden
            # deshabilitar desde esta sesión sin actuar como ese usuario o SYSTEM — Access
            # denied aunque corramos como admin. Si ese SID es una cuenta local deshabilitada
            # (WsiAccount, WDAGUtilityAccount, etc. — nunca inicia sesión), la tarea jamás se
            # ejecuta: no es un fallo real, es no aplicable.
            if ($task.TaskPath -match '(S-1-5-21-[0-9-]+)') {
                $sid = $matches[1]
                try {
                    $acct = Get-LocalUser -SID $sid -ErrorAction Stop
                    if (-not $acct.Enabled) {
                        Write-Log "STARTUP  task $($task.TaskName) en perfil deshabilitado ($($acct.Name)) — no aplica"
                        Write-Status "Task $($task.TaskName)" "perfil deshabilitado ($($acct.Name)) — no aplica" 'INFO'
                        return
                    }
                } catch { }
            }
            try {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
                # Verificar de verdad: releer el estado en vez de confiar en que el cmdlet no tiró error.
                $recheck = Get-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                if ($recheck -and $recheck.State -eq 'Disabled') {
                    Write-Log "STARTUP  task deshabilitada $($task.TaskName)"
                    Write-Status "Task $($task.TaskName)" "deshabilitada" 'OK'
                } else {
                    Write-Log "STARTUP  FAIL (sigue $($recheck.State)) task $($task.TaskName)"
                    Write-Status "Task $($task.TaskName)" "no se pudo deshabilitar (¿admin?)" 'ERROR'
                }
            } catch {
                Write-Log "STARTUP  FAIL task $($task.TaskName) : $_"
                Write-Status "Task $($task.TaskName)" "error: $_" 'ERROR'
            }
        }
    } catch { }
    if (-not $found) { Write-Status $group.Name "no encontrado" 'INFO' }
}
Write-Host ""

# ── Hibernate off ──────────────────────────────────────────────────
Write-Host "  ── energía" -ForegroundColor DarkCyan
try {
    powercfg /h off 2>&1 | Out-Null
    Write-Log "POWER  hibernate off"
    Write-Status "Hibernate" "off (libera espacio SSD)" 'OK'
} catch { Write-Status "Hibernate" "error: $_" 'ERROR' }

# ── Pagefile fijo ──────────────────────────────────────────────────
try {
    $ramMB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $sysDrive = $env:SystemDrive
    $min = [int]($ramMB * $tweaks.power.pagefile_fijo.multiplier_min)
    $max = [int]($ramMB * $tweaks.power.pagefile_fijo.multiplier_max)
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } -ErrorAction SilentlyContinue
    }
    $pf = Get-CimInstance Win32_PageFileSetting -Filter "Name='$sysDrive\\pagefile.sys'" -ErrorAction SilentlyContinue
    if (-not $pf) {
        $pf = New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = "$sysDrive\pagefile.sys" } -ErrorAction SilentlyContinue
    }
    if ($pf) {
        Set-CimInstance -InputObject $pf -Property @{ InitialSize = $min; MaximumSize = $max } -ErrorAction SilentlyContinue
        Write-Log "POWER  pagefile fijo $min-$max MB en $sysDrive"
        Write-Status "Pagefile" "$min-$max MB en $sysDrive" 'OK'
    } else {
        Write-Status "Pagefile" "no se pudo crear setting" 'WARN'
    }
} catch { Write-Status "Pagefile" "error: $_" 'ERROR' }

# ── Ultimate Performance ───────────────────────────────────────────
# Activar o crear el plan "Máximo rendimiento" (Ultimate Performance).
# Se busca primero si ya existe un plan Ultimate Performance en el equipo,
# o se duplica desde la plantilla oficial de Microsoft (tplGuid).
try {
    $tplGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $plansList = powercfg /list 2>&1 | Out-String
    
    # 1) Detectar si ya existe un esquema de Ultimate / Máximo rendimiento
    $existingGuid = $null
    foreach ($line in ($plansList -split "`n")) {
        if ($line -match '(?i)([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s+\((?:Ultimate Performance|M[aá]ximo rendimiento)\)') {
            $existingGuid = $matches[1]
            break
        }
    }

    if ($existingGuid) {
        powercfg /setactive $existingGuid 2>&1 | Out-Null
        Write-Log "POWER  plan existente activado ($existingGuid)"
    } else {
        # 2) El plan no existe: duplicar la plantilla y capturar el GUID nuevo.
        Write-Log "POWER  duplicando plantilla $tplGuid"
        $dupOut = powercfg /duplicatescheme $tplGuid 2>&1 | Out-String
        $m = [regex]::Match($dupOut, '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})')
        if ($m.Success) {
            $newGuid = $m.Groups[1].Value
            powercfg /setactive $newGuid 2>&1 | Out-Null
            Write-Log "POWER  plan duplicado y activado ($newGuid)"

            # Guardar el GUID nuevo en data/status.json.
            $statusFile = "$scriptRoot\data\status.json"
            try {
                if (Test-Path $statusFile) {
                    $status = Get-Content $statusFile -Raw -Encoding UTF8 | ConvertFrom-Json
                } else {
                    $status = [PSCustomObject]@{}
                }
                if ($status.PSObject.Properties['power_plan_guid']) {
                    $status.power_plan_guid = $newGuid
                } else {
                    $status | Add-Member -NotePropertyName 'power_plan_guid' -NotePropertyValue $newGuid -Force
                }
                $status | ConvertTo-Json -Depth 10 | Set-Content -Path $statusFile -Encoding UTF8
                Write-Log "POWER  power_plan_guid guardado en status.json ($newGuid)"
            } catch {
                Write-Log "POWER  FAIL al guardar power_plan_guid en status.json: $_"
            }
        } else {
            Write-Log "POWER  FAIL no se pudo capturar el GUID duplicado: $dupOut"
            Write-Status "Power plan" "no se pudo crear el plan" 'WARN'
        }
    }

    # 3) Verificar el plan activo y loguear el resultado.
    $active = powercfg /getactivescheme 2>&1 | Out-String
    Write-Log "POWER  getactivescheme -> $($active.Trim())"
    Write-Status "Power plan" "activo: $($active.Trim())" 'OK'
} catch { Write-Status "Power plan" "error: $_" 'ERROR' }

# ── Garantía de Sincronización Desatendida (OneDrive) ─────────────
Write-Host ""
Write-Host "  ── sincronización en segundo plano (OneDrive)" -ForegroundColor DarkCyan
$oneDriveProc = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
$oneDriveSync = Get-Process -Name 'OneDrive.Sync.Service' -ErrorAction SilentlyContinue
if ($oneDriveProc) {
    Write-Status "OneDrive Core" "activo (PID $($oneDriveProc.Id), background sync garantizado)" 'OK'
} else {
    Write-Status "OneDrive Core" "no detectado en ejecución" 'WARN'
}
if ($oneDriveSync) {
    Write-Status "OneDrive Sync Service" "activo (PID $($oneDriveSync.Id))" 'OK'
}

Write-Log "=== FIN PERFORMANCE ==="
Write-Host ""
Write-Host "  ── RAM estimada recuperable ──────────────────────" -ForegroundColor Cyan
$e = $tweaks.ram_recoverable_estimate
foreach ($k in $e.PSObject.Properties) {
    if ($k.Name -eq 'total_mb') { continue }
    Write-Host ("  {0,-28} ~{1}MB" -f $k.Name, $k.Value) -ForegroundColor Gray
}
Write-Host "  TOTAL ESTIMADO:              ~$($e.total_mb)MB" -ForegroundColor White
Write-Host ""
Write-Host "  Log: $logFile" -ForegroundColor DarkGray
Write-Host ""
Wait-KeyIfInteractive -Auto:$Auto
