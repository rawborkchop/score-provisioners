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

```bash
# Inicializa el proyecto score-compose
score-compose init

# Genera compose.yaml desde score.yaml  
score-compose generate score.yaml

# Ejecuta con Docker Compose
docker compose up
```

Para más detalles, consulta el [ejemplo Hello World](https://docs.score.dev/docs/get-started/) en la documentación oficial.

## Qué son los Provisioners

Los provisioners en score-compose son componentes que definen cómo se crean y gestionan los recursos externos que necesita tu aplicación. Para más información, consulta la [documentación oficial de provisioners](https://docs.score.dev/docs/score-implementation/score-compose/provisioners/).

## Servicios Disponibles

### 1. Script Provisioners (`01-script.provisioners.yaml`)

#### External Environment
- **Tipo**: `external-environment`
- **URI**: `cmd://python`
- **Descripción**: Carga variables de entorno desde un archivo `.env` utilizando Python
- **Parámetros**:
  - `env_file`: Ruta al archivo de variables de entorno (por defecto: `.env`)
- **Uso**: Útil para cargar configuraciones de desarrollo local desde archivos de entorno

#### Certificate Provisioner
- **Tipo**: `certificate`
- **URI**: `cmd://powershell`
- **Script**: `certificate.ps1`
- **Descripción**: Genera certificados de desarrollo HTTPS usando dotnet dev-certs
- **Parámetros**:
  - `path`: Ruta donde guardar el certificado (por defecto: `C:/certs/aspnet.pfx`)
  - `password`: Contraseña del certificado (por defecto: `password`)

#### Binaries Provisioner
- **Tipo**: `binaries`
- **URI**: `cmd://powershell`
- **Script**: `docker_file_generation.ps1`
- **Descripción**: Genera Dockerfiles y maneja la construcción de binarios

#### Kirol App Provisioner
- **Tipo**: `kirol-app`
- **URI**: `cmd://pwsh`
- **Script**: `kirol_app.ps1`
- **Descripción**: Gestiona aplicaciones Kirol, incluyendo descarga y configuración de paquetes NuGet

**Lógica del Kirol App Provisioner:**

El provisioner `kirol-app` implementa un flujo complejo para la gestión de aplicaciones Kirol:

1. **Búsqueda de Configuración**: Localiza el archivo `nuget.config` desde el directorio raíz del proyecto
2. **Descarga de Paquetes**: Utiliza la función `Get-NugetPackage` para descargar paquetes específicos desde fuentes configuradas
3. **Extracción y Configuración**: Procesa los paquetes descargados y configura la aplicación según los parámetros especificados
4. **Integración con Score**: Devuelve metadatos que pueden ser utilizados por otros provisioners y en la generación final del compose

**Funciones principales:**
- `Get-NugetPackage`: Descarga paquetes NuGet desde fuentes configuradas
- `Find-ProjectRoot`: Localiza el directorio raíz del proyecto para ubicar configuraciones
- Gestión automática de dependencias y configuraciones de aplicaciones Kirol

**Parámetros soportados:**
- `packageId`: ID del paquete NuGet a descargar
- `packageVersion`: Versión específica del paquete
- `downloadPath`: Ruta de destino para la descarga

#### Framework Provisioner
- **Tipo**: `framework`
- **URI**: `cmd://pwsh`
- **Script**: `framework_spec.ps1`
- **Descripción**: Especifica configuraciones de framework para la aplicación

### 2. Volume Provisioners (`02-custom.volumes.provisioners.yaml`)

#### Custom Bind Mount
- **Tipo**: `directory`
- **URI**: `template://custom-bind-mount`
- **Descripción**: Crea bind mounts personalizados con propagación rprivate
- **Parámetros**:
  - `source`: Ruta del directorio a montar

#### Logs Directory
- **Tipo**: `logs-dir`
- **URI**: `template://custom-bind-mount`
- **Descripción**: Monta automáticamente el directorio `C:/logs` para logging

#### Certificates Directory
- **Tipo**: `certs-dir`
- **URI**: `template://custom-bind-mount`
- **Descripción**: Monta automáticamente el directorio `C:/certs` para certificados

#### Existing Volume
- **Tipo**: `volume`
- **Clase**: `existing`
- **URI**: `template://existing-volume`
- **Descripción**: Permite usar volúmenes Docker existentes por nombre
- **Parámetros**:
  - `source`: Nombre del volumen Docker existente

### 3. Specification Provisioner (`03-specification.provisioners.yaml`)

#### Framework Specification
- **Tipo**: `framework-spec`
- **URI**: `template://specification`
- **Descripción**: Define especificaciones de framework para la aplicación
- **Parámetros**:
  - `framework`: Tipo de framework (ej: .NET, Java)
  - `apptype`: Tipo de aplicación (ej: web, api)
  - `version`: Versión del framework

### 4. Container Provisioners (`04-container.provisioners.yaml`)

#### SMTP Service
- **Tipo**: `smtp`
- **URI**: `template://smtp`
- **Descripción**: Provisiona un servidor SMTP de desarrollo usando MailPit
- **Características**:
  - Imagen: `axllent/mailpit:latest`
  - Puerto SMTP: 25 (configurable)
  - Puerto Submission: 587 (configurable)
  - Web UI: Puerto 8025
  - Autenticación configurada automáticamente
  - Volúmenes persistentes para datos y configuración

- **Anotaciones Score soportadas**:
  - `compose.score.dev/domain`: Dominio para el servicio (por defecto: `example.com`)
  - `compose.score.dev/publish-port`: Puerto SMTP público (por defecto: `25`)
  - `compose.score.dev/submission-port`: Puerto de submission (por defecto: `587`)
  - `compose.score.dev/username`: Usuario SMTP (por defecto: `smtp_user`)

## Uso

### Opción 1: Script Automatizado (Recomendado)

Este repositorio incluye el script `score-compose.ps1` que automatiza todo el proceso de configuración y ejecución:

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
   - Utiliza `helper_functions.ps1` para generar comandos score-compose dinámicamente
   - Ejecuta `Get-ScoreComposeGenerateCommand` para procesar todos los archivos Score encontrados

5. **Ejecución de Comandos Adicionales**:
   - Lee el archivo `state.yaml` generado
   - Ejecuta comandos adicionales almacenados en `shared_state.commands`
   - Regenera el state cuando sea necesario tras ejecutar comandos `score-compose generate`

**Ventajas del script automatizado:**
- ✅ Configuración automática de todos los provisioners
- ✅ Descarga siempre las versiones más recientes desde GitHub
- ✅ Manejo inteligente de múltiples archivos Score
- ✅ Ejecución secuencial de comandos dependientes
- ✅ No requiere configuración manual

### Opción 2: Instalación Manual

1. **Instalación**: Copia los archivos de template al directorio `.score-compose/` de tu proyecto
2. **Configuración**: Los provisioners se cargan automáticamente cuando score-compose ejecuta
3. **Referencia en Score**: Usa los tipos definidos en tus archivos `score.yaml`

### Flujo de Trabajo Completo

1. **Preparación**: Crea tus archivos `score.yaml` en tu proyecto
2. **Ejecución**: Ejecuta `.\score-compose.ps1` para configurar y generar automáticamente
3. **Despliegue**: Usa `docker compose up` para ejecutar tu aplicación

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

## Referencias

- [Documentación de Score](https://score.dev/docs)
- [Score Compose Documentation](https://docs.score.dev/docs/score-implementation/score-compose/)
- [Provisioners Guide](https://docs.score.dev/docs/score-implementation/score-compose/provisioners/)
- [Score Specification](https://docs.score.dev/docs/score-specification/score-spec-reference/)
