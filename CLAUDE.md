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
- **Entrada:** `run.ps1` — menú con banner (ASCII art + estado desde `data/status.json`).
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
- **monitor/** — Python:
  - `scan.py` — MANUAL, output rich, hardware + alertas, guarda en DB y `status.json`.
  - `monitor.py` — INVISIBLE, sample cada 15min (`--install`/`--uninstall`/`--run`).
  - `analyze.py` — INVISIBLE, semanal dom 3AM, genera `smart_recommendations` (`--run` visible).
  - `report.py` — MANUAL, dashboard rich.
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
