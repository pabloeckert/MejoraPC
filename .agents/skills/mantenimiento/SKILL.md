---
name: mantenimiento
description: Rutina completa de mantenimiento preventivo y optimización de la PC de Pablo (MejoraPC) para Google Antigravity y Gemini — barrido total del equipo, snapshot del estado, reanálisis e investigación de anomalías, pruebas de hardware, chequeo de drivers, optimización y aprendizaje continuo de hábitos de uso. Activar cuando el usuario solicite "mantenimiento" en el repositorio MejoraPC.
---

# Mantenimiento Preventivo y Optimización (MejoraPC)

Rutina estándar de gobernanza técnica cuando se solicita **"mantenimiento"** en **MejoraPC**. Estandarizada bajo el entorno de **Google Antigravity** y **Gemini**.

Es la consolidación de `run.ps1` en modo automático junto con los procedimientos de diagnóstico profundo (barrido de hardware, auditoría generalizada de arranque, análisis de hábitos y optimización de sistema).

## Precondiciones Operativas

1. **Memoria y Contexto**: Repasar el contexto operativo y decisiones previas sobre la PC (`profile-local.json` y base de datos local `mejorapc.db`) para evitar re-investigar incidencias ya resueltas.
2. **Elevación de Privilegios**: Confirmar que la sesión de PowerShell cuenta con privilegios de Administrador para los módulos que interactúan con el kernel, controladores o registro de Windows.

## Flujo de Ejecución (Orden Secuencial)

1. **Barrido total + optimización**:
   - Ejecutar `.\run.ps1` (modo automático, sin `-Menu`).
   - Orquesta en cadena: descubrimiento, monitor en segundo plano, scan de hardware comparativo, backup preventivo, debloat, performance, estética, seguridad, auditoría de entornos Python, análisis inteligente, auto-ajuste, verificación real (`13-verify.ps1`), informe consolidado y apertura del dashboard HTML (`logs/dashboard.html`).

2. **Pruebas de hardware**:
   - Ejecutar `.\modules\15-hardware-check.ps1 -Auto`.
   - Evalúa estado SMART de discos, métricas y throttling de CPU, integridad de memoria RAM y antigüedad de drivers mediante `pnputil` y `winget`.
   - Modo reporte estricto: no instala ni modifica controladores sin confirmación explícita.

3. **Auditoría de arranque**:
   - Ejecutar `.\modules\16-startup-audit.ps1 -Auto`.
   - Inspecciona claves Run/RunOnce, carpetas Startup, tareas programadas de Logon/Boot, Winlogon Shell/Userinit y StartupTasks de apps UWP/Store.
   - Aplica de forma automática únicamente las reglas consolidadas en `profile-local.json` (`startup_disable_uwp`). Nuevos hallazgos se reportan a `data/last-startup-audit.json` sin alteración destructiva.

4. **Análisis, cruce de métricas y diagnóstico**:
   - Correlacionar métricas de:
     * `data/last-verify.json`, `data/last-hardware-check.json`, `data/last-startup-audit.json`, `data/discovery-report.json`.
     * Recomendaciones pendientes en `mejorapc.db` (tabla `smart_recommendations` o vía `python monitor\report.py`).
   - Si se detectan anomalías en estado WARN/ERROR o entradas no catalogadas, realizar análisis de causa raíz antes de proponer cambios.

5. **Protocolo de Cambios Delicados**:
   - Acciones de riesgo medio/alto (actualización de drivers, modificaciones fuera de `profile-local.json`) deben consolidarse y presentarse para confirmación expresa del usuario.
   - Acciones de bajo riesgo y saneamiento estándar son aplicadas automáticamente por el pipeline de `run.ps1`.

6. **Consolidación de Conocimiento y Aprendizaje**:
   - Registrar nuevos patrones de uso relevantes en `data/profile-local.json` o en la persistencia local.
   - Actualizar el registro del mantenimiento indicando fecha, componentes optimizados y puntos pendientes.

7. **Cierre de Ciclo**:
   - Presentar resumen ejecutivo en consola: optimizaciones aplicadas, métricas de rendimiento resultantes y recomendaciones para validación.

## Restricciones y Reglas de Seguridad

- **No reinstalar ni actualizar drivers** sin autorización expresa por dispositivo.
- **No reiniciar el equipo automáticamente** (si se recomienda diagnóstico de memoria de Windows con `mdsched.exe`, solicitar el reinicio al usuario).
- **Utilizar los módulos de automatización existentes** (`15-hardware-check.ps1`, `16-startup-audit.ps1`) en lugar de comandos ad-hoc repetitivos.
