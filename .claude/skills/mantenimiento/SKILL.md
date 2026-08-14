---
name: mantenimiento
description: Rutina completa de mantenimiento de la PC de Pablo (MejoraPC) — barrido total del equipo, foto/snapshot del estado, reanálisis + investigación de anomalías, pruebas de hardware, chequeo de drivers, optimización, y aprendizaje de hábitos de uso para personalizar cada corrida siguiente. Usar SIEMPRE que Pablo diga la palabra "mantenimiento" sola o en frase ("hacé mantenimiento", "toca mantenimiento"), en el repo MejoraPC.
---

# Mantenimiento (MejoraPC)

Rutina estándar cuando Pablo dice **"mantenimiento"**. Es la unión de todo
lo que ya hace `run.ps1` en modo automático MÁS los pasos de diagnóstico
profundo que se agregaron el 2026-08-14 (barrido de hardware, auditoría
generalizada de arranque, aprendizaje de hábitos). No es una herramienta
nueva y separada — es la forma repetible de todo lo que se hizo a mano en
esa sesión, para no reinvestigar desde cero cada vez.

## Antes de arrancar

1. Repasar memoria relevante ya guardada (`[[project_uwp_startup_blindspot]]`
   y cualquier otra memoria de tipo `project`/`feedback` sobre esta PC) para
   no re-investigar algo que ya se resolvió — solo confirmar que sigue así.
2. Confirmar que se corre desde una consola con privilegios de administrador
   (varios pasos lo requieren, igual que el resto de MejoraPC).

## Pasos (en orden)

1. **Barrido total + optimización** — correr `.\run.ps1` (modo automático,
   sin `-Menu`). Esto ya encadena: descubrimiento (si es la primera vez),
   monitor invisible, scan de hardware antes/después, backup, debloat,
   performance, estética, seguridad, python cleanup (solo reporte), análisis
   inteligente, auto-ajuste, verificación real (`13-verify.ps1`), informe
   consolidado y dashboard HTML. No repetir manualmente ninguno de estos
   pasos sueltos — `run.ps1` ya los orquesta todos.

2. **Pruebas de hardware** — correr `.\modules\15-hardware-check.ps1 -Auto`.
   Reporta salud de disco (SMART/reliability), CPU (carga, throttling,
   errores WHEA), RAM (capacidad, errores en Event Log) y drivers
   (antigüedad, dispositivos con problema vía `pnputil`, actualizaciones
   disponibles vía `winget upgrade` filtradas a fabricantes de driver). Solo
   reporta — nunca instala ni actualiza nada solo.

3. **Auditoría de arranque** — correr `.\modules\16-startup-audit.ps1 -Auto`.
   Es la versión repetible del barrido manual que se hizo el 2026-08-14
   (Run/RunOnce, carpetas Startup, tareas programadas Logon/Boot, Winlogon
   Shell/Userinit, AppInit_DLLs, y StartupTask de apps UWP/Store). Reafirma
   solo lo que ya está aprobado en `profile-local.json` →
   `startup_disable_uwp` (si algo volvió a activarse por una actualización de
   la app, lo vuelve a apagar sin preguntar — decisión ya tomada). Todo lo
   que aparece como hallazgo nuevo (`nuevos` en `data/last-startup-audit.json`)
   se reporta, no se toca.

4. **Reanalizar / investigar / pensar** — leer y cruzar:
   - `data/last-verify.json`, `data/last-hardware-check.json`,
     `data/last-startup-audit.json`, `data/discovery-report.json`.
   - Recomendaciones pendientes en `mejorapc.db` (tabla
     `smart_recommendations` — o correr `python monitor\report.py` para
     verlas resumidas).
   - Si `15-hardware-check.ps1` o `16-startup-audit.ps1` reportaron algo en
     WARN/ERROR/`nuevos` que no está ya cubierto por memoria o por el
     catálogo, investigarlo a fondo con el mismo criterio forense usado el
     2026-08-14 (barrer registro, tareas programadas, procesos activos,
     `Get-AppxPackage`, etc. — no conformarse con el primer hallazgo, buscar
     la causa real antes de proponer nada).

5. **Proponer antes de aplicar lo delicado** — todo lo de riesgo medio/alto
   (actualizar un driver, tocar algo fuera de lo ya aprobado en
   `profile-local.json`) se resume y se pide UNA confirmación, igual que el
   patrón Bloque B de `02-debloat.ps1`. Nunca se auto-aplica en silencio.
   Lo de bajo riesgo ya lo aplicó `run.ps1` en el paso 1 sin preguntar,
   como siempre.

6. **Aprender y guardar** — al cerrar la corrida:
   - Si aparece un patrón de uso genuinamente nuevo (no un dato crudo que ya
     vive en `mejorapc.db` vía `analyze.py`/`smart_recommendations` — eso ya
     es la fuente de verdad, no duplicarlo), guardarlo como memoria de
     proyecto: qué se decidió y por qué, no el dato en sí.
   - Actualizar/crear una memoria corta con la fecha de este mantenimiento,
     qué cambió, y qué quedó pendiente de confirmación — así el próximo
     "mantenimiento" arranca sabiendo qué ya se resolvió.
   - Si se aprobó algo nuevo que valga la pena que el catálogo reconozca
     de ahí en más (ej. un nuevo `startup_disable_uwp`), agregarlo a
     `data/profile-local.json` con el mismo criterio que ya tiene el archivo
     (ver ejemplo de la entrada `startup_disable_uwp` existente).

7. **Cerrar corto** — el dashboard (`logs/dashboard.html`) ya se abre solo al
   final de `run.ps1`. El resumen para Pablo en el chat va aparte, en texto
   plano y corto: qué se aplicó, qué se propone y falta confirmar, y (si
   corresponde) qué se aprendió de nuevo sobre cómo usa la PC.

## Qué NO hacer

- No reinstalar drivers ni ejecutar `pnputil`/`winget upgrade` en modo
  instalación sin que Pablo confirme cada uno.
- No reiniciar la PC sola (el diagnóstico de memoria de Windows, `mdsched.exe`,
  requiere reinicio — proponerlo, no dispararlo).
- No repetir el barrido manual completo del registro si `16-startup-audit.ps1`
  ya lo automatizó — usar el módulo, no reinventar los comandos sueltos cada
  vez (salvo para investigar un hallazgo nuevo puntual).
