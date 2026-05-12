# 📋 PROGRESS — MejoraNotebook

> **Archivo de continuidad.** Cuando digas "continuemos", lee este archivo.
> Última sesión: 2026-05-13 07:19 UTC+8

---

## Estado actual

| Campo | Valor |
|-------|-------|
| **Versión** | v3.0.1 |
| **Módulos** | 29 scripts PowerShell + menú rediseñado |
| **Branch** | main |
| **Repo** | https://github.com/pabloeckert/MejoraNotebook |
| **Último commit** | `c759910` — fix: v3.0.1 auditoría profunda |
| **Commits totales** | 27 |
| **Estado** | ⏳ Pendiente de push |

---

## Qué se hizo hoy (2026-05-13)

### Fase 1: Rediseño UX del menú (v3.0.0)
- Menú completamente rediseñado desde cero
- Dashboard en vivo con estado del sistema (CPU, RAM, Disco, Servicios, Procesos, Startup)
- Navegación por 5 categorías en vez de 30+ opciones planas
- ASCII art banner con progress bars dinámicos
- Submenús contextuales con descripciones
- Componentes de UI reutilizables (Draw-Box, Draw-StatusBar, Draw-MenuItem)
- Paleta de diseño centralizada
- Flujo guiado: Diagnóstico → Optimizar → Modos → Seguridad → Herramientas

### Fase 2: Auditoría profunda (v3.0.1)
- Auditoría de 29 scripts (~8200 líneas de código)
- 9 bugs corregidos
- 12 mejoras de seguridad y arquitectura aplicadas

#### Bugs corregidos (9)
1. `rescue.ps1` — `$rescueDirs[$i]` → `$rescueDirs[$idx]` (nombre incorrecto al restaurar)
2. `profiles.ps1` — `param()` movido antes de `. config.ps1` (parámetros no funcionaban al invocar)
3. `startup-cleaner.ps1` — Detectar HKCU vs HKLM correctamente al desactivar items de registry
4. `html-report.ps1` — Versión hardcodeada actualizada a v3.0.0
5. `debloater.ps1` — Eliminados duplicados (Disney, Spotify aparecían dos veces)
6. `services.ps1` — Ahora incluye "Automatic (Delayed Start)" además de "Automatic"
7. `turbo-boost.ps1` — `Set-ItemProperty` → `Set-RegProperty` (respeta DryRun)
8. `gaming-mode.ps1` — Mismo fix de consistencia DryRun
9. `daemon.ps1` — `Add-Type` movido al inicio (evita re-declaración cada 60s)

#### Mejoras de seguridad (6)
1. Auto rescue point en `services.ps1`, `performance.ps1`, `turbo-boost.ps1`, `gaming-mode.ps1`
2. Confirmación explícita "SI" en Turbo Boost y Gaming Mode antes de activar
3. Advertencia DNS en Network Optimizer (cambia a 1.1.1.1/8.8.8.8)
4. `#Requires -Version 5.1` en `config.ps1` para fail-fast
5. Advertencia sobre redes corporativas en Network Optimizer
6. Auto rescue point antes de Optimizar Todo (ya existía, verificado)

#### Mejoras de arquitectura (6)
1. Lista centralizada de bloatware en `config.ps1` (`$Global:BloatwareApps`)
2. Descripciones centralizadas en `config.ps1` (`$Global:AppDescriptions`)
3. Versión centralizada en `config.ps1` (`$Global:AppVersion = "3.0.0"`)
4. `debloater.ps1` y `app-store.ps1` usan listas centralizadas (eliminada duplicación)
5. `win-optimizer.ps1` usa `$Global:AppVersion` en vez de hardcodear
6. Rotación de logs en daemon (max 1MB, mantiene `.old`)

---

## Archivos modificados hoy

| Archivo | Cambios |
|---------|---------|
| `win-optimizer.ps1` | Reescrito: dashboard + categorías + componentes UI |
| `INICIAR.bat` | ASCII art actualizado v3.0.0 |
| `scripts/config.ps1` | #Requires, versión, bloatware centralizado, descripciones |
| `scripts/debloater.ps1` | Usa lista centralizada, duplicados eliminados |
| `scripts/app-store.ps1` | Usa listas centralizadas |
| `scripts/services.ps1` | Auto rescue point, "Delayed Start" incluido |
| `scripts/performance.ps1` | Auto rescue point |
| `scripts/turbo-boost.ps1` | Confirmación, rescue point, DryRun fix |
| `scripts/gaming-mode.ps1` | Confirmación, rescue point, DryRun fix |
| `scripts/network-optimizer.ps1` | Advertencia DNS |
| `scripts/rescue.ps1` | Bug $i → $idx |
| `scripts/profiles.ps1` | Bug param() order |
| `scripts/startup-cleaner.ps1` | Bug HKCU/HKLM |
| `scripts/html-report.ps1` | Versión actualizada |
| `scripts/daemon.ps1` | Add-Type fix, log rotation |
| `README.md` | v3.0.0, sección nuevo menú |
| `CHANGELOG.md` | v3.0.0 y v3.0.1 documentados |
| `PROGRESS.md` | Este archivo |

---

## Estado del proyecto

### ✅ Completado
- [x] 29 scripts funcionales
- [x] Menú UX rediseñado con dashboard
- [x] Auditoría profunda completada
- [x] Bugs corregidos
- [x] Seguridad mejorada (auto-rescue, confirmaciones)
- [x] Arquitectura mejorada (listas centralizadas)
- [x] Documentación actualizada

### ⏳ Pendiente
- [ ] Push a GitHub (commit `c759910` local, sin push)
- [ ] Testing real en Windows (auditado solo en Linux)
- [ ] Revisar issues en GitHub si los hay

---

## Próximos pasos sugeridos

1. **Push a GitHub** — ejecutar `./push.sh` desde la notebook
2. **Testing real** — correr cada script en la BANGHO MAX L5
3. **Posibles mejoras pendientes** (de la auditoría):
   - Tests automatizados con mocks
   - Verificación de integridad de scripts
   - Multi-disco SSD detection
   - Help global [H] en el menú
   - Feedback post-acción (antes/después) en cada script

---

## Configuración Git

Remote: `https://pabloeckert@github.com/pabloeckert/MejoraNotebook.git`
Push: `git push origin main` o `./push.sh "mensaje"`
Nota: no hay credenciales de GitHub en el servidor de desarrollo. Push manual desde notebook.

---

*Última actualización: 2026-05-13 07:19 UTC+8*
