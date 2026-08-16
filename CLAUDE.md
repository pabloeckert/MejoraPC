# CLAUDE.md — MejoraPC

Sistema de mantenimiento y análisis de Windows 11. Empezó como el perfil
hardcodeado de Pablo; desde 2026-08-08 tiene una capa **universal** (segura
para cualquier PC) separada de la capa **local** (perfil de esta máquina),
más un motor de descubrimiento y un instalador USB para llevarlo a otras
PCs. Suite de módulos PowerShell (optimización) + monitoreo Python
(scan/monitor/analyze/report).

## Perfil de Pablo (esta máquina)
- **RAM: 8GB — crítico.** Toda decisión prioriza liberar RAM.
- Uso: desarrollador full-stack (Claude Code, VSCode, Git, Node, Python 3.14).
- Hijo: Roblox app nativa (BlueStacks y LDPlayer se desinstalan).
- Browsers: Chrome (principal), Brave (testing), Edge (alternativo).
- Monitoreo 100% invisible en background, cero ventanas flash.
- Este perfil vive en `data/profile-local.json` — ver "Capa universal vs
  local" abajo. **No es el único perfil soportado**: en otra PC,
  `modules/00-discover.ps1` genera su propio `profile-local.json`.

## Regla de transcripción de sesión — NO NEGOCIABLE (dogma, 2026-08-09)
Cada vez que se actualiza este archivo (`CLAUDE.md`), actualizar en el mismo
turno `backups/transcripcion-sesion-completa.md` para que quede al día con
toda la conversación de la sesión hasta ese punto. La transcripción va en
texto corrido, sin marcar quién habla en cada momento (ni "usuario:" ni
"asistente:"), incluyendo decisiones, hallazgos y explicaciones en prosa,
más comandos de terminal, JSON crudo de herramientas y outputs técnicos
(git, SQL, curl, etc.) literales, más el código HTML/MD final completo de
cualquier archivo relevante generado en la sesión (no resumido). Adjuntos,
archivos pegados por el usuario e imágenes también se transcriben a texto
dentro del mismo documento. Es una regla recurrente, no una tarea de una
sola vez — se repite en cada sesión donde se toque `CLAUDE.md`.

## Regla de commit/push inmediato — NO NEGOCIABLE (dogma, 2026-08-14)
Todo cambio de código, configuración o documentación (`CLAUDE.md`, módulos
PowerShell, `monitor/*.py`, `data/*.json` trackeados, skills en
`.claude/skills/`, `.gitignore`, etc.) se commitea y se pushea a `origin`
(GitHub, repo **público** `pabloeckert/MejoraPC`) en el mismo turno en que
se termina de escribir — nunca queda como cambio local sin subir. Repo
local y remoto siempre sincronizados.

Excepción explícita, no negociable en el otro sentido: todo lo que ya
estaba (o queda) gitignoreado por contener información personal / huella
de esta máquina específica — `backups/` completo (incluida
`transcripcion-sesion-completa.md`: SID de usuario, inventario de hardware/
software, hábitos de uso), `data/mejorapc.db`, `data/status.json`,
`data/monitor.log`, `data/last-verify.json`, `data/discovery-report.json`,
`profiles/`, `rescue/`, `.claude/settings.local.json`,
`.claude/scheduled_tasks.lock` — sigue sin subirse nunca. El repo es
público; esos archivos son el mismo tipo de dato que `profile-local.json`
ya trata como frontera de seguridad (con la diferencia de que
`profile-local.json` sí se trackea: es curaduría de decisiones, no huella
cruda del sistema). Decisión tomada el 2026-08-14 junto con Pablo, tras
confirmar que el repo es público.

## Regla global de background — NO NEGOCIABLE
- Usar `pythonw.exe` (no `python.exe`) en toda scheduled task.
- Tasks con `-WindowStyle Hidden -ExecutionPolicy Bypass`, sin consola.
- Scripts de background NO escriben a stdout, solo a `data/monitor.log`.
- Si una task falla: loguea silenciosamente, nunca abre ventana de error.
- `run.ps1` y módulos ejecutados manualmente SÍ muestran output.

## Capa universal vs. local — el corazón del diseño de seguridad
El sistema separa qué es seguro tocar en **cualquier** Windows 11 de qué es
específico de una máquina/usuario particular:

- **`data/universal-tweaks.json` / `data/universal-bloatware.json`** —
  bloatware MS Store/OEM y tweaks de performance/privacidad ya probados,
  seguros para cualquier PC. Se aplican siempre, sin preguntar. **Sin
  Bloque B** — riesgo medio, por diseño queda fuera de lo automático para
  una PC ajena.
- **`data/profile-local.json`** — perfil de ESTA máquina: en la de Pablo,
  curado a mano (`registry.vs_telemetria`, `startup_disable.*` de Corel/
  Roblox/Chrome/Canva, `blockA_extra` con lo que Pablo confirmó que no usa,
  `blockB` completo, `keep_always`, `survey`). En una PC ajena, lo genera
  `modules/00-discover.ps1` (encuesta breve). **Nunca viaja en el paquete
  USB** (`installer/build-package.ps1` lo excluye) — es la frontera de
  seguridad completa entre "esta máquina" y "cualquier otra".
- `lib/helpers.ps1::Get-MergedBloatCatalog` / `Get-MergedTweaksCatalog`
  mergean universal + local (si existe) — usadas por `02-debloat.ps1`,
  `03-performance.ps1`, `13-verify.ps1`. Sin `profile-local.json`, el merge
  devuelve solo lo universal: cero riesgo sobre software no reconocido.
- **Principio de seguridad**: el sistema nunca actúa sobre software que no
  reconoce, en ninguna máquina, sin excepción. La personalización viene de
  analizar patrones de uso y de la encuesta post-descubrimiento — nunca de
  tocar algo desconocido.

## Arquitectura
- **Entrada:** `run.ps1` (llamado por `INICIAR.bat` o `Setup.bat` en una PC
  nueva) — **modo automático por defecto**: sin argumentos corre
  `Invoke-AutoOptimize`, un pipeline sin preguntas (descubrimiento →
  monitor invisible → backup → debloat → performance → estética →
  seguridad → python cleanup solo-reporte → análisis inteligente →
  auto-ajuste → verificación real → informe consolidado + dashboard HTML),
  persistiendo cada paso en `applied_actions` (`monitor/record_run.py`). El
  modo automático envuelve toda la corrida en `Start-Transcript`/
  `Stop-Transcript` hacia `logs/ultimo-diagnostico.txt` (encabezado de
  `Get-DiagnosticHeader` + dump de `$Error` al final) — pensado para
  diagnosticar remotamente una PC ajena donde algo sale mal: se adjunta ese
  único archivo. El menú interactivo clásico sigue existiendo detrás de
  `.\run.ps1 -Menu`. `05-rescate.ps1` y `12-workflow-optimizer.ps1` quedan
  siempre fuera del pipeline automático (emergencia / sesión dev, no
  "optimizar").
- **lib/helpers.ps1** — funciones compartidas: `Write-Status`,
  `ConvertTo-HumanReadable`, `Get-MergedBloatCatalog`/`Get-MergedTweaksCatalog`
  (merge universal+local), `Wait-KeyIfInteractive` (reemplaza el ENTER final
  cuando `-Auto`), `Get-DiagnosticHeader` (equipo/OS/PowerShell/Python/build
  para diagnóstico remoto), etc.
- **modules/** — módulos de optimización PowerShell:
  - `00-discover.ps1` — motor de descubrimiento, corre UNA vez por máquina
    (gate: `data/discovery-report.json`). Enumera software instalado,
    clasifica contra el catálogo universal (nunca contra el local), reporta
    lo no reconocido SIN TOCARLO. Encuesta breve (3-5 preguntas generadas
    desde lo encontrado) que escribe contexto a `profile-local.json` — da
    prioridades a las recomendaciones, nunca autoriza tocar lo desconocido.
  - `01-backup.ps1` — restore point + export de claves de registro.
  - `02-debloat.ps1` — Bloque A sin confirmar, Bloque B con UNA confirmación
    (o `-Yes` en modo auto) tras análisis VS/.NET automático (timeout 25s).
  - `03-performance.ps1` — todos los tweaks del catálogo mergeado, loguea
    valor anterior/nuevo. Tabla de RAM recuperable al final es dinámica
    (itera lo que exista en `ram_recoverable_estimate`, no hardcodea claves).
  - `04-estetica.ps1` — efectos visuales.
  - `05-rescate.ps1` — restaurar packages/registry/servicios/power plan.
  - `06-seguridad.ps1` — privacidad/telemetría.
  - `10-python-cleanup.ps1` — conserva 3.14, ofrece eliminar el resto si no
    hay dependencia. **`-Auto` nunca desinstala nada** — solo reporta.
  - `12-workflow-optimizer.ps1` — sesión dev (`-Restore` reactiva Windows Update).
  - `13-verify.ps1` — verificación REAL post-cambio: relee disco/registry/
    servicios directo. Reporta VERIFICADO ✓ / PENDIENTE / FALLIDO ✗, y en
    `-Auto` vuelca contadores a `data/last-verify.json`.
  - `15-hardware-check.ps1` — diagnóstico de hardware y drivers, SOLO
    REPORTA (nunca instala/actualiza nada): salud de disco (SMART/
    reliability), CPU (carga/throttling/errores WHEA), RAM (capacidad/
    errores en Event Log), drivers (antigüedad, dispositivos con problema
    vía `pnputil`, updates disponibles vía `winget upgrade` filtrado a
    fabricantes de driver). Vuelca a `data/last-hardware-check.json`.
    Fuera del pipeline automático de `run.ps1` — lo dispara la rutina
    `mantenimiento` (ver más abajo).
  - `16-startup-audit.ps1` — auditoría de TODO lo que puede arrancar solo,
    más allá del catálogo `startup_disable` clásico (Run keys): carpetas
    Startup, tareas programadas Logon/Boot, Winlogon Shell/Userinit,
    AppInit_DLLs, y StartupTask de apps UWP/Store (`AppModel\
    SystemAppData`, invisible para Run keys — ver `startup_disable_uwp` en
    `profile-local.json`). Reafirma solo lo ya aprobado si "drifeó": reporta
    sin tocar todo lo nuevo. Vuelca a `data/last-startup-audit.json`. Fuera
    del pipeline automático, igual que `15-hardware-check.ps1`.
  - Módulos del pipeline (00,01,03,04,06,10,13) aceptan `-Auto`: sin
    submenú, decisión por defecto, sin ENTER final. `02-debloat.ps1` usa su
    `-Yes` existente (incluye Bloque B — decisión explícita de Pablo).
    `15` y `16` también aceptan `-Auto` pero quedan fuera del pipeline de
    `run.ps1` por defecto (son diagnóstico profundo, no todo runs necesitan
    correrlos) — se disparan desde la rutina `mantenimiento`.
- **monitor/** — Python:
  - `scan.py` — MANUAL, output rich, hardware + alertas, guarda en DB y
    `status.json`. Tabla de RAM recuperable lee universal+local dinámicamente.
  - `monitor.py` — INVISIBLE, sample cada 15min (`--install`/`--uninstall`/`--run`).
  - `analyze.py` — INVISIBLE, semanal dom 3AM. **Motor de reglas**: cada
    regla en la lista `RULES` lee un contexto compartido y devuelve
    `Recommendation`s — agregar una regla es agregar una función a la
    lista. Reglas actuales: hora pico RAM, procesos no-dev consistentes,
    alertas RAM/día, tendencia de RAM (3 scans seguidos a la baja). El
    campo `auto_action` (JSON estructurado) marca qué puede promover
    `auto_adjust.py`.
  - `auto_adjust.py` — promueve recomendaciones ya validadas a
    `profile-local.json` (nunca ejecuta el cambio directo). Solo actúa si
    `profile-local.json` existe en esta máquina, y solo si hay una entrada
    de autoarranque REALMENTE detectable en el registro (vía `winreg`) para
    el proceso candidato — si no hay match real, no promueve nada. En la
    corrida siguiente, `03-performance.ps1` aplica la entrada nueva con su
    mecanismo normal.
  - `report.py` — MANUAL, dashboard rich (consola); delta de RAM + última
    verificación real.
  - `dashboard_data.py` — recolecta datos para el dashboard HTML (queries
    propias, sin acoplarse a `report.py`).
  - `html_report.py` — genera `logs/dashboard.html` (marca Mejora Continua,
    ver `monitor/assets/dashboard.css`) y lo abre en el navegador al final
    del pipeline. Incluye sección "Qué se cambió / Cómo revertir".
  - `record_run.py` — expone `record()` (importable) y CLI; escribe
    `applied_actions` y marca `smart_recommendations.applied`.
- **installer/build-package.ps1** — empaqueta el repo para llevar a otra PC
  (USB, carpeta de OneDrive compartida, etc), excluyendo TODO archivo con
  datos personales de esta máquina (ver lista en el script — se
  auto-verifica que ninguno llegue al paquete, incluidos
  `last-hardware-check.json`/`last-startup-audit.json`). Genera tanto la
  carpeta portable (`dist/MejoraPC-portable/`) como un `.zip`
  (`dist/MejoraPC.zip`) listo para copiar, y escribe
  `data/build-version.txt` (commit de git + fecha de empaquetado) dentro
  del paquete, para saber qué versión corrió al leer un diagnóstico
  enviado desde otra PC. Corre en la PC de Pablo, no se distribuye.
- **Setup.bat** (raíz) — el que se dobleclickea tras descomprimir el zip en
  la PC destino: se auto-eleva, copia a `%LOCALAPPDATA%\MejoraPC`, crea
  acceso directo en el Escritorio, lanza `run.ps1` (dispara descubrimiento +
  encuesta en su primera corrida real).
- **data/** — `universal-tweaks.json`, `universal-bloatware.json`,
  `profile-local.json` (nunca viaja al USB), `mejorapc.db` (SQLite),
  `status.json`, `discovery-report.json`, `last-verify.json`,
  `last-hardware-check.json`, `last-startup-audit.json`, `monitor.log`
  (log de los scripts de background, INVISIBLE).
  `tweaks.json`/`bloatware.json` quedan como legado (reemplazados por la
  capa universal+local), no se borraron todavía.
- **backups/** — `debloat-removed-FECHA.txt`, `.reg`, `python-packages-*.txt`.
- **logs/** — `debloat-FECHA.log`, `performance-FECHA.log`, `ultimo-informe.txt`
  (consola), `dashboard.html` (visual), `hardware-check-FECHA.log`,
  `startup-audit-FECHA.log`, `ultimo-diagnostico.txt` (transcript completo
  de la última corrida automática + errores de PowerShell capturados — para
  adjuntar si algo falla en una PC ajena).

> PowerShell 5.1 no lee SQLite nativamente: los scripts Python escriben además
> un `data/status.json` liviano que `run.ps1` lee para el banner. La DB es la
> fuente de verdad; las recomendaciones pendientes se consultan vía Python.

## Rutina "mantenimiento" (skill, 2026-08-14)
`.claude/skills/mantenimiento/SKILL.md` — se dispara cuando Pablo dice la
palabra "mantenimiento". Es la forma repetible de todo lo que ya hace
`run.ps1` en automático MÁS diagnóstico profundo: corre `15-hardware-check.ps1`
y `16-startup-audit.ps1` (ver arriba), reanaliza cruzando
`last-verify.json`/`last-hardware-check.json`/`last-startup-audit.json`/
`smart_recommendations`, investiga a fondo cualquier hallazgo nuevo (mismo
criterio forense que resolvió el caso Spotify/Firefox/Windows Terminal
reabriéndose solos — ver `startup_disable_uwp` en `profile-local.json`),
aplica lo de bajo riesgo y **propone con una confirmación** lo de riesgo
medio/alto (drivers, hallazgos no reconocidos) — nunca auto-aplica algo así
en silencio. Al cerrar, actualiza memoria de Claude (decisiones tomadas, no
datos crudos — esos ya viven en `mejorapc.db`) para que el próximo
"mantenimiento" no arranque de cero.

## DB (data/mejorapc.db)
`hardware_profile`, `usage_samples`, `ram_alerts`,
`smart_recommendations` (incluye `auto_action` para auto-ajuste),
`applied_actions`. Retención: monitor.py borra registros > 30 días al arrancar.

## Listas — ver data/universal-*.json y data/profile-local.json
Son la fuente de verdad. No hardcodear listas en los módulos ni en analyze.py.

### Conservar siempre en la máquina de Pablo (nunca tocar)
VSCode, Git, GitHub CLI, Node, Bun, Rust, Python 3.14, Android Platform Tools,
JDK 17, CorelDRAW, Audacity, SubtitleEdit, CapCut, Office, WinRAR, Total Commander,
WinSCP, JDownloader, VLC, Spotify, Anthropic.Claude, OneDrive, Ubuntu/WSL,
Windows Terminal, Chrome/Brave/Edge, Roblox, drivers Intel/Bluetooth/Chipset,
AppInstaller (winget), Twinkle Tray, CLEVOCO Fan/Control Center.
(Este listado es específico de `data/profile-local.json` de Pablo — en otra
PC no aplica, esa máquina tiene el suyo propio.)

## Identidad visual — dashboard HTML
`monitor/assets/dashboard.css` aplica el manual de marca de Mejora Continua:
Azul `#1A3D84` (estructura), Rojo `#E1061E` (alerta/fallido), Amarillo
`#F7CC13` (detalle/pendiente), blanco dominante, color como acento nunca
como fondo. Tipografía **League Spartan** (Google Fonts, licencia abierta) —
**no** Bw Modelica (de pago, no se puede redistribuir en un paquete que
viaja a PCs de terceros). Si se actualiza el manual de marca, releer la
skill `mejora-continua-brand` antes de tocar el CSS.

## Convención de UI
Usar `Write-Status -Label -Value -Status OK|WARN|ERROR|INFO` de `lib/helpers.ps1`.
Cabeceras con caja `╔═╗`. Español rioplatense.

## Comandos comunes
No hay build/lint/test formal (sin Pester, sin pytest). "Test" real = `13-verify.ps1`,
que relee el estado del sistema en vez de confiar en el output de otro módulo.

```powershell
.\run.ps1                                   # modo automático (default, correr como admin) — sin menú, informe al final
.\run.ps1 -Menu                             # menú clásico interactivo
.\modules\00-discover.ps1 -Auto              # forzar re-descubrimiento (normalmente corre una sola vez por máquina)
.\modules\02-debloat.ps1                    # correr un módulo suelto directo
.\modules\02-debloat.ps1 -RetryFailed       # reintentar solo los FAIL del último debloat
.\modules\12-workflow-optimizer.ps1 -Restore # revertir sesión dev (reactiva Windows Update)
.\modules\13-verify.ps1                     # verificación real post-cambio
.\modules\14-post-reboot-verify.ps1         # verificación post-reinicio
.\modules\15-hardware-check.ps1 -Auto       # diagnóstico de hardware/drivers (solo reporta)
.\modules\16-startup-audit.ps1 -Auto        # auditoría total de arranque (Run/tasks/UWP StartupTask)
.\installer\build-package.ps1               # empaquetar en carpeta + .zip para otra PC (excluye datos personales, se auto-verifica)

pip install -r monitor/requirements.txt     # psutil, rich, schedule (scan.py autoinstala si faltan)
python monitor\scan.py                      # manual, output rich
python monitor\report.py                    # manual, dashboard consola
python monitor\html_report.py               # manual, dashboard HTML (marca)
python monitor\analyze.py --run             # análisis manual (visible)
python monitor\auto_adjust.py               # promover recomendaciones a profile-local.json (manual)
python monitor\monitor.py --install|--uninstall|--run   # scheduled tasks invisibles (pythonw.exe)
```

## Arquitectura legado — eliminada
La arquitectura anterior (`win-optimizer.ps1`, los scripts numerados de la raíz
`01-startup.ps1` … `09-report.ps1`, la carpeta `scripts/`, y `GEMINI.md`) fue
**eliminada del repo** (2026-08-08). `run.ps1` + `modules/` es la única arquitectura
vigente. Si algo referencia esos nombres, es historial viejo (ver tag
`backup/remote-legacy-20260808`), no código a mantener ni extender.

## Roadmap explícito (no implementado todavía)
- Catálogo universal más exhaustivo (bloat OEM Dell/HP/Lenovo) — requiere
  testing en hardware que Pablo no tiene.
- Auto-ajuste más agresivo (remoción de software, no solo startup) o
  telemetría cruzada entre instalaciones — implica diseño de privacidad
  que hoy no existe.
- GUI nativa en vez de dashboard HTML, si el HTML resulta insuficiente.
- Tracking de uso continuo (hook de foreground de Windows en vez de
  muestreo cada 15 min).
- `Setup.bat` sin firma dispara SmartScreen en máquinas ajenas — aceptable
  para uso personal/cercano, no para distribución amplia.
- Migrar/eliminar `data/tweaks.json` y `data/bloatware.json` (legado, ya
  reemplazados por la capa universal+local) una vez confirmado que nada
  más los referencia.
