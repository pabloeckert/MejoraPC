# 🔥 MejoraNotebook — Win Optimizer v3.0.1

**Optimizador de Windows 11 para notebooks. Sin romper nada, todo reversible.**

Diseñado para la **BANGHO MAX L5** (i7-10510U, 8GB RAM) pero funciona en cualquier Windows 11.

---

## ⚡ Instalación rápida

```bash
git clone https://github.com/pabloeckert/MejoraNotebook.git
cd MejoraNotebook
```

Después: click derecho en `INICIAR.bat` → **Ejecutar como administrador**

## 🖥️ Nuevo menú v3.0.0

El menú se rediseñó desde cero con una experiencia guiada e intuitiva:

```
  ┌─── ESTADO DEL SISTEMA ──────────────────────────────┐
  │  🟢 CPU   12%  [██░░░░░░░░░░░░░░░░░░]   12%        │
  │  🟡 RAM   71%  [██████████████░░░░░░]   71%         │
  │       2.3 GB libre de 8 GB                          │
  │  🟢 Disco  58% [████████████░░░░░░░░]   58%         │
  │       95 GB libre de 238 GB                         │
  │  ⚙️  Servicios: 87 activos de 230                   │
  │  🚀 Inicio:     8 programas                         │
  │  📊 Procesos:   142                                 │
  └───────────────────────────────────────────────────────┘

  ¿Qué necesitás hacer?

  [1] 🔍  Diagnóstico          — Ver cómo está tu notebook ahora
  [2] 🚀  Optimizar            — Limpiar, acelerar y liberar recursos
  [3] ⚡  Modos especiales     — Turbo Boost, Gaming Mode, Red
  [4] 🛡️  Seguridad y respaldo — Rescue points, perfiles, emergencia
  [5] 🧰  Herramientas         — Drivers, apps, reportes, actualizaciones
```

**Cambios clave:**
- Dashboard en vivo con estado del sistema (CPU, RAM, Disco, Servicios)
- 5 categorías claras en vez de 30+ opciones planas
- Submenús contextuales con descripciones de cada función
- Wizard accesible desde "Optimizar" para principiantes
- Progresión natural: diagnosticar → optimizar → proteger

## 🎯 ¿Qué hace?

| Módulo | Descripción | Impacto |
|--------|-------------|---------|
| 🔍 Benchmark | Diagnóstico completo del sistema | Info |
| 🗑️ Debloater | Elimina ~30 apps basura de Windows | 🔥🔥🔥 |
| ⚡ Startup Cleaner | Limpia programas de inicio | 🔥🔥 |
| 🔧 Services Optimizer | Desactiva servicios innecesarios | 🔥🔥 |
| 🚀 Performance | Efectos visuales, plan energía, telemetría | 🔥🔥🔥 |
| 💾 Memory Optimizer | Libera RAM, ajusta pagefile | 🔥🔥 |
| 🧹 Disk Cleanup | Temp files, WU cache, navegadores, papelera | 🔥🔥 |
| 🎮 Gaming Mode | Game DVR off, GPU prioridad, baja latencia | 🔥🔥🔥 |
| 📂 Profiles | Guardar/cargar configuraciones | 🔥🔥 |
| 🔒 WU Blocker | Pausar/reanudar Windows Update | 🔥🔥 |
| 📊 Reporte HTML | Benchmark visual exportado a HTML | 🔥 |
| ⏰ Scheduler | Benchmark semanal automático | 🔥 |
| 🗑️ Uninstall Tool | Desinstalador completo con restauración | 🛡️ |
| 🌐 Network Optimizer | TCP/DNS/latencia optimizados | 🔥🔥 |
| 🏥 Health Check | Verificación rápida del sistema | 🔥 |
| 🔧 Driver Updater | Escaneo de drivers y actualizaciones | 🔥 |
| 📥 Auto-updater | Actualización automática desde GitHub | 🔥 |
| 🧙 Wizard | Modo guiado para principiantes | 🔥🔥 |
| 📊 Compare | Comparar benchmarks + tendencia | 🔥 |
| 📦 Offline Pack | Exportar para uso sin internet | 🔥 |
| 🏪 App Store | Reinstalar apps desinstaladas | 🔥 |
| 📤 Share Benchmark | Comparar benchmarks entre PCs | 🔥 |
| 🌐 Dashboard | Monitoreo web en tiempo real | 🔥🔥🔥 |
| 🔔 Notifications | Notificaciones toast para Windows | 🔥 |
| 🤖 Daemon | Monitoreo silencioso + aprendizaje automático | 🔥🔥🔥🔥 |
| 🔥🔥🔥 TURBO BOOST | Modo máximo rendimiento | 🔥🔥🔥🔥🔥 |
| 🚨 Emergencia | Restaurar TODO si algo sale mal | 🛡️ |

## 🔥 Turbo Boost (el botón "casi overclocking")

Cuando necesitás máximo rendimiento para trabajo intenso:

- CPU al 100% siempre
- +40 servicios detenidos
- +20 procesos cerrados
- Todos los efectos visuales apagados
- Background tasks desactivados
- Prioridad CPU máxima para apps activas

Desde el menú: **[3] Modos especiales** → [1] Activar | [2] Revertir

## 🎮 Gaming Mode

Optimizado para jugar (diferente a Turbo Boost):

- Game DVR desactivado (el mayor killer de FPS)
- GPU prioridad máxima
- Red optimizada para baja latencia
- Servicios de audio/red **activos** (a diferencia de Turbo)
- Telemetría de fondo detenida

Desde el menú: **[3] Modos especiales** → [4] Activar | [5] Revertir

## 🧹 Disk Cleanup

Limpia basura del sistema:

- Archivos temporales del usuario y Windows
- Caché de Windows Update
- Thumbnails e iconos cache
- Prefetch (>30 días)
- Papelera de reciclaje
- Caché de navegadores (Chrome, Edge, Firefox)

Ejecutar: desde menú o como paso del "Optimizar Todo"

## 🔇 Modo Silencioso

Para reinstalaciones o configuración rápida — ejecuta todo sin prompts:

```powershell
# Optimización completa silenciosa
.\win-optimizer.ps1 -Silent

# Simular sin aplicar cambios
.\win-optimizer.ps1 -Silent -DryRun

# Incluir Gaming Mode
.\win-optimizer.ps1 -Silent -WithGaming
```

Incluye benchmark antes/después automáticamente.

## 📂 Profiles

Guardá y cargá configuraciones completas del sistema:

- **Trabajo:** servicios mínimos, rendimiento alto, telemetría off
- **Gaming:** Gaming Mode activo, Game DVR off
- **Default:** configuración de fábrica de Windows

Desde el menú: **[4] Seguridad y respaldo** → [3] Perfiles.

## 🔒 Windows Update Blocker

Pausá Windows Update cuando necesitás toda la RAM:

- Detiene el servicio Windows Update
- Bloquea descargas e instalaciones automáticas
- Bloquea reinicios automáticos
- Todo reversible con un click

Desde el menú: **[3] Modos especiales** → [7] Bloquear | [8] Desbloquear.

## 🛡️ Seguridad

- ✅ Rescue Point antes de cada cambio
- ✅ No toca Windows Defender, VBS, ni BitLocker
- ✅ Emergencia restaura todo con un click
- ✅ Todo es reversible
- ✅ Modo DRY-RUN para simular sin aplicar cambios
- ✅ Validación post-optimización (confirma que cada cambio se aplicó)
- ✅ Auto-detección de SSD vs HDD (ajusta servicios automáticamente)
- ✅ Logs detallados de cada operación

## 📖 Documentación

- **[TUTORIAL.md](TUTORIAL.md)** — Guía paso a paso
- **[MANUAL.md](MANUAL.md)** — Documentación completa de cada módulo

## 📊 Resultado estimado

| Antes | Después |
|-------|---------|
| 1.4 GB RAM libre | 3-4 GB RAM libre |
| 50+ servicios corriendo | ~20 servicios |
| 10+ programas en inicio | 2-3 programas |
| Efectos visuales full | Mínimos/Off |
| Telemetría activa | Desactivada |

## ⚠️ Requisitos

- Windows 11 (también funciona en Windows 10)
- Permisos de administrador
- PowerShell 5.1+

## Licencia

MIT — Hacé lo que quieras con esto.

## Créditos

Inspirado en [MejoraRedmi14c](https://github.com/pabloeckert/MejoraRedmi14c) — el mismo concepto pero para Android.
