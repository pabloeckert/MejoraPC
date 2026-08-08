# 🔧 MejoraPC — perfil definitivo

**Optimizador de Windows 11 hecho a medida para 8GB de RAM y flujo de desarrollo
full-stack.** Un solo perfil, sin menús de perfil, todo reversible. Monitoreo de
fondo 100% invisible.

> Notebook objetivo: BANGHO MAX L5 (i7-10510U, 8GB RAM). Funciona en cualquier
> Windows 11.

---

## ⚡ Uso

```powershell
# Click derecho en INICIAR.bat → Ejecutar como administrador
# o directamente:
.\run.ps1
```

Sin argumentos, `run.ps1` corre en **modo automático**: no pregunta nada,
ejecuta el pipeline completo de optimización (backup → debloat → performance →
estética → seguridad → python cleanup solo-reporte → verificación real) con el
output de cada paso visible en pantalla, y termina con un informe consolidado
(`monitor/report.py`). Cada corrida queda registrada en la base de datos
(`data/mejorapc.db`, tabla `applied_actions`).

```powershell
.\run.ps1 -Menu   # menú clásico interactivo, para control manual módulo por módulo
```

## 🖥️ Menú manual (`-Menu`)

```
  ── OPTIMIZACIÓN ──
   1  Backup
   2  Debloat
   3  Performance + tweaks
   4  Estética
   5  Rescate / Restaurar
   6  Seguridad
  ── MONITOREO ──
   7  Scan hardware
   8  Dashboard
   9  Análisis inteligente
  ── DESARROLLO ──
  10  Python cleanup
  11  Workflow optimizer (sesión dev)
  12  Instalar monitor background
  13  Verificación real del sistema
  14  Verificación post-reinicio (manual)
   0  Salir
```

El banner muestra `RAM libre / total | Score | Último scan` y avisa si la
memoria está crítica (<2.5GB) o si hay recomendaciones inteligentes pendientes.

## 🧩 Qué hace cada opción

| # | Módulo | Descripción |
|---|--------|-------------|
| 1 | `modules/01-backup.ps1` | Punto de restauración + export de claves de registro |
| 2 | `modules/02-debloat.ps1` | **Un solo perfil.** Bloque A sin confirmar, Bloque B con UNA confirmación tras análisis automático de dependencias VS/.NET en `C:\Github\` |
| 3 | `modules/03-performance.ps1` | Game Bar off, browsers background off, animaciones off, Superfetch off, Search manual, hibernate off, pagefile fijo, Ultimate Performance, CorelUpdateHelper off |
| 4 | `modules/04-estetica.ps1` | Efectos visuales (rendimiento/equilibrado/default) |
| 5 | `modules/05-rescate.ps1` | Reinstala packages, restaura registry/servicios/power plan |
| 6 | `modules/06-seguridad.ps1` | Telemetría, publicidad y seguimiento off |
| 7 | `monitor/scan.py` | Escaneo de hardware + alertas del perfil (RAM, ollama, emuladores, browsers, Python) |
| 8 | `monitor/report.py` | Dashboard: hardware, RAM 24h, top procesos, recomendaciones, score |
| 9 | `monitor/analyze.py --run` | Análisis inteligente de la última semana |
| 10 | `modules/10-python-cleanup.ps1` | Conserva Python 3.14, ofrece eliminar el resto si no hay dependencia |
| 11 | `modules/12-workflow-optimizer.ps1` | Sesión dev: limpia TEMP, pausa Windows Update, mata update checkers (`-Restore` revierte) |
| 12 | `monitor/monitor.py --install` | Scheduled tasks **invisibles** (sample 15min + análisis semanal) |
| 13 | `modules/13-verify.ps1` | Verificación real: relee disco/registry/servicios en vez de confiar en lo que reportaron los otros módulos |
| 14 | `modules/14-post-reboot-verify.ps1` | Corre la verificación tras reiniciar; se auto-borra de la scheduled task si fue disparado por ella |

## 👤 Perfil definitivo

- **RAM 8GB — crítico.** Toda decisión prioriza liberar RAM.
- Desarrollador full-stack: Claude Code, VSCode, Git, Node, Python 3.14.
- Hijo: Roblox nativo (BlueStacks/LDPlayer se desinstalan).
- Browsers: Chrome (principal), Brave, Edge.

**Se conserva siempre:** VSCode, Git, GitHub CLI, Node, Bun, Rust, Python 3.14,
Android Platform Tools, JDK 17, CorelDRAW, Office, WinRAR, Total Commander,
WinSCP, JDownloader, VLC, Spotify, Claude, OneDrive, Ubuntu/WSL, Windows
Terminal, Chrome/Brave/Edge, Roblox, drivers Intel, Twinkle Tray, CLEVOCO.

Listas completas en [`data/bloatware.json`](data/bloatware.json) y
[`data/tweaks.json`](data/tweaks.json).

## 🕶️ Monitoreo invisible

Las tasks de fondo usan `pythonw.exe -WindowStyle Hidden`: cero ventanas, todo a
`data/monitor.log`. Datos en SQLite (`data/mejorapc.db`), retención 30 días.

```powershell
python monitor/monitor.py --install      # sample cada 15 min
python monitor/analyze.py --install      # análisis semanal (dom 3AM)
python monitor/monitor.py --uninstall    # quitar
```

## 🐍 Dependencias Python

```powershell
pip install -r monitor/requirements.txt   # psutil, rich, schedule
```

`scan.py` autoinstala `psutil`/`rich` si faltan.

## 🛡️ Seguridad

- Backup (opción 1) antes de cambios; restauración completa en opción 5.
- No toca Windows Defender, VBS ni BitLocker.
- Logs por operación en `logs/`, IDs eliminados en `backups/`.

## Licencia

MIT.
