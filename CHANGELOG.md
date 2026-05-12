# 📋 CHANGELOG

## v2.2.0 — 2026-05-13

### Nuevos módulos
- **Daemon** (`scripts/daemon.ps1`) — monitoreo silencioso en segundo plano con aprendizaje automático.
  - Aprende patrones: horas activas/inactivas, procesos frecuentes, uso de RAM/CPU
  - Acciones automáticas: limpiar RAM, cerrar procesos seguros, matar zombies
  - Protecciones: no mata procesos del sistema, navegadores, IDEs, comunicación
  - Configurable: umbrales, intervalos, notificaciones, modo silencioso
  - Log persistente con historial de acciones

### Menú
- Submenú `[8]` — Daemon (start/stop/status/logs) + Rescue Point

---

## v2.1.0 — 2026-05-13

### Nuevos módulos
- **Notifications** (`scripts/notifications.ps1`) — notificaciones toast para Windows 10/11. Soporta iconos personalizados (success, warning, error, fire, game, globe, chart). Fallback a msg.exe.

### Integración
- `config.ps1`: función `Send-Notification()` wrapper usable por todos los scripts
- Notificaciones automáticas en: Turbo Boost, Gaming Mode, Benchmark, Network Optimizer, WU Blocker

---

## v2.0.0 — 2026-05-13

### Nuevos módulos
- **Dashboard** (`scripts/dashboard.ps1`) — servidor web local con monitoreo en tiempo real. Gráficos interactivos de CPU, RAM, Disco. Estado de optimizaciones. Top 5 procesos. Auto-actualización cada 5s.

### Menú
- Opción `[X]` — Dashboard web (monitoreo en tiempo real)

---

## v1.9.0 — 2026-05-13

### Nuevos módulos
- **App Store** (`scripts/app-store.ps1`) — reinstalar apps desinstaladas por Debloater. Busca en winget y Microsoft Store. Incluye list, reinstall, search.
- **Share Benchmark** (`scripts/share-benchmark.ps1`) — exportar/importar benchmarks entre PCs. Formato .portable.json con comparación visual.

### Menú
- Opción `[E]` — Exportar benchmark para otra PC
- Opción `[B]` — Importar benchmark de otra PC
- Opción `[F]` — App Store (reinstalar apps desinstaladas)

---

## v1.8.0 — 2026-05-13

### Nuevos módulos
- **Benchmark Compare** (`scripts/compare.ps1`) — comparación visual de benchmarks con tabla, score de mejora y tendencia histórica. Soporta modos: compare, list, trend.
- **Offline Pack** (`scripts/offline-pack.ps1`) — exporta paquete completo para uso sin internet. Incluye instalador .bat y instrucciones.

### Menú
- Opción `[C]` — Comparar benchmarks (antes/después)
- Opción `[O]` — Paquete offline (sin internet)

---

## v1.7.0 — 2026-05-13

### Nuevos módulos
- **Driver Updater** (`scripts/driver-updater.ps1`) — escaneo de drivers instalados, detección de problemas, verificación de actualizaciones vía Windows Update, reporte exportable.
- **Auto-updater** (`scripts/updater.ps1`) — actualización automática desde GitHub. Descarga ZIP, crea backup, actualiza scripts y verifica versión.
- **Wizard** (`scripts/wizard.ps1`) — modo guiado paso a paso para principiantes. Sin tecnicismos, 5 pasos: diagnóstico → respaldo → limpieza → optimización → resultado.

### Menú
- Opción `[V]` — Driver Updater (escanear drivers)
- Opción `[Y]` — Actualizar MejoraNotebook desde GitHub
- Opción `[Z]` — Wizard guiado para principiantes

---

## v1.6.0 — 2026-05-13

### Nuevos módulos
- **Network Optimizer** (`scripts/network-optimizer.ps1`) — optimización avanzada de red: TCP global, parámetros TCP, DNS (Cloudflare+Google), throttling, NIC, gaming profile. Incluye revert y status.
- **Health Check** (`scripts/health-check.ps1`) — verificación rápida del sistema con resumen visual de CPU, RAM, disco, servicios, procesos, red y estado de optimizaciones activas.

### Benchmark
- Exportación automática a CSV (`benchmark_history.csv`) para tracking histórico de rendimiento

### Emergencia
- Ahora revierte red, gaming mode y WU blocker (expandido de 10 a 12 pasos)

### Menú
- Opción `[N]` — Network Optimizer
- Opción `[M]` — Revertir Network Optimizer
- Opción `[Q]` — Health Check rápido
- Sección RED separada en el menú

---

## v1.5.0 — 2026-05-13

### Nuevos módulos
- **Uninstall Tool** (`scripts/uninstall-tool.ps1`) — desinstalador completo que restaura todo al estado original y opcionalmente elimina el programa del sistema. Incluye restauración desde rescue point, reactivación de todos los servicios/telemetría/WU, y auto-eliminación.

### Menú
- Opción `[U]` — desinstalador completo
- Opción `[X]` — reporte completo (benchmark + HTML + abrir navegador)

### Correcciones (auditoría completa)
- `debloater.ps1`: eliminada entrada duplicada "Clipchamp.Clipchamp"
- `profiles.ps1`: parámetro Action con valor por defecto corregido
- `memory.ps1`: Write-Step con parámetros incorrectos corregido (2 lugares)
- `disk-cleanup.ps1`: icon cache path corregido para evitar error con wildcard
- `rescue.ps1`: restauración ahora reactiva servicios que estaban corriendo
- `turbo-boost.ps1`: fallback seguro si powercfg no retorna GUID válido
- `gaming-mode.ps1`: fallback seguro si powercfg no retorna GUID válido

### Documentación
- README.md: versión actualizada a v1.4.0
- PROGRESS.md: archivo de continuidad para retomar trabajo entre sesiones

---

## v1.4.0 — 2026-05-13

### Nuevos módulos
- **HTML Report** (`scripts/html-report.ps1`) — genera reporte visual del benchmark en HTML con barras de progreso, colores de estado, diagnóstico y comparación con benchmarks anteriores
- **Scheduler** (`scripts/scheduler.ps1`) — programa benchmark semanal via Windows Task Scheduler para detectar degradación del sistema

### Menú
- Opción `[I]` — generar reporte HTML del último benchmark
- Opción `[K]` — submenú de optimización programada (status, instalar, eliminar)

---

## v1.3.0 — 2026-05-13

### Nuevos módulos
- **Profiles** (`scripts/profiles.ps1`) — guardar/cargar perfiles de optimización (servicios, efectos visuales, background apps, telemetría, plan de energía, startup)
- **Windows Update Blocker** (`scripts/wu-blocker.ps1`) — pausar/reanudar Windows Update con un click (servicio, registro, reinicios automáticos)

### Menú
- Opción `[P]` — submenú de perfiles (listar, guardar, cargar, eliminar)
- Opción `[W]` — submenú de Windows Update (status, bloquear, desbloquear)

---

## v1.2.0 — 2026-05-13

### Nuevos módulos
- **Disk Cleanup** (`scripts/disk-cleanup.ps1`) — limpia temp files, WU cache, thumbnails, prefetch, papelera, caché de navegadores, iconos
- **Gaming Mode** (`scripts/gaming-mode.ps1`) — Game DVR off, GPU prioridad, baja latencia, mantiene audio/red activos

### Modo Silencioso
- `win-optimizer.ps1 -Silent` ejecuta todo sin prompts (para reinstalaciones)
- `-DryRun` para simular sin aplicar cambios
- `-WithGaming` para incluir Gaming Mode
- Incluye benchmark antes/después automáticamente

### Menú
- Opciones `[G]`/`[H]`/`[J]` para Gaming Mode (activar/revertir/status)
- Disk Cleanup integrado en "Optimizar Todo"

### Documentación
- TUTORIAL.md reescrito con Gaming Mode, Silent Mode, DRY-RUN
- MANUAL.md reescrito con todos los módulos nuevos (13 secciones)

---

## v1.1.0 — 2026-05-13

### Features
- **Modo DRY-RUN** — toggle `[D]` en menú, wrappers `Set-RegProperty`/`Set-ServiceState` que respetan modo simulación
- **Auto-detección SSD/HDD** — `Global:IsSSD`, servicios se ajustan automáticamente
- **Validación post-optimización** — `Confirm-ServiceState` y `Confirm-RegistryValue` verifican cada cambio
- **Logs visibles** — `[L]` en menú para ver log, `Show-LogPath` al final de cada operación
- **Comparación benchmark antes/después** — `-Mode antes` guarda snapshot, `-Mode despues` muestra diff con colores

### Error handling
- `emergencia.ps1`: try/catch en cada paso, resumen completados/errores
- `debloater.ps1`: validación de eliminación post-acción
- `memory.ps1`: validación de background apps
- `performance.ps1`: validación de registry values

### Centralización
- Listas de servicios centralizadas en `config.ps1` (elimina duplicación entre services, turbo-boost, emergencia)
- Listas de procesos centralizadas en `$Global:TurboProcesses`

---

## v1.0.1 — 2026-05-13

### Bug fixes
- `param()` movido al inicio en `benchmark.ps1`, `rescue.ps1`, `turbo-boost.ps1` (antes estaba después de dot-source y se ignoraba)
- Regex de captura de plan de energía corregida en `turbo-boost.ps1`
- `startup-cleaner.ps1`: mueve .lnk a subcarpeta `.disabled` en vez de renombar
- `emergencia.ps1`: SysMain y WSearch van a Manual (no Automatic) al restaurar
- `rescue.ps1`: eliminado segundo bloque `param()` duplicado

---

## v1.0.0 — 2026-05-12

### Módulos iniciales
- Benchmark (diagnóstico completo)
- Rescue Point (respaldo y restauración)
- Debloater (eliminar apps basura)
- Startup Cleaner (limpiar inicio)
- Services Optimizer (optimizar servicios)
- Performance Tweaks (rendimiento + efectos visuales)
- Memory Optimizer (liberar RAM)
- Turbo Boost (modo máximo rendimiento)
- Emergencia (restaurar todo)

### Infraestructura
- `config.ps1` compartido con funciones comunes
- Sistema de logging
- `INICIAR.bat` launcher con verificación de admin
- Documentación: README, TUTORIAL, MANUAL
