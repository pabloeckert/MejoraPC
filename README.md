# 🔧 MejoraPC

**Sistema de mantenimiento y análisis de Windows 11.** Escanea tu PC, aplica
lo que es seguro para cualquier equipo, aprende de tu uso, y te muestra un
informe visual — todo sin menús ni confirmaciones. Empaquetable en USB para
llevarlo a otra PC.

> Desarrollado sobre una BANGHO MAX L5 (i7-10510U, 8GB RAM). Funciona en
> cualquier Windows 11.

---

## ⚡ Uso

```powershell
# Click derecho en INICIAR.bat → Ejecutar como administrador
# o directamente:
.\run.ps1
```

Sin argumentos, `run.ps1` corre en **modo automático**: no pregunta nada
(salvo una encuesta breve la primera vez en una PC nueva), escanea, aplica
lo que es seguro para cualquier equipo, analiza tu uso, y termina con un
**dashboard visual** que se abre solo en el navegador. Cada corrida queda
registrada en la base de datos (`data/mejorapc.db`).

```powershell
.\run.ps1 -Menu   # menú clásico interactivo, para control manual módulo por módulo
```

## 🧠 Cómo decide qué tocar

El sistema separa dos capas:

- **Universal** (`data/universal-*.json`) — bloatware MS Store/OEM y tweaks
  de performance/privacidad seguros para **cualquier** Windows 11. Se
  aplican siempre, sin preguntar.
- **Local** (`data/profile-local.json`) — el perfil de tu máquina. En una
  PC nueva lo genera `modules/00-discover.ps1`: escanea el equipo, clasifica
  lo que reconoce contra el catálogo universal, y **deja todo lo demás
  intacto, siempre** — nunca toca software que no reconoce. Una encuesta
  breve (3-5 preguntas, generadas a partir de lo que encontró) da contexto
  para priorizar recomendaciones futuras.

Con el uso, `monitor/analyze.py` detecta patrones (procesos que consumen
RAM seguido, horas pico, tendencias) y `monitor/auto_adjust.py` promueve las
recomendaciones ya validadas al perfil local — se aplican en la corrida
siguiente, con el mismo mecanismo verificado de siempre.

## 💾 Llevarlo a otra PC (USB, OneDrive, lo que sea)

```powershell
.\installer\build-package.ps1   # genera dist/MejoraPC-portable/ y dist/MejoraPC.zip (excluye tus datos personales)
```

Copiá `dist/MejoraPC.zip` a la PC destino por el medio que quieras — USB,
una carpeta de OneDrive compartida, lo que sea. Ahí: descomprimilo y
doble-click en `Setup.bat` (se auto-eleva a administrador, instala en
`%LOCALAPPDATA%\MejoraPC`, crea acceso directo, y arranca solo: escanea esa
PC, hace una encuesta breve, optimiza, e instala el monitor invisible para
aprender de esa máquina en adelante).

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
| — | `modules/00-discover.ps1` | Descubrimiento (una vez por máquina): escanea software instalado, clasifica contra el catálogo universal, encuesta breve |
| 1 | `modules/01-backup.ps1` | Punto de restauración + export de claves de registro |
| 2 | `modules/02-debloat.ps1` | Bloque A sin confirmar, Bloque B con UNA confirmación (o automático en modo `-Auto`) tras análisis de dependencias VS/.NET |
| 3 | `modules/03-performance.ps1` | Game Bar off, browsers background off, animaciones off, Superfetch off, Search manual, hibernate off, pagefile fijo, Ultimate Performance |
| 4 | `modules/04-estetica.ps1` | Efectos visuales (rendimiento/equilibrado/default) |
| 5 | `modules/05-rescate.ps1` | Reinstala packages, restaura registry/servicios/power plan |
| 6 | `modules/06-seguridad.ps1` | Telemetría, publicidad y seguimiento off |
| 7 | `monitor/scan.py` | Escaneo de hardware + alertas del perfil |
| 8 | `monitor/report.py` | Dashboard de consola: hardware, RAM 24h, top procesos, recomendaciones, score |
| — | `monitor/html_report.py` | Dashboard visual (HTML, marca Mejora Continua) — se abre solo al final del modo automático |
| 9 | `monitor/analyze.py --run` | Motor de reglas: hora pico, procesos no-dev consistentes, alertas de RAM, tendencia de RAM |
| — | `monitor/auto_adjust.py` | Promueve recomendaciones validadas al perfil local (nunca ejecuta el cambio directo) |
| 10 | `modules/10-python-cleanup.ps1` | Conserva Python 3.14, ofrece eliminar el resto si no hay dependencia (`-Auto` nunca desinstala, solo reporta) |
| 11 | `modules/12-workflow-optimizer.ps1` | Sesión dev: limpia TEMP, pausa Windows Update, mata update checkers (`-Restore` revierte) |
| 12 | `monitor/monitor.py --install` | Scheduled tasks **invisibles** (sample 15min + análisis semanal) |
| 13 | `modules/13-verify.ps1` | Verificación real: relee disco/registry/servicios en vez de confiar en lo que reportaron los otros módulos |
| 14 | `modules/14-post-reboot-verify.ps1` | Corre la verificación tras reiniciar; se auto-borra de la scheduled task si fue disparado por ella |

## 👤 Perfil local (esta máquina)

`data/profile-local.json` **nunca viaja en el paquete USB** — es la
frontera de seguridad entre "esta PC" y cualquier otra. En esta máquina
(Pablo): 8GB RAM crítico, dev full-stack (Claude Code, VSCode, Git, Node,
Python 3.14), hijo con Roblox nativo, browsers Chrome/Brave/Edge.

Catálogo universal (cualquier PC) en
[`data/universal-bloatware.json`](data/universal-bloatware.json) y
[`data/universal-tweaks.json`](data/universal-tweaks.json). Perfil local en
`data/profile-local.json` (no se commitea el de cada PC ajena).

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

- Backup (opción 1) antes de cualquier cambio; restauración completa en opción 5.
- El sistema **nunca actúa sobre software que no reconoce**, en ninguna PC.
- No toca Windows Defender, VBS ni BitLocker.
- Logs por operación en `logs/`, IDs eliminados en `backups/`.

## Licencia

MIT.
