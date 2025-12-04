# Framework Provisioning Flow

```mermaid
flowchart TD
    Input[stdin JSON] --> Entry[framework_spec.ps1]
    Entry --> Normalize[Normalizar parámetros]
    Normalize --> BuildCtx[Construir ProvisioningContext]
    BuildCtx --> Load[Cargar provisioners.ps1]
    Load --> Factory[FrameworkProvisionerFactory::Create]
    
    Factory --> IsChild{IsChildProject?}
    IsChild -->|No| CreateDC[Crear Docker Compose VS Project]
    IsChild -->|Yes| CheckFw
    CreateDC --> CheckFw{Framework?}
    
    CheckFw -->|netcore| CheckAppCore{applicationType?}
    CheckFw -->|netframework| CheckAppFx{applicationType?}
    
    CheckAppCore -->|internal| NCInternal[NetCoreInternalProvisioner]
    CheckAppCore -->|external| NCExternal[NetCoreExternalProvisioner]
    CheckAppFx -->|internal| NFInternal[NetFrameworkInternalProvisioner]
    CheckAppFx -->|external| NFExternal[NetFrameworkExternalProvisioner]
    
    NCInternal --> NCIDockerfile[Generar Dockerfile multi-stage]
    NCIDockerfile --> Output
    
    NCExternal --> NCEDockerfile[Generar Dockerfile runtime-only]
    NCEDockerfile --> NCEOverride[Registrar Entrypoint Compose override]
    NCEOverride --> Output
    
    NFInternal --> NFIIdle[Registrar Idle Compose overrides]
    NFIIdle --> NFILaunch[Aplicar variables a launchSettings]
    NFILaunch --> Output
    
    NFExternal --> NFEIdle[Registrar Idle Compose overrides]
    NFEIdle --> NFELauncher[Generar netfx_external_launcher.ps1]
    NFELauncher --> NFEFiles[Escribir env.json + start.bat]
    NFEFiles --> NFECmd[Añadir a shared_state.commands:<br/>netfx_external_launcher.ps1]
    NFECmd --> Output
    
    Output[Output JSON:<br/>resource_outputs + shared_state]
```

## Leyenda

**shared_state.commands:**
- Array de comandos shell que se devuelven en el JSON de salida
- **.NET Core External**: comandos de merge compose para entrypoint override
- **.NET Framework Internal**: comandos de merge compose para idle debugging (implícito)
- **.NET Framework External**: comandos de merge compose + launcher script

**Docker Compose VS Project:**
- Se crea **solo para Parent Projects** (cuando `IsChildProject == false`)
- Se ejecuta **una vez** antes de evaluar framework/applicationType
- Incluye: crear `.dcproj`, descargar plantillas, registrar en `.sln`

**Idle Compose:**
- Solo para **.NET Framework** (interno y externo)
- Genera `idle-{workload}.yaml` con SDK override
- Registra comandos `debbugeable_net_framework.ps1` para merge (implícito)

**Dockerfiles:**
- **NetCore Interno**: Multi-stage (build + runtime-exe + runtime-iis)
- **NetCore Externo**: Runtime-only (aspnet/runtime según hostingModel)
- **NetFramework**: No genera Dockerfile (usa idle compose + Visual Studio)
