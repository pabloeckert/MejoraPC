# 📋 CHANGELOG

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
