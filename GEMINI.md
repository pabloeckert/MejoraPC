# MejoraNotebook - Instrucciones para el Agente Gemini

Este archivo proporciona contexto técnico y pautas de desarrollo para el proyecto **MejoraNotebook**, un optimizador de Windows 11 basado en PowerShell, diseñado originalmente para notebooks Bangho Max L5 pero compatible con sistemas Windows modernos.

## 🚀 Descripción General
El proyecto es una suite modular de scripts de PowerShell que automatiza la optimización del sistema, eliminando bloatware, ajustando servicios, mejorando el rendimiento visual y gestionando el consumo de recursos (CPU/RAM).

### Arquitectura
- **Punto de Entrada:** `win-optimizer.ps1` proporciona un menú interactivo basado en categorías.
- **Lanzador Admin:** `INICIAR.bat` asegura la ejecución con privilegios elevados.
- **Núcleo de Configuración:** `scripts/config.ps1` contiene variables globales, listas centralizadas (servicios, bloatware) y funciones auxiliares.
- **Módulos:** Ubicados en `scripts/`, cada uno se encarga de una tarea específica (e.g., `debloater.ps1`, `performance.ps1`).
- **Seguridad:** `scripts/rescue.ps1` gestiona "Rescue Points" (respaldos) antes de aplicar cambios.

## 🛠️ Comandos Clave

### Ejecución
- **Menú Interactivo:** `.\win-optimizer.ps1` (Debe ejecutarse como Administrador).
- **Modo Silencioso:** `.\win-optimizer.ps1 -Silent` (Aplica optimizaciones automáticas).
- **Simulación (Dry-Run):** `.\win-optimizer.ps1 -DryRun` o `.\win-optimizer.ps1 -Silent -DryRun`.
- **Con Gaming Mode:** `.\win-optimizer.ps1 -WithGaming`.

### Desarrollo y Diagnóstico
- **Benchmark rápido:** `.\scripts\benchmark.ps1 -Mode rapido`.
- **Generar Reporte HTML:** `.\scripts\html-report.ps1`.
- **Iniciar Monitoreo (Daemon):** `.\scripts\daemon.ps1 -Action start`.

## 📏 Convenciones de Desarrollo

### 1. Seguridad y Reversibilidad
- **SIEMPRE** crear un punto de restauración antes de realizar cambios estructurales: `& "$PSScriptRoot\rescue.ps1" -Action create -Name "mi-cambio"`.
- **Validación Admin:** Todos los scripts deben comenzar con `. "$PSScriptRoot\config.ps1"` seguido de `Assert-Admin`.

### 2. Configuración Centralizada
- **NO** hardcodear listas de servicios o apps en los módulos. Usar las variables globales definidas en `scripts/config.ps1` (e.g., `$Global:BloatwareApps`, `$Global:ServicesToManual`).

### 3. Modo Dry-Run
- Para asegurar que los scripts respeten el modo de simulación, utilizar los wrappers definidos en `config.ps1`:
  - `Set-RegProperty`: Para cambios en el registro.
  - `Set-ServiceState`: Para cambiar el estado de servicios.
- Consultar `$Global:DryRun` antes de realizar acciones destructivas.

### 4. Interfaz de Usuario (PowerShell)
Utilizar las funciones estándar de `config.ps1` para mantener la consistencia visual:
- `Write-Header "TÍTULO"`: Encabezados de sección.
- `Write-Step $n "Acción"`: Pasos numerados.
- `Write-Success`, `Write-Warn`, `Write-Error`, `Write-Info`: Mensajes con colores predefinidos.

### 5. Registro (Logging)
- Utilizar la función `Log "Mensaje"` para registrar eventos. Los logs se guardan en la carpeta `logs/` con el formato `optimizer_yyyy-MM-dd_HH-mm-ss.log`.

## 🔍 Estructura de Archivos Importante
- `win-optimizer.ps1`: Lógica principal del menú y dashboard.
- `scripts/config.ps1`: El "corazón" del proyecto. Contiene la configuración global.
- `scripts/rescue.ps1`: Lógica de backup y restauración.
- `scripts/benchmark.ps1`: Sistema de diagnóstico y comparación.
- `scripts/daemon.ps1`: Proceso de fondo para monitoreo y aprendizaje automático.
- `PROGRESS.md`: Archivo de seguimiento del estado del proyecto. **Leer siempre al iniciar una sesión.**

## 🧪 Testing
Actualmente, el proyecto no cuenta con un framework de tests automatizados (como Pester). Las validaciones se realizan mediante:
1. **Modo Dry-Run:** Para verificar la lógica sin aplicar cambios.
2. **Post-Operación:** Uso de `Confirm-ServiceState` y `Confirm-RegistryValue` para validar la aplicación de cambios.
