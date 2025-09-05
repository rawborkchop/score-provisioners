# Score Provisioners

Extensiones y provisioners para usar Score/Score Compose de forma simple y consistente en entornos locales.

## Guía Rápida

```powershell
# Desde la raíz del proyecto que contiene score.yaml
./score-compose.ps1

# Arranca los servicios generados
docker compose up
```

- No ejecutes `score-compose generate` manualmente: el script ya prepara dependencias, descarga provisioners y ejecuta pasos adicionales necesarios.
- Requisitos: consulta `requirements.md` para versiones mínimas y verificaciones rápidas.

## Uso diario

- Visual Studio: Tools → “Score Compose” (importa `utils/Score_Compose_Tool.vssettings`).
- Terminal: ejecuta `./score-compose.ps1` en el proyecto con `score.yaml`.

Qué hace el script:
- Inicializa `.score-compose` y descarga/actualiza provisioners.
- Llama a la generación de `compose` y ejecuta comandos posteriores (definidos por provisioners) si los hay.

## Addons

### Pyroscope (.NET)
Perfilado continuo para servicios .NET en contenedores.

Uso mínimo:
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

Más info: `addons/README.md`.

### Plantilla dcproj (VS + Docker)
Proyecto Docker Compose para depurar en Visual Studio con `entrypoint.sh` que ejecuta `/init-scripts/*.sh` (si existen) antes de iniciar.

Pasos:
1) Copia `addons/dcproj template/` a tu solución (renómbralo si quieres).
2) En `docker-compose.vs.debug.yml`, apunta el volumen `source` al `entrypoint.sh` local.
3) En `projectname.dcproj`, configura `DockerComposeBaseFilePath` al compose generado.
4) Abre el `.dcproj` en Visual Studio y usa el perfil “Docker Compose”.

Más info: `addons/README.md`.

## Casos comunes (recetas rápidas)

- Certificados de desarrollo: usa el provisioner `certificate` para generar un PFX y montarlo.
- Directorios locales compartidos: `logs-dir` y `certs-dir` ya vienen preparados (bind mounts). 
- SMTP de desarrollo: usa `smtp` (MailPit) y accede a la UI en puerto 8025.

## Guías avanzadas

- Kirol App Provisioner: `templates/kirol-app-provisioner.md`
- Framework Provisioner (.NET Framework 4.7.2 y extracción de variables): `templates/framework-spec.md`
- Helper .NET Framework (`EnvConfigLoader.cs`): `utils/EnvConfigLoader.cs`

## Referencias

- Score Compose: https://docs.score.dev/docs/score-implementation/score-compose/
- Provisioners: https://docs.score.dev/docs/score-implementation/score-compose/provisioners/
- Especificación Score: https://docs.score.dev/docs/score-specification/score-spec-reference/