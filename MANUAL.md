# 📚 MANUAL — Documentación completa

## Índice

1. [Benchmark (Diagnóstico)](#1-benchmark)
2. [Rescue Point (Respaldo)](#2-rescue-point)
3. [Debloater](#3-debloater)
4. [Startup Cleaner](#4-startup-cleaner)
5. [Services Optimizer](#5-services-optimizer)
6. [Performance Tweaks](#6-performance-tweaks)
7. [Memory Optimizer](#7-memory-optimizer)
8. [Turbo Boost](#8-turbo-boost)
9. [Emergencia](#9-emergencia)
10. [Archivos del sistema](#10-archivos-del-sistema)

---

## 1. Benchmark

**Script:** `scripts/benchmark.ps1`
**Opción del menú:** `[1]`

### ¿Qué hace?

Ejecuta un diagnóstico completo de tu sistema en 10 secciones:

| Sección | Qué mide |
|---------|----------|
| Sistema | OS, CPU, RAM, GPU, modelo |
| Memoria | Total, usado, libre, % de uso |
| CPU | Carga actual del procesador |
| Almacenamiento | Espacio en disco, % usado |
| Startup | Cantidad de programas de inicio |
| Servicios | Servicios corriendo y automáticos |
| Procesos | Total de procesos y top 5 por RAM |
| Plan de energía | Plan activo actual |
| Efectos visuales | Configuración de animaciones |
| Diagnóstico | Problemas detectados y sugerencias |

### ¿Qué problemas detecta?

- RAM alta (>80%) → Sugiere ejecutar Memory Optimizer
- RAM libre baja (<1.5 GB) → Sugiere liberar RAM
- CPU alta (>70%) → Sugiere cerrar procesos
- Disco lleno (>85%) → Sugiere limpiar archivos
- Muchos programas de inicio (>10) → Sugiere Startup Cleaner
- Muchos servicios (>100) → Sugiere Services Optimizer
- Efectos visuales activos → Sugiere Performance Tweaks

### Modos

```powershell
.\benchmark.ps1 -Mode rapido     # Solo muestra info
.\benchmark.ps1 -Mode antes      # Guarda reporte "antes"
.\benchmark.ps1 -Mode despues    # Guarda reporte "después"
```

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

### ¿Cuándo usarlo?

- **Siempre** antes de ejecutar cualquier optimización
- Antes de instalar software nuevo
- Antes de hacer cambios importantes en el sistema

### ¿Dónde se guardan?

En la carpeta `rescue/` con nombre `manual_YYYY-MM-DD_HH-mm-ss/`

### Restaurar

```
Menú → [8] → Seleccionar rescue point → Confirmar
```

Restaura:
- Servicios a su estado original
- Plan de energía
- Efectos visuales
- Verifica apps desinstaladas

---

## 3. Debloater

**Script:** `scripts/debloater.ps1`
**Opción del menú:** `[3]`

### ¿Qué hace?

Elimina apps basura que Windows trae preinstaladas. Estas apps consumen RAM, disco y CPU en segundo plano.

### Apps que elimina

**Juegos y entretenimiento:**
- Candy Crush Saga
- Candy Crush Soda Saga
- Spotify (versión preinstalada)
- Disney+
- Netflix
- TikTok
- Clipchamp

**Apps de Microsoft innecesarias:**
- 3D Builder
- Bing News
- Bing Weather
- Get Help
- Get Started
- Solitaire Collection
- People
- Power Automate
- To Do
- Alarms
- Feedback Hub
- Maps
- Your Phone
- Groove Music
- Movies & TV
- Office Hub
- Skype
- Mixed Reality Portal
- Teams (versión preinstalada)
- Copilot
- Cortana
- Outlook (versión nueva)
- Sticky Notes

**Bloatware de fabricantes:**
- Apps de Samsung, HP, Dell, etc.
- Apps de Adobe preinstaladas
- Apps de terceros preinstaladas

### ¿Qué NO toca?

- Microsoft Store (podés reinstalar apps después)
- Windows Settings
- Apps del sistema esenciales
- Windows Defender
- Apps que vos instalaste

### Seguridad

- Pide confirmación explícita (escribir "SI")
- Muestra la lista completa antes de eliminar
- Las apps se pueden reinstalar desde Microsoft Store
- El Rescue Point guarda la lista de apps eliminadas

---

## 4. Startup Cleaner

**Script:** `scripts/startup-cleaner.ps1`
**Opción del menú:** `[4]`

### ¿Qué hace?

Desactiva programas que se ejecutan automáticamente al iniciar Windows.

### Fuentes que revisa

1. **Carpeta Startup** — Accesos directos en la carpeta de inicio
2. **Registro HKCU Run** — Programas del usuario actual
3. **Registro HKLM Run** — Programas del sistema
4. **Task Scheduler** — Tareas programadas

### Categorización

El script separa los programas en dos categorías:

**✅ Seguro de desactivar:**
- OneDrive
- Edge auto-launch
- Spotify
- Discord
- Steam
- Epic Games
- Adobe updaters
- Google Drive sync
- Brave
- Opera
- iTunes Helper
- Skype
- Teams
- Cortana
- Copilot
- Widgets

**⚠️ Otros (revisar antes):**
- Cualquier programa no categorizado
- Antivirus de terceros
- Software de hardware
- Apps que necesitás al inicio

### Modo de acción

```
[1] Desactivar solo los seguros (recomendado)
[2] Desactivar TODO (revisar lista primero)
[0] Cancelar
```

### ¿Cómo se desactiva?

- **Archivos .lnk:** Los renombra a `.lnk.disabled`
- **Registry:** Elimina la entrada del registro
- **Tasks:** Desactiva la tarea programada

---

## 5. Services Optimizer

**Script:** `scripts/services.ps1`
**Opción del menú:** `[5]`

### ¿Qué hace?

Optimiza servicios de Windows que corren en segundo plano consumiendo RAM y CPU.

### Servicios que pone en Manual

Estos servicios no se desactivan, pero dejan de iniciarse automáticamente:

**Telemetría y diagnósticos:**
- DiagTrack (telemetría de Microsoft)
- diagnosticshub
- diagsvc
- DPS (directivas de diagnóstico)
- WdiServiceHost
- WdiSystemHost

**Servicios de terceros:**
- AdobeARMservice (Adobe Update)
- brave / bravem (Brave Update)
- edgeupdate / edgeupdatem (Edge Update)
- gupdate / gupdatem (Google Update)
- CapCutServiceLS (CapCut)
- DFWSIDService (Wondershare)
- DSAService / DSAUpdateService (Intel Driver Assistant)

**Windows features innecesarias:**
- MapsBroker (mapas descargados)
- lfsvc (geolocalización)
- SharedAccess (ICS)
- RemoteRegistry (registro remoto)
- RetailDemo (modo demo)
- WerSvc (error reporting)
- XblAuthManager / XblGameSave / XboxGipSvc / XboxNetApiSvc (Xbox)
- PhoneSvc / TapiSrv / MessagingService (teléfono/mensajería)
- PimIndexMaintenanceSvc (contactos)
- BcastDVRUserService (game DVR)
- wisvc (Windows Insider)
- dmwappushservice (WAP Push)

### Servicios que desactiva

- **SysMain** (Superfetch) — Con SSD es innecesario
- **WSearch** (Windows Search Indexer) — Come RAM y CPU constantemente

### ¿Es seguro?

Sí. Los servicios se ponen en "Manual", no se desactivan. Si un servicio se necesita, Windows lo inicia bajo demanda. Solo Superfetch y Search Indexer se desactivan completamente.

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
| 6 | SSD | Desactiva Superfetch y Prefetch |
| 7 | Tips | Desactiva sugerencias de Windows |
| 8 | Red | Optimiza TCP para menor latencia |

### Detalle de cada tweak

**1. Efectos visuales:**
- VisualFXSetting = 2 (ajustar por mejor rendimiento)
- MenuShowDelay = 0 (menús instantáneos)
- Transparencias desactivadas
- Animaciones de ventana desactivadas

**2. Plan de energía:**
- Activa el plan "Alto Rendimiento"
- CPU funciona a frecuencia máxima
- Disco no se apaga
- USB no se suspende

**3. Sombras:**
- ListviewAlphaSelect = 0
- ListviewShadow = 0
- AeroPeek desactivado
- Thumbnails en vivo desactivados

**4. Foreground priority:**
- ForegroundLockTimeout = 0
- Win32PrioritySeparation = 38 (foreground apps get more CPU)

**5. Telemetría:**
- AllowTelemetry = 0
- ActivityFeed desactivado
- PublishUserActivities desactivado

**6. SSD:**
- Superfetch desactivado
- Prefetcher desactivado
- Mejor rendimiento en SSD

**7. Tips:**
- SoftLandingEnabled = 0
- SystemPaneSuggestionsEnabled = 0
- Sugerencias de contenido desactivadas

**8. Red:**
- TCP Ack Frequency = 1 (menor latencia)
- TCP No Delay = 1 (Nagle's algorithm desactivado)

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

### Detalle

**1. Liberar memoria:**
- Usa EmptyWorkingSet para limpiar procesos
- Forza garbage collection de .NET
- Muestra cuánta RAM se liberó

**2. Pagefile:**
- Desactiva administración automática
- Configura tamaño fijo (1.5x RAM)
- Evita fragmentación

**3. Background apps:**
- GlobalUserDisabled = 1
- Excluye Calculator, Store, Photos

**4. SvcHost split:**
- SvcHostSplitThresholdInKB = RAM total
- Reduce instancias de svchost.exe
- Cada servicio usa menos RAM

**5. NTFS:**
- disablelastaccess = 1
- Menos escrituras al disco

**6. Caché:**
- Flush DNS cache
- Limpia standby memory

---

## 8. Turbo Boost

**Script:** `scripts/turbo-boost.ps1`
**Opción del menú:** `[T]` (activar) / `[R]` (revertir) / `[S]` (status)

### ¿Qué hace?

Modo de rendimiento extremo para trabajo intenso. Es como un "overclocking de software".

### Activación

Cuando lo activás, ejecuta 7 pasos:

| # | Acción | Efecto |
|---|--------|--------|
| 1 | CPU al 100% | Sin throttling, frecuencia máxima |
| 2 | Detiene +40 servicios | Telemetría, Xbox, updates, etc. |
| 3 | Cierra +20 procesos | OneDrive, Edge, Teams, etc. |
| 4 | Efectos visuales off | Todo desactivado |
| 5 | CPU priority máxima | Foreground apps al máximo |
| 6 | Background tasks off | Sin tareas en segundo plano |
| 7 | Limpia memoria | RAM liberada agresivamente |

### Servicios que detiene

- Telemetría: DiagTrack, diagsvc, DPS
- Xbox: XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc
- Actualizaciones: edgeupdate, gupdate, brave, AdobeARM
- Comunicación: PhoneSvc, MessagingService, PimIndexMaintenanceSvc
- Otros: MapsBroker, lfsvc, WerSvc, RetailDemo, dmwappushservice, wisvc, BcastDVRUserService

### Procesos que cierra

- OneDrive, FileSyncHelper
- Microsoft Edge
- Widgets, WidgetService
- YourPhone, PhoneExperienceHost
- Cortana, SearchApp, SearchUI
- Teams, MSTeams
- Spotify, Discord
- Steam, EpicGamesLauncher
- Adobe updaters
- Intel Driver Assistant
- Copilot, WindowsCopilot

### Plan de energía

- Intenta activar "Ultimate Performance"
- Si no existe, crea el plan
- CPU mínimo: 100% (sin throttling)
- Core parking desactivado

### Revertir

Cuando ejecutás `revert`:

1. Restaura el plan de energía original
2. Reactiva todos los servicios detenidos
3. Reactiva background apps
4. Restaura efectos visuales
5. Elimina el estado turbo

### Estado

El estado se guarda en `rescue/turbo_state.json` con:
- Timestamp de activación
- Lista de servicios detenidos
- Lista de procesos cerrados
- Plan de energía original

### ⚠️ Importante

- **NO** es para uso diario
- **SIEMPRE** revertí cuando terminés
- Solo usá para: edición de video, compilación, renderizado, gaming
- NO usá para: navegación, ofimática, YouTube

---

## 9. Emergencia

**Script:** `scripts/emergencia.ps1`
**Opción del menú:** `[9]`

### ¿Qué hace?

Restaura TODO al estado original. Es el "botón de pánico".

### Qué restaura

1. **Plan de energía** → Equilibrado (default)
2. **Servicios** → Todos en Automatic
3. **Efectos visuales** → Default de Windows
4. **Background apps** → Reactivadas
5. **Telemetría** → Reactivada (necesaria para updates)
6. **Windows Update** → Reactivado
7. **CPU priorities** → Default
8. **Superfetch** → Reactivado (si no es SSD)
9. **Tips** → Reactivados
10. **Turbo state** → Eliminado

### ¿Cuándo usarlo?

- Si algo no funciona después de optimizar
- Si la PC va rara después del Turbo Boost
- Si querés volver al estado de fábrica
- Si Windows Update no funciona
- Si algún servicio se rompió

### ¿Pide confirmación?

Sí. Pide escribir "SI" para confirmar. Después ofrece reiniciar.

---

## 10. Archivos del sistema

### Estructura

```
MejoraNotebook/
├── INICIAR.bat              # Launcher (click derecho → admin)
├── win-optimizer.ps1        # Menú principal
├── README.md                # Este archivo
├── TUTORIAL.md              # Guía paso a paso
├── MANUAL.md                # Documentación completa
├── LICENSE                  # Licencia MIT
├── scripts/
│   ├── config.ps1           # Configuración compartida
│   ├── benchmark.ps1        # Diagnóstico
│   ├── rescue.ps1           # Rescue points
│   ├── debloater.ps1        # Eliminar bloatware
│   ├── startup-cleaner.ps1  # Limpiar inicio
│   ├── services.ps1         # Optimizar servicios
│   ├── performance.ps1      # Tweaks de rendimiento
│   ├── memory.ps1           # Optimizar RAM
│   ├── turbo-boost.ps1      # Turbo Boost
│   └── emergencia.ps1       # Restaurar todo
├── logs/                    # Logs automáticos
│   ├── optimizer_*.log      # Log de optimizaciones
│   └── benchmark_*.json     # Reportes de benchmark
└── rescue/                  # Rescue points
    └── *_YYYY-MM-DD_HH-mm-ss/
        ├── startup.json     # Programas de inicio
        ├── services.csv     # Estado de servicios
        ├── visual.json      # Efectos visuales
        ├── powerplan.txt    # Plan de energía
        ├── apps.csv         # Apps instaladas
        └── system.json      # Config del sistema
```

### Logs

Cada ejecución genera un log en `logs/optimizer_YYYY-MM-DD_HH-mm-ss.log` con:
- Timestamp de cada acción
- Qué se hizo
- Errores encontrados
- Resultado de cada paso

### Rescue Points

Cada rescue point es una carpeta en `rescue/` con:
- `startup.json` — Programas de inicio
- `services.csv` — Estado de todos los servicios
- `visual.json` — Configuración de efectos visuales
- `powerplan.txt` — Plan de energía activo
- `apps.csv` — Lista de apps instaladas
- `system.json` — Pagefile, variables de entorno

---

## Preguntas frecuentes

### ¿Esto es seguro?

Sí. Todo es reversible. El Rescue Point guarda todo antes de tocar. El script de Emergencia restaura todo.

### ¿Pierdo datos?

No. Solo se desinstalan apps preinstaladas de Windows que se pueden reinstalar desde Microsoft Store. No se tocan archivos personales.

### ¿Funciona en Windows 10?

Sí, la mayoría de los tweaks funcionan en Windows 10. Algunos (como Copilot) son específicos de Windows 11.

### ¿Necesito internet?

No. Todo funciona sin conexión.

### ¿Cuánto espacio libra el Debloater?

Depende de las apps instaladas, típicamente 500 MB - 2 GB.

### ¿El Turbo Boost daña la PC?

No. Solo optimiza software. No modifica hardware ni voltajes. Es como cerrar apps manualmente pero más rápido.

### ¿Puedo usar Turbo Boost todo el tiempo?

No se recomienda. Solo para trabajo intenso. Para uso diario, usá las optimizaciones normales.

### ¿Qué pasa si no revierto el Turbo Boost?

Los servicios detenidos no se reinician. Windows Update no funciona. Algunas apps no arrancan. Por eso siempre hay que revertir.

---

## Licencia

MIT License — Hacé lo que quieras.
