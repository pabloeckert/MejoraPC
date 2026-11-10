# GEMINI.md — Gobernanza Técnica y Arquitectura de MejoraPC

Sistema de mantenimiento preventivo, debloat en 3 capas, optimización de kernel y telemetría silenciosa con aprendizaje continuo para Windows 11. Estandarizado bajo **Google Antigravity** y **Gemini** siguiendo el protocolo **Zero-Trust Principal Engineer**.

---

## 1. Perfil del Equipo Principal (Pablo)
- **Hardware base:** Banghó Max L5 (Intel Core i7-10510U @ 1.80GHz - 2.30 GHz, 4 núcleos físicos / 8 lógicos).
- **Memoria RAM:** **16 GB RAM** instalados (15.8 GB utilizables por reserva de BIOS/hardware).
- **Gráficos:** Intel(R) UHD Graphics (Driver 31.0.101.2145).
- **Almacenamiento:** SSD NVMe 466 GB (C:\ ~160 GB usado de 466 GB, 304 GB libres).
- **Sistema Operativo:** Windows 11 Pro 64 bits, **Versión 26H2** (Compilación 26300.9974, instalada el 25/09/2026, Paquete de experiencia 1000.26100.385.0).
- **Entorno de uso:** Desarrollo full-stack (Google Antigravity IDE, VSCode, Git, Node, Bun, Rust, Python 3.14, WSL/Ubuntu), diseño (CorelDRAW 2026), productividad IA (Speechify, Gemini Desktop) y uso familiar (Roblox nativo).
- **Navegadores activos:** Google Chrome, Brave y Microsoft Edge.
- **Monitoreo:** 100% silencioso en segundo plano (`pythonw.exe`), cero ventanas emergentes.

---

## 2. Arquitectura de Seguridad: Capa Universal vs. Capa Local

El corazón del diseño separa estrictamente qué es seguro aplicar en **cualquier** Windows 11 de qué es específico de una máquina particular:

1. **Catálogo Universal (`data/universal-bloatware.json` y `data/universal-tweaks.json`):**
   - Bloatware de MS Store/OEM y ajustes de rendimiento/privacidad de bajo riesgo probados para cualquier PC con Windows 11.
   - Se aplican sin preguntar. No incluyen el `Bloque B` (riesgo medio).
2. **Perfil Local (`data/profile-local.json`):**
   - Configuración específica de esta máquina (`registry.vs_telemetria`, `startup_disable`, `startup_disable_uwp`, `startup_audit_reconocidos`, `auto_adjust_declined`, `blockA_extra`, `blockB`, `keep_always` y `survey`).
   - **Frontera de aislamiento:** Nunca viaja en el paquete portable USB (`installer/build-package.ps1` lo excluye y verifica que no se filtre). En una PC ajena, `modules/00-discover.ps1` genera su propio `profile-local.json` a partir del inventario local.
3. **Principio Inviolable:**
   - El sistema **nunca actúa sobre software que no reconoce**, en ninguna máquina. Todo software fuera del catálogo universal o del perfil local explícito permanece intacto.

---

## 3. Mapa del Sistema

### Raíz y Orquestación
- `run.ps1`: Punto de entrada único.
  - Sin argumentos: ejecuta `Invoke-AutoOptimize` (pipeline desatendido de punta a punta con transcripción completa en `logs/ultimo-diagnostico.txt` y apertura automática de `logs/dashboard.html`).
  - Con `-Menu`: abre el menú interactivo clásico con acceso individual a todos los módulos (`1` a `20`).
- `INICIAR.bat`: Launcher con auto-elevación UAC automática hacia `run.ps1`.
- `Setup.bat`: Instalador portable para PCs destino (se auto-eleva, copia a `%LOCALAPPDATA%\MejoraPC`, crea acceso directo en Escritorio, registra `setup-log.txt` y dispara la primera corrida).
- `installer/build-package.ps1`: Genera `dist/MejoraPC-portable/` y `dist/MejoraPC.zip` excluyendo toda base de datos, logs, backups y perfiles locales, inyectando `data/build-version.txt` y auditando que cero archivos personales se hayan filtrado.
- `lib/helpers.ps1`: Primitivas compartidas (`Repair-WingetPath`, `Repair-PSModulePath`, `Clear-HostSafe`, `Write-Status`, `Get-MergedBloatCatalog`, `Get-MergedTweaksCatalog`, `Get-DiagnosticHeader`, `Wait-KeyIfInteractive`).

### Módulos PowerShell (`modules/`)
- `00-discover.ps1`: Inventario inicial (1 vez por máquina) contra el catálogo universal + encuesta contextual breve.
- `01-backup.ps1`: Punto de restauración del sistema (con verificación real vía `Get-ComputerRestorePoint`) + exportación `.reg` en `backups/`.
- `02-debloat.ps1`: Remoción en 3 capas:
  - **Capa 1:** Política permanente en registro (`RemoveDefaultMicrosoftStorePackages`) que sobrevive updates y reboots.
  - **Capa 2:** Remoción inmediata de paquetes `Appx` y provisionados.
  - **Capa 3:** Desinstalación `Programs`/`MSI`/`winget` para `Bloque A` y `Bloque B` (previa auditoría de dependencias nativas en `C:\Github\` y `C:\github_personal\` con corte por timeout de 25s). Soporta `-RetryFailed`.
- `03-performance.ps1`: Tweaks de registro, `UserPreferencesMask`, servicios (`SysMain`, `DiagTrack`, `WSearch`), limpieza de autoarranque (`Run` y Scheduled Tasks), hibernación off, pagefile fijo y plan de energía *Ultimate Performance*.
- `04-estetica.ps1`: Ajuste de efectos visuales priorizando rendimiento.
- `05-rescate.ps1`: Rollback interactivo de paquetes, claves `.reg`, servicios y plan de energía.
- `06-seguridad.ps1`: Desactivación de telemetría (`AllowTelemetry=0`), ID de publicidad y feed de actividad.
- `10-python-cleanup.ps1`: Conserva Python 3.14 y versiones requeridas por proyectos en `C:\Github\` / `C:\github_personal\`. En modo `-Auto` solo reporta; si desinstala una versión, re-registra las tareas del monitor contra el intérprete activo y depura `PATH`.
- `12-workflow-optimizer.ps1`: Optimización para sesión de desarrollo (limpieza de `%TEMP%` >7 días, `Prefetch`, pausa temporal de `wuauserv` reversible con `-Restore`, cierre de update checkers).
- `13-verify.ps1`: Verificación empírica independiente (relee disco, registro y servicios sin confiar en el output de los módulos previos; mide tamaño de carpetas con `[System.IO.Directory]` evitando ciclos en reparse points/junctions).
- `14-post-reboot-verify.ps1`: Verificación post-reinicio de un solo uso.
- `15-hardware-check.ps1`: Diagnóstico no destructivo de discos (SMART/reliability), CPU (clock/throttling/WHEA), RAM y antigüedad de drivers (filtrando fechas centinela `1968-07-17` y `2006-06-20`).
- `16-startup-audit.ps1`: Auditoría exhaustiva de persistencia en arranque (`Run`/`RunOnce`, carpetas `Startup`, tareas `Logon`/`Boot`, `Winlogon` y `StartupTask` de apps UWP/Store). Reafirma bloqueos UWP ya aprobados si driftearon.
- `20-kernel-performance.ps1`: Optimización profunda de kernel (`Win32PrioritySeparation = 38` / `0x26`), activación de interrupciones MSI (`MessageSignaledInterruptProperties`) en PCIe (Red y Display), desactivación de `SysMain`/`DiagTrack` y purga de rutas huérfanas/duplicadas en `PATH` (`User` y `Machine`).

### Telemetría y Motor de Reglas Python (`monitor/`)
- `scan.py`: Escaneo de hardware y procesos con salida `rich`, persistencia en SQLite (`data/mejorapc.db`) y `data/status.json`.
- `monitor.py`: Demonio por tarea programada (`MejoraPC-Monitor`, cada 15 min con `pythonw.exe`) que registra muestras de CPU/RAM/Swap y alertas (>85% RAM), con purga automática >30 días.
- `analyze.py`: Motor de reglas semanal (`MejoraPC-Analyze`, domingos 03:00 AM) que evalúa hora pico, procesos no-dev consistentes, alertas diarias y tendencia de RAM, respetando `auto_adjust_declined`.
- `auto_adjust.py`: Promueve candidatos validados con entrada `Run` verificable hacia `data/profile-local.json` para su aplicación controlada en la siguiente corrida.
- `report.py`: Dashboard de consola (`rich`) exportado a `logs/ultimo-informe.txt`.
- `dashboard_data.py` + `html_report.py` + `assets/dashboard.css`: Generador del dashboard visual HTML (`logs/dashboard.html`) bajo la identidad visual de **Mejora Continua** (Azul `#1A3D84`, Rojo `#E1061E`, Amarillo `#F7CC13`, Tinta `#2B2B2B`, tipografía League Spartan).
- `record_run.py`: Persistencia parametrizada de acciones ejecutadas (`applied_actions`).

---

## 4. Reglas Inviolables de Ingeniería en este Repositorio

1. **UTF-8 con BOM obligatorio en todo script `.ps1` (`239, 187, 191`):**
   Windows PowerShell 5.1 interpreta archivos `.ps1` sin BOM usando la página de códigos ANSI local, corrompiendo caracteres Unicode (`—`, `╔`, `✓`) y rompiendo el parser. Todo archivo `.ps1` debe guardarse siempre con UTF-8 BOM.
2. **Prohibido usar `Clear-Host` directo:**
   En sesiones sin buffer de consola interactivo (redirección, tareas programadas, consolas embebidas), `Clear-Host` lanza `SetValueInvocationException`. Usar siempre `Clear-HostSafe` de `lib/helpers.ps1`.
3. **Prohibido colisionar con variables automáticas de PowerShell:**
   Nunca nombrar parámetros o variables locales `$Args`, `$Profile`, `$Matches`, `$Input`, `$Error` ni `$Host` (ej. usar `$PyArgs` en lugar de `$Args` y `$localProfile` en lugar de `$profile`). Poner siempre `$null` a la izquierda en comparaciones (`$null -ne $x`).
4. **Monitoreo 100% invisible:**
   Toda tarea programada en background debe usar `pythonw.exe` y registrar eventos exclusivamente en `data/monitor.log`.
5. **Frontera de privacidad en Git y USB:**
   El repositorio remoto (`pabloeckert/MejoraPC`) es público. Jamás trackear `backups/`, `logs/`, `dist/`, `data/mejorapc.db`, `data/status.json`, `data/last-*.json`, `data/discovery-report.json` ni `data/mirror-output-dir.txt`.

---

## 5. Historial de Higiene y Decisiones Técnicas Relevantes
- **2026-11-10 — Higienización integral bajo protocolo Zero-Trust (Antigravity):**
  - Eliminación de archivos huérfanos y redundantes del árbol (`lib/run-hidden.vbs`, `REPORTE_AUDITORIA.md`, `EJECUTAR_KERNEL_ADMIN.bat`, `reporte_limpieza.ps1`).
  - Creación de `GEMINI.md` como bitácora canónica de gobernanza local tras la purga del ecosistema legado.
  - Restauración de UTF-8 BOM en todos los scripts `.ps1` (`build-package.ps1`, `10-python-cleanup.ps1`, `15-hardware-check.ps1`) y corrección de colisiones con variables automáticas (`$profile` -> `$localProfile` en `16-startup-audit.ps1`) y comparaciones `$null` (`run.ps1`, `10-python-cleanup.ps1`).
  - Integración de los módulos `15`, `16` y `20` al menú interactivo de `run.ps1` y `README.md`, auto-elevación UAC en `INICIAR.bat`, blindaje de `last-kernel-performance.json` en `build-package.ps1` y ampliación del escaneo de proyectos a `C:\Github\` y `C:\github_personal\`.
- **2026-09-28 — Estandarización en Google Antigravity y Gemini:**
  - Purga total de referencias a herramientas previas y migración de la skill `.agents/skills/mantenimiento/SKILL.md`.
- **2026-09-18 — Módulo 20 (Kernel, MSI y PATH):**
  - Incorporación de `modules/20-kernel-performance.ps1` para tuning de `Win32PrioritySeparation` (`0x26`), interrupciones MSI en PCIe y saneamiento de `PATH`.
- **2026-09-07 — Upgrade físico a 16 GB RAM y blindaje de `PSModulePath` / `Clear-HostSafe`:**
  - Aislamiento de `PSModulePath` en Desktop CLR (`Repair-PSModulePath`), filtro de fechas centinela de drivers (`1968-07-17`, `2006-06-20`) y lista `startup_audit_reconocidos`.

