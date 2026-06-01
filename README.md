# MejoraPC

Optimizador de rendimiento para Windows 10/11. Requiere PowerShell 5.1 como Administrador.

```powershell
.\run.ps1
```

## Módulos

| # | Nombre | Descripción |
|---|--------|-------------|
| 01 | Startup | Listado y gestión de programas de inicio |
| 02 | Servicios | Servicios candidatos a deshabilitar |
| 03 | Visual | Efectos visuales (rendimiento / equilibrado) |
| 04 | Red | Limpieza DNS, reset TCP/IP |
| 05 | Privacidad | Telemetría, publicidad, seguimiento |
| 06 | Gaming | Modo juego, Game DVR, plan de energía |
| **07** | **Escaneo** | Escaneo completo de hardware + recomendaciones |
| **08** | **Monitor** | Daemon de monitoreo + análisis inteligente |
| **09** | **Dashboard** | Reporte visual con gráficos ASCII |

---

## 07 — Escaneo de Hardware

Detecta CPU, RAM, GPU, almacenamiento, red y placa madre. Genera recomendaciones adaptadas al hardware real.

**Archivos generados:**
- `data/hardware-profile.json` — perfil completo
- `data/recommendations.json` — optimizaciones específicas
- `logs/scan-YYYY-MM-DD.json` — log del escaneo

**Recomendaciones automáticas:**
- RAM < 8 GB → ajuste de paginación virtual
- HDD → deshabilitar indexación, programar defrag
- SSD → verificar TRIM, excluir de defrag
- CPU < 4 núcleos → reducir efectos visuales
- GPU VRAM < 4 GB → tweaks de calidad gráfica
- RAM ≥ 16 GB → deshabilitar hibernación

**Temperatura de CPU/GPU:** disponible si [OpenHardwareMonitor](https://openhardwaremonitor.org/) está corriendo.

---

## 08 — Monitor Inteligente

Corre en background como scheduled task. Aprende los patrones de uso del equipo y genera recomendaciones concretas.

```powershell
# Instalar monitoreo automático
.\08-monitor.ps1 -Install

# Con AutoTune (aplica ajustes de bajo riesgo automáticamente los domingos)
.\08-monitor.ps1 -Install -EnableAutoTune

# Desinstalar
.\08-monitor.ps1 -Uninstall
```

**Tareas programadas instaladas:**
| Tarea | Frecuencia | Acción |
|-------|-----------|--------|
| `MejoraPC-Monitor` | Cada 15 min | Registra CPU%, RAM%, I/O, top 10 procesos |
| `MejoraPC-WeeklyAnalysis` | Domingos 03:00 | Analiza 7 días y genera recomendaciones |
| `MejoraPC-AutoTune` | Domingos 03:30 | Aplica ajustes de bajo riesgo (solo con `-EnableAutoTune`) |

**Patrones detectados:**
- Procesos siempre en top 10 que no son del sistema → candidatos a deshabilitar
- Horas pico de CPU > 70% → sugerir cambio de power plan por horario
- RAM > 85% en más del 30% de las muestras → ampliar RAM virtual
- Disco I/O > 80% frecuente → reprogramar indexación o antivirus
- Apps de startup no usadas en las primeras 2 horas → candidatos a sacar del inicio

**Retención:** 30 días. Máximo 500 KB por archivo diario.

---

## 09 — Dashboard

Vista consolidada del estado del sistema.

```powershell
.\09-report.ps1
```

**Muestra:**
- Resumen de hardware con score de salud (0–100)
- Gráfico de barras ASCII de CPU y RAM por hora (últimas 24 hs)
- Top 5 procesos más consumidores de la última semana
- Recomendaciones de hardware pendientes (de 07-scan)
- Recomendaciones inteligentes pendientes (de 08-monitor)

**Score de salud:**
| Rango | Estado |
|-------|--------|
| 80–100 | Excelente |
| 60–79 | Bueno |
| 40–59 | Regular |
| 0–39 | Necesita atención |

Factores: cantidad de RAM, tipo de almacenamiento (SSD > HDD), núcleos de CPU, temperatura.

---

## Estructura

```
MejoraPC/
├── run.ps1
├── lib/helpers.ps1
├── data/
│   ├── hardware-profile.json
│   ├── recommendations.json
│   └── smart-recommendations.json
├── logs/
│   ├── scan-YYYY-MM-DD.json
│   └── usage/YYYY-MM-DD.json
├── 01-startup.ps1 … 09-report.ps1
```

## Requisitos

- Windows 10 / 11
- PowerShell 5.1+
- Ejecutar como **Administrador**
- Opcional: OpenHardwareMonitor para temperaturas
