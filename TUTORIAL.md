# 📖 TUTORIAL — Guía paso a paso

## Antes de empezar

### ¿Qué necesitás?

- Tu notebook con Windows 11
- Permisos de administrador (tu usuario debe ser admin)
- 5 minutos de tiempo

### ¿Qué NO necesitás?

- No necesitás instalar nada
- No necesitás conexión a internet
- No necesitás conocimientos técnicos

---

## Paso 1: Descargar

### Opción A: Git clone
```bash
git clone https://github.com/pabloeckert/MejoraNotebook.git
```

### Opción B: Descargar ZIP
1. Andá a https://github.com/pabloeckert/MejoraNotebook
2. Click en "Code" → "Download ZIP"
3. Descomprimí en cualquier carpeta

---

## Paso 2: Ejecutar

1. Abrí la carpeta `MejoraNotebook`
2. Click derecho en `INICIAR.bat`
3. Seleccioná **"Ejecutar como administrador"**
4. Si Windows pregunta "¿Querés permitir que esta app haga cambios?" → **Sí**

> ⚠️ **IMPORTANTE:** Si no lo ejecutás como administrador, no va a funcionar.

---

## Paso 3: Primer diagnóstico

Cuando se abra el menú, empezá por ver cómo está tu sistema:

```
Seleccioná: [1] 🔍 Benchmark completo
```

Esto te va a mostrar:
- Cuánta RAM tenés libre
- Cuántos programas de inicio hay
- Cuántos servicios están corriendo
- Si hay problemas detectados
- Si tu disco es SSD o HDD

**Anotá los números** para comparar después.

---

## Paso 4: Crear Rescue Point (respaldo)

Antes de tocar NADA, creá un respaldo:

```
Seleccioná: [2] 💾 Crear Rescue Point
```

Esto guarda:
- Todos tus programas de inicio
- Estado de todos los servicios
- Configuración de efectos visuales
- Plan de energía actual
- Lista de todas tus apps

**Si algo sale mal, podés restaurar todo con esto.**

---

## Paso 5: Optimizar

### Opción rápida: Todo automático

```
Seleccioná: [A] 🔥 OPTIMIZAR TODO
```

Esto ejecuta todos los pasos en orden:
1. Debloater (elimina apps basura)
2. Startup Cleaner (limpieza de inicio)
3. Services Optimizer (optimiza servicios)
4. Performance Tweaks (rendimiento)
5. Memory Optimizer (libera RAM)
6. Disk Cleanup (limpia archivos temporales)

Te va a pedir confirmación. También podés elegir modo **DRY-RUN** para simular sin aplicar cambios.

### Opción manual: Paso a paso

Si preferís controlar cada cosa:

```
[3] 🗑️  Debloater          → Eliminar apps basura
[4] ⚡  Startup Cleaner    → Limpiar inicio
[5] 🔧  Services Optimizer → Optimizar servicios
[6] 🚀  Performance        → Tweaks de rendimiento
[7] 💾  Memory Optimizer   → Liberar RAM
```

---

## Paso 6: Reiniciar

Después de optimizar, **reiniciá la notebook**.

```
Start → Energía → Reiniciar
```

Cuando vuelva, ejecutá el benchmark de nuevo para comparar:

```
Seleccioná: [1] 🔍 Benchmark completo
```

---

## Paso 7: Usar Turbo Boost (opcional)

Cuando necesitás máximo rendimiento para trabajo intenso:

```
Seleccioná: [T] 🔥🔥🔥 ACTIVAR TURBO BOOST
```

### ¿Cuándo usarlo?

- Editando video (Premiere, DaVinci, CapCut)
- Compilando código
- Renderizando 3D
- Usando Photoshop con archivos pesados
- Cualquier tarea que necesite toda la potencia

### ¿Cuándo NO usarlo?

- Navegación normal
- Ofimática (Word, Excel)
- YouTube, Netflix
- Uso casual del día a día

### Revertir

Cuando terminés de trabajar:

```
Seleccioná: [R] 🔄 Revertir Turbo Boost
```

**Siempre revertí el Turbo Boost cuando terminés.** No es para uso diario.

---

## Paso 8: Gaming Mode (opcional)

Cuando querés jugar:

```
Seleccioná: [G] 🎮 ACTIVAR Gaming Mode
```

### ¿Qué diferencia tiene con Turbo Boost?

| | Turbo Boost | Gaming Mode |
|---|---|---|
| CPU | 100% siempre | Balanceado |
| Audio | ❌ Detenido | ✅ Activo |
| Red | ❌ Detenida | ✅ Activa |
| Game DVR | Sin cambios | ❌ Desactivado |
| GPU | Sin cambios | ✅ Prioridad máxima |
| Latencia | Sin cambios | ✅ Optimizada |

**Usá Gaming Mode para jugar, Turbo Boost para compilar/renderizar.**

### Revertir

```
Seleccioná: [H] 🔄 Revertir Gaming Mode
```

---

## Modo Silencioso (avanzado)

Para reinstalaciones o configuración rápida, ejecutá todo sin prompts:

```powershell
# Optimización completa silenciosa
.\win-optimizer.ps1 -Silent

# Simular sin aplicar cambios
.\win-optimizer.ps1 -Silent -DryRun

# Incluir Gaming Mode
.\win-optimizer.ps1 -Silent -WithGaming
```

Incluye benchmark antes/después automáticamente.

---

## Perfiles (opcional)

Podés guardar tu configuración actual como perfil y cargarla después:

```
Seleccioná: [P] 📂 Perfiles
```

### ¿Para qué sirve?

- **Trabajo:** guardás una config de máximo rendimiento
- **Gaming:** guardás Gaming Mode activado
- **Default:** volvés a la config de fábrica

### Uso rápido

```
[P] → [2] Guardar perfil actual → nombre: "trabajo"
[P] → [3] Cargar perfil → seleccionar "trabajo"
```

---

## Windows Update Blocker (opcional)

Cuando Windows Update te come la RAM en medio de un trabajo importante:

```
Seleccioná: [W] 🔒 Windows Update Blocker
```

### ¿Cuándo usarlo?

- Presentaciones o demos
- Sesiones de gaming
- Trabajo intensivo donde no querés interrupciones
- Cuando tenés 8GB RAM y cada MB cuenta

### Uso

```
[W] → [2] Bloquear    → Pausa todo
[W] → [3] Desbloquear → Reactiva todo
```

**No te olvides de desbloquear** cuando terminés, para recibir actualizaciones de seguridad.

---

## Reporte HTML (opcional)

Generá un reporte visual del estado de tu sistema:

```
Seleccioná: [I] 📊 Generar reporte HTML
```

Abrilo en tu navegador para ver:
- Estado de RAM, CPU y disco con barras de colores
- Top 5 procesos que más RAM consumen
- Diagnóstico de problemas
- Comparación con benchmarks anteriores

---

## Optimización programada (opcional)

Programá un benchmark automático cada semana para detectar si tu sistema se degrada:

```
Seleccioná: [K] ⏰ Optimización programada → [2] Instalar
```

Cada lunes a las 10 AM ejecuta el benchmark y guarda el reporte. Después podés comparar con `[I]` para ver si algo cambió.

---

## ¿Algo salió mal?

### Problema: "No se ejecuta como administrador"

**Solución:** Click derecho en `INICIAR.bat` → "Ejecutar como administrador"

### Problema: "La ejecución de scripts está deshabilitada"

**Solución:** Abrí PowerShell como administrador y ejecutá:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Problema: "Algo no funciona después de optimizar"

**Solución 1:** Restaurar desde Rescue Point
```
Seleccioná: [8] 🔄 Restaurar Rescue Point
```

**Solución 2:** Emergencia (restaura TODO)
```
Seleccioná: [9] 🚨 EMERGENCIA - Restaurar TODO
```

### Problema: "La notebook va lenta después del Turbo Boost"

**Solución:** Revertí el Turbo Boost
```
Seleccioná: [R] 🔄 Revertir Turbo Boost
```

---

## Consejos

1. **Siempre** creá un Rescue Point antes de optimizar
2. **Siempre** revertí el Turbo Boost / Gaming Mode cuando terminés
3. **Reiniciá** después de las optimizaciones
4. **Probá con DRY-RUN** antes de aplicar si tenés dudas
5. **El Emergencia** es tu red de seguridad — usalo si algo falla
6. **Usá los logs** (`[L]`) para ver qué se hizo

---

## Desinstalar (si querés revertir todo)

Si querés deshacer todas las optimizaciones y eliminar el programa:

```
Seleccioná: [U] 🗑️ Desinstalador
```

Esto va a:
1. Restaurar todos los servicios a su estado original
2. Restaurar efectos visuales y plan de energía
3. Reactivar telemetría y Windows Update
4. Reactivar apps en segundo plano
5. Limpiar archivos de estado del programa
6. (Opcional) Eliminar la carpeta del programa

**Si tenés un Rescue Point, el desinstalador te ofrece restaurar desde él antes de eliminar.**

---

## ¿Preguntas?

Creá un issue en: https://github.com/pabloeckert/MejoraNotebook/issues
