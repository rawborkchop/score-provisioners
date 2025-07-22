# Score Provisioners

Este repositorio contiene provisioners personalizados para [score-compose](https://docs.score.dev/docs/score-implementation/score-compose/) que extienden las capacidades de [Score](https://score.dev) para desarrollo local y despliegue de aplicaciones.

## ¿Qué es Score-Compose?

[Score-compose](https://docs.score.dev/docs/score-implementation/score-compose/) es la implementación de la especificación Score que genera archivos Docker Compose. Score permite describir aplicaciones de forma declarativa y agnóstica a la plataforma.

### Funcionamiento de Score-Compose

Score-compose funciona en tres pasos principales:

1. **Recolección de Workloads**: Recopila y valida los archivos Score del usuario y contexto local
2. **Provisión de Recursos**: Provisiona todos los recursos mencionados en la sección `resources` de los archivos Score antes de convertir las cargas de trabajo a su formato final
3. **Conversión de Workloads**: Convierte las cargas de trabajo en manifiestos Docker Compose mientras resuelve todos los placeholders

### Flujo de Trabajo Básico

```powershell
# Usa el script automatizado que configura todo
.\score-compose.ps1

# Una vez completado, ejecuta con Docker Compose
docker compose up
```

> ⚠️ **IMPORTANTE**: No uses `score-compose generate` directamente. Siempre utiliza el script `score-compose.ps1` incluido en este repositorio, ya que configura automáticamente todos los provisioners necesarios y maneja dependencias complejas.

Para más detalles, consulta el [ejemplo Hello World](https://docs.score.dev/docs/get-started/) en la documentación oficial.

## Qué son los Provisioners

Los provisioners en score-compose son componentes que definen cómo se crean y gestionan los recursos externos que necesita tu aplicación. Para más información, consulta la [documentación oficial de provisioners](https://docs.score.dev/docs/score-implementation/score-compose/provisioners/).

## Instalación

### 📁 Ubicación del Repositorio

Para usar la herramienta de Visual Studio, este repositorio **DEBE** clonarse en la carpeta padre donde se encuentren tus otros repositorios que usen Score:

```
📁 Tus-Proyectos/              # Carpeta padre que contiene todos tus proyectos
├── 📁 score-provisioners/     # ✅ Este repositorio clonado aquí
├── 📁 mi-proyecto-1/          # Tu proyecto que usa Score
├── 📁 mi-proyecto-2/          # Otro proyecto que usa Score
└── 📁 mi-proyecto-3/          # Más proyectos...
```

### Comando de clonación:

```bash
# Navega a la carpeta padre de tus proyectos
cd /ruta/a/tus/proyectos

# Clona este repositorio
git clone https://github.com/tu-usuario/score-provisioners.git
```

### 🛠️ Configuración de Herramienta Externa en Visual Studio

Este repositorio incluye una herramienta externa preconfigurada para Visual Studio (`utils/Score_Compose_Tool.vssettings`) que facilita la ejecución:

#### **Método 1: Importación Automática (Recomendado)**

1. **Abre Visual Studio**
2. **Ve al menú**: `Tools` → `Import and Export Settings...`
3. **Selecciona**: `Import selected environment settings`
4. **Haz clic en**: `Next >`
5. **Opcional**: Guarda tu configuración actual si lo deseas
6. **Navega al archivo**: `score-provisioners/utils/Score_Compose_Tool.vssettings`
7. **Selecciona el archivo** y haz clic en `Next >`
8. **Asegúrate** de que `Tools > External Tools` esté marcado
9. **Haz clic en**: `Finish`

#### **Método 2: Configuración Manual**

Si prefieres configurar manualmente:

1. **Ve a**: `Tools` → `External Tools...`
2. **Haz clic en**: `Add` para crear una nueva herramienta
3. **Configura los siguientes campos**:
   - **Title**: `Score Compose`
   - **Command**: `pwsh.exe`
   - **Arguments**: `-ExecutionPolicy Bypass -NoProfile -File "$(SolutionDir)\..\score-provisioners\score-compose.ps1"`
   - **Initial directory**: `$(ProjectDir)`
   - **Marca**: `Use Output window`
   - **Marca**: `Close on exit`
   - **Marca**: `Save all documents`

#### **Verificación de la Instalación**

1. **Ve a**: `Tools` → menú principal
2. **Deberías ver**: una nueva opción llamada **"Score Compose"**
3. **Si no aparece**: reinicia Visual Studio y verifica nuevamente

#### **¿Cómo funciona la herramienta?**

La herramienta externa está configurada para:
- ✅ **Ejecutar automáticamente** el script `score-compose.ps1` 
- ✅ **Usar la ruta relativa** `$(SolutionDir)\..\score-provisioners\` (por eso es importante la ubicación del repositorio)
- ✅ **Mostrar la salida** en la ventana de Output de Visual Studio
- ✅ **Guardar todos los documentos** antes de ejecutar
- ✅ **Trabajar desde el directorio** del proyecto actual (`$(ProjectDir)`)

## Servicios Disponibles

| Type | Params | Outputs | Description |
|------|--------|---------|-------------|
| `external-environment` | `env_file` (string, default: `.env`) - Ruta al archivo de variables de entorno | Variables de entorno como `${resources.mi-env.VARIABLE_NAME}` | Carga variables de entorno desde un archivo `.env` utilizando Python |
| `certificate` | `path` (string, default: `C:/certs/aspnet.pfx`) - Ruta donde guardar el certificado<br>`password` (string, default: `password`) - Contraseña del certificado | `path` - Ruta del certificado<br>`password` - Contraseña del certificado<br>`name` - Nombre del certificado | Genera certificados de desarrollo HTTPS usando dotnet dev-certs |
| `binaries` | Ninguno | Outputs vacíos (provisioner placeholder) | Provisioner básico para construcción de binarios (en desarrollo) |
| `kirol-app` | `packageId` (string) - ID del paquete NuGet a descargar<br>`packageVersion` (string) - Versión específica del paquete<br>`downloadPath` (string) - Ruta de destino para la descarga<br>`path` (string) - Ruta alternativa a un proyecto local | `ports` - Puertos extraídos del score.yaml<br>`containers` - Información de contenedores<br>`metadata` - Metadatos del proyecto | Provisioner avanzado para gestión de aplicaciones Kirol con descarga automática de paquetes NuGet |
| `framework` | `framework` (string) - Tipo de framework (ej: "net", "java", "node")<br>`apptype` (string) - Tipo de aplicación (ej: "web", "api", "runtime")<br>`version` (string) - Versión del framework (ej: "472", "8.0") | `framework` - Tipo de framework<br>`apptype` - Tipo de aplicación<br>`version` - Versión del framework | Provisioner especializado para configuraciones de framework con lógica específica para .NET Framework 4.7.2 |
| `directory` | `source` (string, requerido) - Ruta del directorio a montar | `source` - Ruta configurada<br>`bind_mount` - Configuración de bind mount | Crea bind mounts personalizados con propagación rprivate |
| `logs-dir` | Ninguno | `source` - `C:/logs`<br>`bind_mount` - Configuración de bind mount | Bind mount preconfigurado para logging centralizado en `C:/logs` |
| `certs-dir` | Ninguno | `source` - `C:/certs`<br>`bind_mount` - Configuración de bind mount | Bind mount preconfigurado para certificados compartidos en `C:/certs` |
| `volume` (clase: `existing`) | `source` (string, requerido) - Nombre del volumen Docker existente | `volume_name` - Nombre del volumen<br>`volume_config` - Configuración external: true | Referencia volúmenes Docker existentes por nombre |
| `framework-spec` | `framework` (string) - Tipo de framework<br>`apptype` (string) - Tipo de aplicación<br>`version` (string) - Versión del framework | `framework` - Tipo de framework<br>`apptype` - Tipo de aplicación<br>`version` - Versión del framework | Provisioner de metadatos para especificaciones de framework (pass-through) |
| `smtp` | Configuración vía annotations:<br>`compose.score.dev/domain` - Dominio (default: `example.com`)<br>`compose.score.dev/publish-port` - Puerto SMTP (default: `25`)<br>`compose.score.dev/submission-port` - Puerto submission (default: `587`)<br>`compose.score.dev/username` - Usuario SMTP (default: `smtp_user`) | `host` - Hostname del servicio<br>`port` - Puerto SMTP principal<br>`submission_port` - Puerto de submission<br>`username` - Usuario de autenticación<br>`password` - Contraseña generada<br>`domain` - Dominio configurado | Provisioner completo para servidor SMTP de desarrollo usando MailPit con interfaz web en puerto 8025 |

## Uso

### ⚡ Opción 1: Herramienta de Visual Studio (Recomendado)

Si has configurado la herramienta externa de Visual Studio mediante la importación del archivo `.vssettings`:

1. **Abre tu proyecto** que contiene archivos `score.yaml` en Visual Studio
2. **Ejecuta la herramienta**:
   - Ve a `Tools` → `Score Compose`
   - O usa el atajo de teclado si lo has configurado
3. **La herramienta ejecutará automáticamente** el script `score-compose.ps1` con toda la configuración necesaria
4. **Ver resultados** en la ventana "Output" de Visual Studio (selecciona "General" en el dropdown)
5. **Ejecutar aplicación**: Una vez completado, usa `docker compose up`

> 🎯 **Ventajas de usar Visual Studio**: Ejecución con un clic, salida integrada, no necesitas abrir terminal

### ⚡ Opción 2: Script Automatizado (Línea de Comandos)

Este repositorio **REQUIERE** el uso del script `score-compose.ps1` que automatiza todo el proceso de configuración y ejecución:

```powershell
# Ejecuta el script automatizado
.\score-compose.ps1
```

**¿Qué hace el script `score-compose.ps1`?**

1. **Limpieza e Inicialización**:
   - Elimina el directorio `.score-compose` existente para empezar limpio
   - Ejecuta `score-compose init` para crear la estructura base

2. **Instalación de Dependencias**:
   - Verifica e instala el módulo `powershell-yaml` si no está disponible

3. **Descarga de Provisioners**:
   - Descarga automáticamente todos los provisioners y scripts desde este repositorio GitHub
   - Incluye todos los archivos YAML de provisioners y scripts PowerShell auxiliares

4. **Generación Inteligente**:
   - Utiliza `helper_functions.ps1` para generar comandos dinámicamente
   - Ejecuta `Get-ScoreComposeGenerateCommand` para procesar todos los archivos Score encontrados
   - Lee el archivo `state.yaml` generado
   - Ejecuta comandos adicionales almacenados en `shared_state.commands`
   - Regenera el state cuando sea necesario tras ejecutar comandos `score-compose generate`

**¿Por qué es obligatorio usar alguna de estas dos opciones?**
- ✅ Configuración automática de todos los provisioners
- ✅ Descarga siempre las versiones más recientes desde GitHub
- ✅ Manejo inteligente de múltiples archivos Score
- ✅ Ejecución secuencial de comandos dependientes
- ✅ Resolución automática de dependencias entre provisioners
- ⚠️ Los provisioners tienen dependencias complejas que requieren configuración específica
- ⚠️ El uso manual de `score-compose generate` puede fallar o generar configuraciones incorrectas

### Flujo de Trabajo Completo

#### Con Visual Studio:
1. **Preparación**: Crea tus archivos `score.yaml` en tu proyecto
2. **Ejecución**: Ve a `Tools` → `Score Compose` en Visual Studio
3. **Verificación**: Revisa la salida en la ventana "Output" 
4. **Despliegue**: Usa `docker compose up` para ejecutar tu aplicación

#### Con Línea de Comandos:
1. **Preparación**: Crea tus archivos `score.yaml` en tu proyecto
2. **Ejecución**: Ejecuta `.\score-compose.ps1`
3. **Despliegue**: Usa `docker compose up` para ejecutar tu aplicación

> 📌 **Recuerda**: En ambos casos, nunca uses comandos manuales de score-compose directamente.

### Ejemplo de uso en score.yaml:

```yaml
apiVersion: score.dev/v1b1
metadata:
  name: mi-app
spec:
  containers:
    app:
      image: mi-imagen:latest
  resources:
    smtp:
      type: smtp
      metadata:
        annotations:
          compose.score.dev/domain: midominio.com
          compose.score.dev/publish-port: "2525"
    
    certificados:
      type: certificate
      params:
        path: "C:/certs/mi-cert.pfx"
        password: "mi-password"
    
    logs:
      type: logs-dir
    
    datos:
      type: volume
      class: existing
      params:
        source: mi-volumen-existente
        
    # Ejemplo de uso del Kirol App Provisioner
    kirol-package:
      type: kirol-app
      params:
        packageId: "MiPaquete.Kirol"
        packageVersion: "1.0.0"
        downloadPath: "./packages"
    
    # Ejemplo de framework specification
    framework-config:
      type: framework-spec
      params:
        framework: ".NET"
        apptype: "web"
        version: "8.0"
```

### Comandos Post-Generación

Después de que el script `score-compose.ps1` complete la generación, puedes usar los comandos estándar de Docker Compose:

```bash
# Ver servicios generados
docker compose config

# Ejecutar en modo detached
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f

# Detener servicios
docker compose down
```

## ⚠️ Advertencias Importantes

### NO usar comandos manuales

```bash
# ❌ NO HAGAS ESTO - Fallará o generará configuraciones incorrectas
score-compose generate score.yaml

# ❌ NO HAGAS ESTO - Los provisioners no estarán configurados
score-compose init && score-compose generate

# ✅ OPCIÓN 1: Usa la herramienta de Visual Studio
Tools → Score Compose

# ✅ OPCIÓN 2: Usa el script automatizado dentro del directorio del proyecto
.\score-compose.ps1
```

**Razones por las que los comandos manuales fallan:**
- Los provisioners requieren scripts PowerShell específicos que deben descargarse desde GitHub
- Existen dependencias entre provisioners que tanto el script como la herramienta manejan automáticamente
- Se requiere configuración específica de variables de entorno y rutas
- Algunos provisioners necesitan configuración previa (como módulos PowerShell)
- La herramienta de Visual Studio y el script aseguran la descarga de las versiones más recientes

## Referencias

- [Documentación de Score](https://score.dev/docs)
- [Score Compose Documentation](https://docs.score.dev/docs/score-implementation/score-compose/)
- [Provisioners Guide](https://docs.score.dev/docs/score-implementation/score-compose/provisioners/)
- [Score Specification](https://docs.score.dev/docs/score-specification/score-spec-reference/)