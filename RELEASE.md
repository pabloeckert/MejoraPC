# 🚀 RELEASE — MejoraNotebook v2.2.0

**Fecha:** 2026-05-13
**Estado:** ✅ PRODUCCIÓN — RELEASE ESTABLE

---

## ¿Qué es?

Optimizador de Windows 11 para notebooks. Sin romper nada, todo reversible.

Diseñado para la **BANGHO MAX L5** (i7-10510U, 8GB RAM) pero funciona en cualquier Windows 11.

---

## Instalación

```bash
git clone https://github.com/pabloeckert/MejoraNotebook.git
cd MejoraNotebook
```

Click derecho en `INICIAR.bat` → **Ejecutar como administrador**

---

## Módulos incluidos (29 scripts)

### 🔧 Optimización
| Módulo | Descripción |
|--------|-------------|
| Debloater | Elimina ~30 apps bloatware |
| Startup Cleaner | Limpia programas de inicio |
| Services Optimizer | Desactiva servicios innecesarios |
| Performance Tweaks | Efectos visuales, energía, telemetría |
| Memory Optimizer | Libera RAM, ajusta pagefile |
| Disk Cleanup | Temp, WU cache, navegadores, papelera |
| Network Optimizer | TCP/DNS/latencia optimizados |

### 🎮 Modos especiales
| Módulo | Descripción |
|--------|-------------|
| Turbo Boost | Modo máximo rendimiento (CPU 100%, servicios mínimos) |
| Gaming Mode | Optimizado para gaming (Game DVR off, GPU prioridad) |

### 🛡️ Respaldo y seguridad
| Módulo | Descripción |
|--------|-------------|
| Rescue Point | Crear/restaurar respaldo del sistema |
| Emergencia | Restaurar TODO al estado original (12 pasos) |
| Uninstall Tool | Desinstalador completo con restauración |

### 📊 Monitoreo
| Módulo | Descripción |
|--------|-------------|
| Benchmark | Diagnóstico completo + CSV + HTML |
| Health Check | Verificación rápida del sistema |
| Dashboard | Servidor web con gráficos en tiempo real |
| Compare | Comparar benchmarks (antes/después) |
| Share Benchmark | Exportar/importar benchmarks entre PCs |

### 🤖 Automatización
| Módulo | Descripción |
|--------|-------------|
| **Daemon** | **Monitoreo silencioso con aprendizaje automático** |
| Scheduler | Benchmark semanal automático |
| Auto-updater | Actualización automática desde GitHub |
| Notifications | Notificaciones toast para Windows |

### 🧩 Herramientas
| Módulo | Descripción |
|--------|-------------|
| Wizard | Modo guiado para principiantes |
| App Store | Reinstalar apps desinstaladas |
| Profiles | Guardar/cargar configuraciones |
| WU Blocker | Pausar/reanudar Windows Update |
| Driver Updater | Escaneo de drivers |
| Offline Pack | Exportar para uso sin internet |
| HTML Report | Reporte visual del benchmark |

---

## Características principales

### 🤖 Daemon de monitoreo silencioso
- Se ejecuta en segundo plano
- Aprende patrones de uso (horas activas, procesos frecuentes)
- Optimiza automáticamente (libera RAM, cierra procesos seguros)
- Protege procesos críticos (navegadores, IDEs, comunicación)
- Configurable (umbrales, intervalos, notificaciones)

### 🛡️ Seguridad
- Rescue Point antes de cada cambio
- No toca Windows Defender, VBS, ni BitLocker
- Emergencia restaura TODO con un click
- Todo es reversible
- Modo DRY-RUN para simular sin aplicar cambios
- Validación post-optimización
- Logs detallados de cada operación

### 📊 Monitoreo completo
- Benchmark con comparación antes/después
- Dashboard web con gráficos en tiempo real
- Exportación a CSV para histórico
- Comparación entre PCs
- Reporte HTML visual

---

## Requisitos

- Windows 11 (también funciona en Windows 10)
- Permisos de administrador
- PowerShell 5.1+

---

## Resultado estimado

| Antes | Después |
|-------|---------|
| 1.4 GB RAM libre | 3-4 GB RAM libre |
| 50+ servicios corriendo | ~20 servicios |
| 10+ programas en inicio | 2-3 programas |
| Efectos visuales full | Mínimos/Off |
| Telemetría activa | Desactivada |

---

## Licencia

MIT — Hacé lo que quieras con esto.

---

## Créditos

Inspirado en [MejoraRedmi14c](https://github.com/pabloeckert/MejoraRedmi14c) — el mismo concepto pero para Android.

---

**Tag:** v2.2.0
**Commit:** a294b23
**Módulos:** 29 scripts PowerShell
