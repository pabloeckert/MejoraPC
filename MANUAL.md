# 📚 MANUAL — Documentación completa

## Índice

1. [Benchmark (Diagnóstico)](#1-benchmark)
2. [Rescue Point (Respaldo)](#2-rescue-point)
3. [Debloater](#3-debloater)
4. [Startup Cleaner](#4-startup-cleaner)
5. [Services Optimizer](#5-services-optimizer)
6. [Performance Tweaks](#6-performance-tweaks)
7. [Memory Optimizer](#7-memory-optimizer)
8. [Disk Cleanup](#8-disk-cleanup)
9. [Turbo Boost](#9-turbo-boost)
10. [Gaming Mode](#10-gaming-mode)
11. [Emergencia](#11-emergencia)
12. [Modo Silencioso](#12-modo-silencioso)
13. [Profiles](#13-profiles)
14. [Windows Update Blocker](#14-windows-update-blocker)
15. [HTML Report](#15-html-report)
16. [Scheduler](#16-scheduler)
17. [Uninstall Tool](#17-uninstall-tool)
18. [Archivos del sistema](#18-archivos-del-sistema)

---

## 1. Benchmark

**Script:** `scripts/benchmark.ps1`
**Opción del menú:** `[1]`

### ¿Qué hace?

Ejecuta un diagnóstico completo de tu sistema en 10 secciones:

| Sección | Qué mide |
|---------|----------|
| Sistema | OS, CPU, RAM, GPU, modelo, tipo de disco |
| Memoria | Total, usado, libre, % de uso |
| CPU | Carga actual del procesador |
| Almacenamiento | Espacio en disco, % usado |
| Startup | Cantidad de programas de inicio |
| Servicios | Servicios corriendo y automáticos |
| Procesos | Total de procesos y top 5 por RAM |
| Plan de energía | Plan activo actual |
| Efectos visuales | Configuración de animaciones |
| Diagnóstico | Problemas detectados y sugerencias |

### Modos

```powershell
.\benchmark.ps1 -Mode rapido     # Solo muestra info
.\benchmark.ps1 -Mode antes      # Guarda snapshot para comparar
.\benchmark.ps1 -Mode despues    # Compara con snapshot "antes"
```

### Comparación antes/después

Cuando ejecutás `-Mode despues`, el benchmark busca el último snapshot "antes" y muestra la diferencia con colores:
- 🟢 Verde = mejoró
- 🔴 Rojo = empeoró
- ⚪ Blanco = sin cambio

### Auto-detección

- Detecta si tu disco es **SSD o HDD** y lo muestra
- Guarda snapshot persistente en `logs/benchmark_latest.json`

---

## 2. Rescue Point

**Script:** `scripts/rescue.ps1`
**Opción del menú:** `[2]` (crear) / `[8]` (restaurar)

### ¿Qué hace?

Crea un respaldo completo de la configuración actual del sistema:

| Dato guardado | Formato |
|---------------|---------|
| Programas de inicio | JSON |
| Estado de servicios | CSV |
| Efectos visuales | JSON |
| Plan de energía | TXT |
| Apps instaladas | CSV |
| Configuración del sistema | JSON |

### ¿Dónde se guardan?

En la carpeta `rescue/` con nombre `manual_YYYY-MM-DD_HH-mm-ss/`

### Restaurar

```
Menú → [8] → Seleccionar rescue point → Confirmar
```

---

## 3. Debloater

**Script:** `scripts/debloater.ps1`
**Opción del menú:** `[3]`

### ¿Qué hace?

Elimina apps basura que Windows trae preinstaladas.

### Apps que elimina

**Juegos:** Candy Crush, Spotify, Disney+, Netflix, TikTok, Clipchamp

**Apps de Microsoft:** 3D Builder, Bing News/Weather, Get Help, Solitaire, People, Power Automate, To Do, Alarms, Feedback Hub, Maps, Your Phone, Groove Music, Movies & TV, Office Hub, Skype, Mixed Reality, Teams, Copilot, Cortana, Outlook, Sticky Notes

**Bloatware:** Apps de Samsung, HP, Dell, Adobe preinstaladas, apps de terceros

### ¿Qué NO toca?

- Microsoft Store (podés reinstalar después)
- Windows Settings
- Windows Defender
- Apps que vos instalaste

### Validación

Después de eliminar cada app, verifica que realmente se eliminó. Si no, reporta el error.

---

## 4. Startup Cleaner

**Script:** `scripts/startup-cleaner.ps1`
**Opción del menú:** `[4]`

### ¿Qué hace?

Desactiva programas que se ejecutan automáticamente al iniciar Windows.

### Fuentes que revisa

1. **Carpeta Startup** — Accesos directos
2. **Registro HKCU/HKLM Run** — Programas registrados
3. **Task Scheduler** — Tareas programadas

### Categorización

**✅ Seguro de desactivar:** OneDrive, Edge, Spotify, Discord, Steam, Epic, Adobe updaters, Google Drive, Brave, Opera, iTunes, Skype, Teams, Cortana, Copilot, Widgets

**⚠️ Otros (revisar antes):** Cualquier programa no categorizado

### Modo de acción

```
[1] Desactivar solo los seguros (recomendado)
[2] Desactivar TODO (revisar lista primero)
[0] Cancelar
```

---

## 5. Services Optimizer

**Script:** `scripts/services.ps1`
**Opción del menú:** `[5]`

### ¿Qué hace?

Optimiza servicios de Windows. Los pone en "Manual" (no se desactivan, solo no arrancan solos).

### Auto-detección SSD/HDD

- **SSD:** SysMain (Superfetch) y WSearch (indexer) se **desactivan** (innecesarios con SSD)
- **HDD:** SysMain se mantiene activo (mejora rendimiento en discos mecánicos)

### Servicios que pone en Manual

Telemetría (DiagTrack, DPS, diagsvc), Xbox (4 servicios), updates (Adobe, Brave, Edge, Google), Maps, geolocalización, error reporting, teléfono, mensajería, Game DVR, Windows Insider, WAP Push, y más.

### Validación

Después de cada cambio, verifica que el servicio quedó en el estado esperado. Si no, lo reporta.

---

## 6. Performance Tweaks

**Script:** `scripts/performance.ps1`
**Opción del menú:** `[6]`

### ¿Qué hace?

8 optimizaciones de rendimiento:

| # | Tweak | Qué hace |
|---|-------|----------|
| 1 | Efectos visuales | Reduce animaciones al mínimo |
| 2 | Plan de energía | Activa "Alto Rendimiento" |
| 3 | Sombras | Desactiva sombras y Aero Peek |
| 4 | Foreground priority | Apps activas tienen prioridad CPU |
| 5 | Telemetría | Desactiva envío de datos a Microsoft |
| 6 | SSD | Desactiva Superfetch y Prefetch (solo SSD) |
| 7 | Tips | Desactiva sugerencias de Windows |
| 8 | Red | Optimiza TCP para menor latencia |

### Validación

Cada tweak verifica que el valor del registro se aplicó correctamente.

---

## 7. Memory Optimizer

**Script:** `scripts/memory.ps1`
**Opción del menú:** `[7]`

### ¿Qué hace?

6 optimizaciones de memoria:

| # | Acción | Efecto |
|---|--------|--------|
| 1 | Liberar working sets | Libera RAM de procesos activos |
| 2 | Pagefile fijo | Evita fragmentación del archivo de paginación |
| 3 | Background apps off | Desactiva apps en segundo plano |
| 4 | SvcHost split | Reduce instancias de svchost.exe |
| 5 | NTFS last access | Desactiva timestamp de acceso |
| 6 | Limpiar caché | DNS cache + standby memory |

### Resultado

Muestra RAM libre antes y después de la optimización.

---

## 8. Disk Cleanup

**Script:** `scripts/disk-cleanup.ps1`

### ¿Qué hace?

Limpia archivos temporales y basura del sistema en 8 pasos:

| # | Qué limpia | Ruta |
|---|-----------|------|
| 1 | Temporales del usuario | `%TEMP%`, `%LOCALAPPDATA%\Temp` |
| 2 | Caché de Windows Update | `Windows\SoftwareDistribution\Download` |
| 3 | Thumbnails | Explorer thumbcache |
| 4 | Logs de eventos | Event Logs no esenciales |
| 5 | Prefetch | Archivos >30 días |
| 6 | Papelera | Recycle Bin |
| 7 | Caché de navegadores | Chrome, Edge, Firefox |
| 8 | Iconos cache | iconcache_*.db |

### Resultado

Muestra espacio libre en disco antes y después, con la cantidad total liberada.

---

## 9. Turbo Boost

**Script:** `scripts/turbo-boost.ps1`
**Opción del menú:** `[T]` (activar) / `[R]` (revertir) / `[S]` (status)

### ¿Qué hace?

Modo de rendimiento extremo para trabajo intenso. 7 pasos:

1. CPU al 100% (sin throttling)
2. Detiene +40 servicios
3. Cierra +20 procesos
4. Efectos visuales off
5. CPU priority máxima
6. Background tasks off
7. Limpia memoria agresivamente

### ⚠️ Importante

- **NO** es para uso diario
- **SIEMPRE** revertí cuando terminés
- Solo para: edición de video, compilación, renderizado

---

## 10. Gaming Mode

**Script:** `scripts/gaming-mode.ps1`
**Opción del menú:** `[G]` (activar) / `[H]` (revertir) / `[J]` (status)

### ¿Qué hace?

Optimización específica para jugar. Diferente a Turbo Boost:

| | Turbo Boost | Gaming Mode |
|---|---|---|
| CPU | 100% siempre | Balanceado |
| Audio | ❌ Detenido | ✅ Activo |
| Red | ❌ Detenida | ✅ Activa |
| Game DVR | Sin cambios | ❌ Desactivado |
| GPU | Sin cambios | ✅ Prioridad máxima |
| Latencia input | Sin cambios | ✅ Optimizada |
| Servicios detenidos | +40 | ~25 selectivos |

### 9 pasos de activación

1. Plan Alto Rendimiento (no Ultimate)
2. Game DVR desactivado (mayor impacto en FPS)
3. GPU prioridad máxima + Hardware-accelerated GPU scheduling
4. Red optimizada (Nagle off, TCP Ack = 1)
5. Efectos visuales reducidos
6. Servicios selectivos detenidos (mantiene audio/red)
7. Procesos innecesarios cerrados (mantiene Discord, Spotify si están corriendo)
8. Input priority configurada
9. Background tasks desactivadas

### Estado

Se guarda en `rescue/gaming_state.json`.

---

## 11. Emergencia

**Script:** `scripts/emergencia.ps1`
**Opción del menú:** `[9]`

### ¿Qué hace?

Restaura TODO al estado original. 10 pasos con validación:

1. Plan de energía → Equilibrado
2. Servicios → Automatic (SysMain/WSearch → Manual)
3. Efectos visuales → Default
4. Background apps → Reactivadas
5. Telemetría → Reactivada
6. Windows Update → Reactivado
7. CPU priorities → Default
8. Superfetch → según tipo de disco
9. Tips → Reactivados
10. Turbo/Gaming state → Eliminado

### Resultado

Muestra resumen: `completados/total, errores`. Si hubo errores, indica cuáles.

---

## 12. Modo Silencioso

**Opción de línea de comandos**

### Uso

```powershell
.\win-optimizer.ps1 -Silent                    # Todo silencioso
.\win-optimizer.ps1 -Silent -DryRun            # Simular
.\win-optimizer.ps1 -Silent -WithGaming        # + Gaming Mode
```

### ¿Qué hace?

1. Benchmark "antes" (guarda snapshot)
2. Ejecuta todos los módulos (Debloater → Disk Cleanup)
3. Gaming Mode (si `-WithGaming`)
4. Benchmark "después" (compara con "antes")
5. Muestra log

Sin prompts, sin interacción. Ideal para reinstalaciones de Windows.

---

## 13. Profiles

**Script:** `scripts/profiles.ps1`
**Opción del menú:** `[P]`

### ¿Qué hace?

Guarda y carga configuraciones completas del sistema como "perfiles". Cada perfil captura:

| Dato | Qué guarda |
|------|-----------|
| Servicios | Estado y tipo de inicio de todos los servicios |
| Efectos visuales | VisualFXSetting, transparencia, AeroPeek |
| Background apps | Si están activas o desactivadas |
| Telemetría | Nivel de telemetría permitido |
| Plan de energía | GUID del plan activo |
| Startup | Entradas del registro HKCU Run |

### Acciones

| Acción | Qué hace |
|--------|----------|
| `list` | Muestra todos los perfiles guardados |
| `save` | Captura estado actual y lo guarda como perfil |
| `load` | Aplica un perfil guardado (crea rescue point primero) |
| `delete` | Elimina un perfil |

### Uso desde menú

```
[P] → [1] Listar perfiles
[P] → [2] Guardar perfil actual
[P] → [3] Cargar perfil
[P] → [4] Eliminar perfil
```

### Uso desde CLI

```powershell
.\profiles.ps1 -Action save -Name "trabajo"
.\profiles.ps1 -Action load -Name "trabajo"
.\profiles.ps1 -Action list
.\profiles.ps1 -Action delete -Name "trabajo"
```

### ¿Dónde se guardan?

En la carpeta `profiles/` como archivos JSON.

### Seguridad

- Al cargar un perfil, crea un rescue point automáticamente antes de aplicar
- Solo modifica configuración, no desinstala apps ni toca archivos personales

---

## 14. Windows Update Blocker

**Script:** `scripts/wu-blocker.ps1`
**Opción del menú:** `[W]`

### ¿Qué hace?

Pausa o reanuda completamente Windows Update. Útil cuando necesitás toda la RAM sin interrupciones.

### Qué bloquea

| Componente | Cómo |
|-----------|------|
| Servicio WU | Detenido + Disabled |
| Update Orchestrator | Detenido + Disabled |
| Auto-update | Registro: NoAutoUpdate = 1 |
| Update internet | Registro: DisableWindowsUpdateAccess = 1 |
| Reinicios automáticos | Registro: NoAutoRebootWithLoggedOnUsers = 1 |
| Power management | Registro: AUPowerManagement = 0 |

### Acciones

| Acción | Qué hace |
|--------|----------|
| `block` | Detiene servicios, bloquea via registro |
| `unblock` | Reactiva servicios, elimina restricciones |
| `status` | Muestra estado actual del bloqueo |

### Uso desde menú

```
[W] → [1] Ver status
[W] → [2] Bloquear
[W] → [3] Desbloquear
```

### Uso desde CLI

```powershell
.\wu-blocker.ps1 -Action block
.\wu-blocker.ps1 -Action unblock
.\wu-blocker.ps1 -Action status
```

### ⚠️ Importante

- **No te olvides de desbloquear** cuando terminés
- Sin actualizaciones, tu PC no recibe parches de seguridad
- Ideal para sesiones puntuales, no para uso permanente

---

## 15. HTML Report

**Script:** `scripts/html-report.ps1`
**Opción del menú:** `[I]`

### ¿Qué hace?

Genera un reporte visual del benchmark en formato HTML con:

- Información del sistema (CPU, RAM, GPU, modelo)
- Barras de progreso con colores de estado (verde/amarillo/rojo)
- Top 5 procesos por RAM
- Diagnóstico de problemas
- Comparación con benchmarks anteriores

### Uso desde menú

```
[I] → Genera reporte del último benchmark
```

### Uso desde CLI

```powershell
# Generar del último benchmark
.\html-report.ps1

# Generar de un archivo específico
.\html-report.ps1 -InputFile "logs\benchmark_antes_2026-05-13.json"

# Especificar archivo de salida
.\html-report.ps1 -OutputFile "mi-reporte.html"
```

### ¿Dónde se guarda?

En `logs/report_YYYY-MM-DD_HH-mm.html`. Abrir en cualquier navegador.

---

## 16. Scheduler

**Script:** `scripts/scheduler.ps1`
**Opción del menú:** `[K]`

### ¿Qué hace?

Crea una tarea de Windows Task Scheduler que ejecuta el benchmark automáticamente cada semana. Útil para detectar degradación del sistema con el tiempo.

### Acciones

| Acción | Qué hace |
|--------|----------|
| `install` | Crea tarea: benchmark cada lunes a las 10:00 AM |
| `uninstall` | Elimina la tarea |
| `status` | Muestra estado, última ejecución, reportes generados |

### Uso desde menú

```
[K] → [1] Ver status
[K] → [2] Instalar
[K] → [3] Eliminar
```

### Detalles de la tarea

- **Frecuencia:** Cada lunes a las 10:00 AM
- **Modo:** Solo cuando estás logueado (no en background oculto)
- **Batería:** Se ejecuta incluso en batería
- **Disponibilidad:** Si no estabas, corre cuando te logueás
- **Reportes:** Se guardan en `logs/benchmark_antes_*.json`

---

## 17. Uninstall Tool

**Script:** `scripts/uninstall-tool.ps1`
**Opción del menú:** `[U]`

### ¿Qué hace?

Desinstalador completo que revierte todas las optimizaciones y opcionalmente elimina el programa del sistema.

### Proceso

1. **Restaurar desde Rescue Point** (opcional): Si existen rescue points, ofrece restaurar desde el más reciente
2. **Restaurar valores por defecto**: Servicios, plan de energía, efectos visuales, telemetría, Windows Update, Game DVR, background apps, prioridades CPU, tips
3. **Limpiar archivos**: Logs, archivos de estado, tarea programada
4. **Eliminar programa** (opcional): Puede eliminar la carpeta completa del programa

### Qué restaura

| Componente | Valor restaurado |
|------------|-----------------|
| Servicios | Automatic (los que estaban en Manual) |
| SysMain/WSearch | Manual (si es HDD) / Disabled (si es SSD) |
| Plan de energía | Equilibrado |
| Efectos visuales | Por defecto de Windows |
| Telemetría | Reactivada |
| Windows Update | Reactivado + servicio reactivado |
| Game DVR | Reactivado |
| Background apps | Reactivadas |
| Prioridades CPU | Valor por defecto (2) |
| Tips de Windows | Reactivados |

### Uso

```powershell
# Desde el menú
[U] → seguir instrucciones

# Directamente
.\scripts\uninstall-tool.ps1
```

### Seguridad

- Siempre ofrece restaurar desde Rescue Point primero
- Pide confirmación antes de eliminar la carpeta
- Auto-eliminación via batch script (no puede eliminarse a sí mismo)
- Pregunta si reiniciar al final

---

## 18. Archivos del sistema

### Estructura

```
MejoraNotebook/
├── INICIAR.bat              # Launcher
├── win-optimizer.ps1        # Menú principal + Silent Mode
├── README.md
├── TUTORIAL.md
├── MANUAL.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── scripts/
│   ├── config.ps1           # Config compartida + listas centralizadas
│   ├── benchmark.ps1        # Diagnóstico + comparación
│   ├── rescue.ps1           # Rescue points
│   ├── debloater.ps1        # Eliminar bloatware
│   ├── startup-cleaner.ps1  # Limpiar inicio
│   ├── services.ps1         # Optimizar servicios
│   ├── performance.ps1      # Tweaks de rendimiento
│   ├── memory.ps1           # Optimizar RAM
│   ├── disk-cleanup.ps1     # Limpiar archivos temporales
│   ├── gaming-mode.ps1      # Modo gaming
│   ├── turbo-boost.ps1      # Turbo Boost
│   ├── profiles.ps1         # Guardar/cargar perfiles
│   ├── wu-blocker.ps1       # Windows Update Blocker
│   ├── html-report.ps1      # Reporte HTML del benchmark
│   ├── scheduler.ps1        # Optimización programada
│   └── emergencia.ps1       # Restaurar todo
├── logs/                    # Logs automáticos
│   ├── optimizer_*.log
│   ├── benchmark_antes_*.json
│   ├── benchmark_despues_*.json
│   └── benchmark_latest.json
└── rescue/                  # Rescue points
    └── *_YYYY-MM-DD_HH-mm-ss/
```

### Features del sistema

| Feature | Dónde |
|---------|-------|
| Dry-Run Mode | Toggle `[D]` en menú, o `-DryRun` |
| SSD Detection | Automático en `config.ps1` |
| Validación post-op | Cada script verifica cambios |
| Logging | Cada operación se loguea |
| Progress bars | Loops largos muestran progreso |

---

## Preguntas frecuentes

### ¿Esto es seguro?

Sí. Todo es reversible. El Rescue Point guarda todo. El Emergencia restaura todo.

### ¿Pierdo datos?

No. Solo se desinstalan apps preinstaladas reinstalables desde Microsoft Store.

### ¿Funciona en Windows 10?

Sí, la mayoría de los tweaks. Algunos (Copilot) son específicos de Windows 11.

### ¿El Turbo Boost / Gaming Mode dañan la PC?

No. Solo optimizan software. No modifican hardware ni voltajes.

### ¿Puedo usar Turbo Boost todo el tiempo?

No se recomienda. Solo para trabajo intenso. Para gaming, usá Gaming Mode.

### ¿Qué pasa si no revierto el Turbo Boost?

Los servicios detenidos no se reinician. Windows Update no funciona. Siempre revertí.

---

MIT License — Hacé lo que quieras.
