# CLAUDE.md — MejoraPC

Optimizador de Windows 11 para el **perfil definitivo de Pablo**. Suite de
módulos PowerShell (optimización) + monitoreo Python (scan/monitor/analyze/report).

## Perfil definitivo — Pablo
- **RAM: 8GB — crítico.** Toda decisión prioriza liberar RAM.
- Uso: desarrollador full-stack (Claude Code, VSCode, Git, Node, Python 3.14).
- Hijo: Roblox app nativa (BlueStacks y LDPlayer se desinstalan).
- Browsers: Chrome (principal), Brave (testing), Edge (alternativo).
- **Un solo perfil de debloat** — sin menús de perfil, sin opciones.
- Monitoreo 100% invisible en background, cero ventanas flash.

## Regla global de background — NO NEGOCIABLE
- Usar `pythonw.exe` (no `python.exe`) en toda scheduled task.
- Tasks con `-WindowStyle Hidden -ExecutionPolicy Bypass`, sin consola.
- Scripts de background NO escriben a stdout, solo a `data/monitor.log`.
- Si una task falla: loguea silenciosamente, nunca abre ventana de error.
- `run.ps1` y módulos ejecutados manualmente SÍ muestran output.

## Arquitectura
- **Entrada:** `run.ps1` (llamado por `INICIAR.bat`) — **modo automático por
  defecto**: sin argumentos corre `Invoke-AutoOptimize`, un pipeline sin
  preguntas (backup → debloat → performance → estética → seguridad → python
  cleanup solo-reporte → verificación real → informe consolidado vía
  `report.py`), persistiendo cada paso en `applied_actions`
  (`monitor/record_run.py`). El menú interactivo clásico con banner (ASCII
  art + estado desde `data/status.json`) sigue existiendo detrás de
  `.\run.ps1 -Menu`, para control manual módulo por módulo. `05-rescate.ps1`
  y `12-workflow-optimizer.ps1` quedan siempre fuera del pipeline automático
  (emergencia / sesión dev, no "optimizar") — se invocan directo.
- **lib/helpers.ps1** — funciones compartidas (`Write-Status`, `ConvertTo-HumanReadable`, etc.).
- **modules/** — módulos de optimización PowerShell:
  - `01-backup.ps1` — restore point + export de claves de registro.
  - `02-debloat.ps1` — un solo perfil; Bloque A sin confirmar, Bloque B con UNA confirmación tras análisis VS/.NET automático.
  - `03-performance.ps1` — todos los tweaks de `data/tweaks.json`, loguea valor anterior/nuevo.
  - `04-estetica.ps1` — efectos visuales.
  - `05-rescate.ps1` — restaurar packages/registry/servicios/power plan.
  - `06-seguridad.ps1` — privacidad/telemetría.
  - `10-python-cleanup.ps1` — conserva 3.14, ofrece eliminar el resto si no hay dependencia.
  - `12-workflow-optimizer.ps1` — sesión dev (`-Restore` reactiva Windows Update).
  - `13-verify.ps1` — verificación REAL post-cambio: relee disco/registry/servicios directo (nunca confía en lo que reportaron los otros módulos). Reporta VERIFICADO ✓ / PENDIENTE / FALLIDO ✗ por ítem, y en `-Auto` vuelca los contadores a `data/last-verify.json` (lo lee `report.py`).
  - Todos los módulos del pipeline (01,03,04,06,10,13) aceptan `-Auto`: sin submenú, decisión por defecto, sin ENTER final (`Wait-KeyIfInteractive` en `lib/helpers.ps1`). `02-debloat.ps1` usa su `-Yes` existente (incluye Bloque B). `10-python-cleanup.ps1 -Auto` **nunca desinstala nada** — solo reporta candidatos.
- **monitor/** — Python:
  - `scan.py` — MANUAL, output rich, hardware + alertas, guarda en DB y `status.json`.
  - `monitor.py` — INVISIBLE, sample cada 15min (`--install`/`--uninstall`/`--run`).
  - `analyze.py` — INVISIBLE, semanal dom 3AM, genera `smart_recommendations` (`--run` visible).
  - `report.py` — MANUAL, dashboard rich; incluye delta de RAM (últimas 2 filas de `hardware_profile`) y última verificación real (`data/last-verify.json`).
  - `record_run.py` — escribe `applied_actions` y marca `smart_recommendations.applied`, llamado por `Invoke-AutoOptimize` en `run.ps1`.
- **data/** — `bloatware.json` (lista definitiva), `tweaks.json`, `mejorapc.db` (SQLite), `status.json`.
- **backups/** — `debloat-removed-FECHA.txt`, `.reg`, `python-packages-*.txt`.
- **logs/** — `debloat-FECHA.log`, `performance-FECHA.log`.

> PowerShell 5.1 no lee SQLite nativamente: los scripts Python escriben además
> un `data/status.json` liviano que `run.ps1` lee para el banner. La DB es la
> fuente de verdad; las recomendaciones pendientes se consultan vía Python.

## DB (data/mejorapc.db)
`hardware_profile`, `usage_samples`, `ram_alerts`, `smart_recommendations`, `applied_actions`.
Retención: monitor.py borra registros > 30 días al arrancar.

## Listas — ver data/bloatware.json y data/tweaks.json
Son la fuente de verdad. No hardcodear listas en los módulos.

### Conservar siempre (nunca tocar)
VSCode, Git, GitHub CLI, Node, Bun, Rust, Python 3.14, Android Platform Tools,
JDK 17, CorelDRAW, Audacity, SubtitleEdit, CapCut, Office, WinRAR, Total Commander,
WinSCP, JDownloader, VLC, Spotify, Anthropic.Claude, OneDrive, Ubuntu/WSL,
Windows Terminal, Chrome/Brave/Edge, Roblox, drivers Intel/Bluetooth/Chipset,
AppInstaller (winget), Twinkle Tray, CLEVOCO Fan/Control Center.

## Convención de UI
Usar `Write-Status -Label -Value -Status OK|WARN|ERROR|INFO` de `lib/helpers.ps1`.
Cabeceras con caja `╔═╗`. Español rioplatense.

## Comandos comunes
No hay build/lint/test formal (sin Pester, sin pytest). "Test" real = `13-verify.ps1`,
que relee el estado del sistema en vez de confiar en el output de otro módulo.

```powershell
.\run.ps1                                   # modo automático (default, correr como admin) — sin menú, informe al final
.\run.ps1 -Menu                             # menú clásico interactivo
.\modules\02-debloat.ps1                    # correr un módulo suelto directo
.\modules\02-debloat.ps1 -RetryFailed       # reintentar solo los FAIL del último debloat
.\modules\12-workflow-optimizer.ps1 -Restore # revertir sesión dev (reactiva Windows Update)
.\modules\13-verify.ps1                     # verificación real post-cambio
.\modules\14-post-reboot-verify.ps1         # verificación post-reinicio

pip install -r monitor/requirements.txt     # psutil, rich, schedule (scan.py autoinstala si faltan)
python monitor\scan.py                      # manual, output rich
python monitor\report.py                    # manual, dashboard
python monitor\analyze.py --run             # análisis manual (visible)
python monitor\monitor.py --install|--uninstall|--run   # scheduled tasks invisibles (pythonw.exe)
```

## Arquitectura legado — eliminada
La arquitectura anterior (`win-optimizer.ps1`, los scripts numerados de la raíz
`01-startup.ps1` … `09-report.ps1`, la carpeta `scripts/`, y `GEMINI.md`) fue
**eliminada del repo** (2026-08-08). `run.ps1` + `modules/` es la única arquitectura
vigente. Si algo referencia esos nombres, es historial viejo (ver tag
`backup/remote-legacy-20260808`), no código a mantener ni extender.
