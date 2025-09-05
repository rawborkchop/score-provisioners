# Addons

Guía rápida y práctica para los addons incluidos en esta carpeta.

## 1) Pyroscope para .NET (`score-pyroscope.yaml`)

Activa el profiling continuo para servicios .NET dentro de contenedores.

### Qué hace
- Añade un script de init para descargar las bibliotecas de Pyroscope.
- Define variables de entorno necesarias para el profiler .NET.
- Usa `${resources.pyroscope.webUrl}` para apuntar al servidor Pyroscope.

### Uso mínimo

```yaml
apiVersion: score.dev/v1b1
metadata:
  name: mi-servicio
containers:
  webservice:
    files:
      /init-scripts/pyroscope-init.sh:
        content: |
          #!/bin/sh
          cd /
          curl -s -L https://github.com/grafana/pyroscope-dotnet/releases/download/v0.12.0-pyroscope/pyroscope.0.12.0-glibc-x86_64.tar.gz | tar xvz -C .
          chmod +x ./Pyroscope.Profiler.Native.so ./Pyroscope.Linux.ApiWrapper.x64.so
    variables:
      PYROSCOPE_APPLICATION_NAME: ${metadata.name}
      PYROSCOPE_SERVER_ADDRESS: ${resources.pyroscope.webUrl}
      PYROSCOPE_PROFILING_ENABLED: "1"
      CORECLR_ENABLE_PROFILING: "1"
      CORECLR_PROFILER: "{BD1A650D-AC5D-4896-B64F-D6FA25D6B26A}"
      CORECLR_PROFILER_PATH: "/Pyroscope.Profiler.Native.so"
      LD_PRELOAD: "/Pyroscope.Linux.ApiWrapper.x64.so"
      DOTNET_EnableDiagnostics: "1"
      DOTNET_EnableDiagnostics_IPC: "0"
      DOTNET_EnableDiagnostics_Debugger: "0"
      DOTNET_EnableDiagnostics_Profiler: "1"
resources:
  pyroscope:
    type: pyroscope
```

### Requisitos
- Un servidor Pyroscope accesible (local/remoto).
- Conectividad de red desde los contenedores al servidor.

## 2) Plantilla dcproj para VS + Docker (`dcproj template/`)

Facilita el debugging con Visual Studio usando Docker Compose y un `entrypoint.sh` extensible.

### Contenido
- `.dockerignore`
- `docker-compose.vs.debug.yml`
- `entrypoint.sh`
- `launchSetiings.json`
- `projectname.dcproj`

### Flujo de uso
1. Copia la carpeta en tu solución y renómbrala según tu host.
2. Ajusta `docker-compose.vs.debug.yml` → `volumes.source` con la ruta absoluta a `entrypoint.sh`.
3. Ajusta `projectname.dcproj` → `DockerComposeBaseFilePath` y referencias al `docker-compose` generado.
4. Abre el `.dcproj` en Visual Studio y usa el perfil “Docker Compose”.

### Detalle útil
- `entrypoint.sh` ejecuta cualquier script ejecutable dentro de `/init-scripts/*.sh` antes de lanzar la app.


