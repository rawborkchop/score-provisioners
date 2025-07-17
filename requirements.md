# Score Provisioners - Requisitos del Sistema

## Requisitos Obligatorios

### 1. PowerShell Core
- **Versión mínima**: 7.0+
- **Recomendada**: 7.4+
- **Plataformas**: Windows, Linux, macOS
- **Instalación Windows**: 
  - Descarga desde: https://github.com/PowerShell/PowerShell/releases
  - O vía winget: `winget install Microsoft.PowerShell`
- **Instalación Linux/macOS**: 
  - Consulta: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell

### 2. Score-Compose CLI
- **Versión mínima**: 0.15.0+
- **Recomendada**: 0.16.0+
- **Instalación**:
  - Descarga desde: https://github.com/score-spec/score-compose/releases
  - O vía brew: `brew install score-spec/tap/score-compose`
  - O vía winget: `winget install score-spec.score-compose`
- **Verificación**: `score-compose --version`

### 3. Docker Engine
- **Versión mínima**: 20.10+
- **Recomendada**: 24.0+
- **Instalación**: https://docs.docker.com/get-docker/
- **Verificación**: `docker --version`

### 4. Docker Compose
- **Versión mínima**: 2.0+
- **Recomendada**: 2.20+
- **Nota**: Incluido con Docker Desktop
- **Verificación**: `docker compose version`

## Módulos PowerShell (Se instalan automáticamente)

### powershell-yaml
- **Versión**: Latest
- **Propósito**: Procesamiento de archivos YAML en PowerShell
- **Instalación automática**: El script `score-compose.ps1` lo instala automáticamente
- **Instalación manual**: `Install-Module -Name powershell-yaml -Force -Scope CurrentUser`

- **587**: SMTP submission (configurable)


### Permisos requeridos
- **Windows**: Ejecución de scripts PowerShell habilitada
  - `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Linux/macOS**: Usuario en grupo docker
  - `sudo usermod -aG docker $USER`

## Verificación de Requisitos

### Script de verificación PowerShell:
```powershell
# Verificar PowerShell
$PSVersionTable.PSVersion

# Verificar score-compose
score-compose --version

# Verificar Docker
docker --version
docker compose version

# Verificar conectividad
Test-NetConnection github.com -Port 443

# Verificar módulo YAML
Get-Module -ListAvailable powershell-yaml
```

## Troubleshooting Común

### Error: "score-compose: command not found"
- **Solución**: Añadir score-compose al PATH del sistema
- **Windows**: Añadir directorio de instalación a PATH
- **Linux/macOS**: Mover binario a `/usr/local/bin/`

### Error: "Cannot run scripts on this system"
- **Solución**: Habilitar ejecución de scripts en PowerShell
- **Comando**: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Error: "Docker daemon not running"
- **Solución**: Iniciar Docker Desktop o servicio Docker
- **Windows**: Iniciar Docker Desktop
- **Linux**: `sudo systemctl start docker`

### Error: "Module powershell-yaml not found"
- **Solución**: Instalación manual del módulo
- **Comando**: `Install-Module -Name powershell-yaml -Force -Scope CurrentUser`

## Actualizaciones

### Para mantener el sistema actualizado:
```powershell
# Actualizar score-compose (si se instaló vía package manager)
winget upgrade score-spec.score-compose  # Windows
brew upgrade score-compose               # macOS/Linux

# Actualizar módulos PowerShell
Update-Module powershell-yaml

# Actualizar Docker (seguir documentación oficial)
```

## Notas de Compatibilidad

- **Windows PowerShell 5.1**: No soportado, se requiere PowerShell Core 7+
- **Docker Toolbox**: No recomendado, usar Docker Desktop
- **WSL1**: Funcional pero se recomienda WSL2 para mejor rendimiento
- **ARM64**: Soportado en PowerShell 7+ y Docker Desktop
