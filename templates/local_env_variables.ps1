param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    [ValidateSet("Session", "User", "Machine")]
    [string]$Scope = "Session",
    [switch]$RestartVSAdvice
)

function Set-EnvVar {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Scope
    )
    if ($Scope -eq "User") {
        [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    } elseif ($Scope -eq "Machine") {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
    } else {
        # Variables de sesión - solo para la sesión actual de PowerShell
        Set-Item -Path "Env:$Name" -Value $Value
    }
}

function Get-EnvVar {
    param(
        [string]$Name,
        [string]$Scope
    )
    if ($Scope -eq "User") {
        return [Environment]::GetEnvironmentVariable($Name, "User")
    } elseif ($Scope -eq "Machine") {
        return [Environment]::GetEnvironmentVariable($Name, "Machine")
    } else {
        # Variables de sesión
        return (Get-Item -Path "Env:$Name" -ErrorAction SilentlyContinue).Value
    }
}

function Remove-EnvVar {
    param(
        [string]$Name,
        [string]$Scope
    )
    if ($Scope -eq "User") {
        [Environment]::SetEnvironmentVariable($Name, $null, "User")
    } elseif ($Scope -eq "Machine") {
        [Environment]::SetEnvironmentVariable($Name, $null, "Machine")
    } else {
        # Variables de sesión
        Remove-Item -Path "Env:$Name" -ErrorAction SilentlyContinue
    }
}

function Ensure-EnvVar {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Scope
    )
    $existingValue = Get-EnvVar -Name $Name -Scope $Scope
    if ($existingValue -ne $Value) {
        if ($null -ne $existingValue) {
            Write-Host "Eliminando variable existente: $Name"
            Remove-EnvVar -Name $Name -Scope $Scope
        }
        Write-Host "Estableciendo variable de entorno: $Name = $Value (Scope: $Scope)"
        Set-EnvVar -Name $Name -Value $Value -Scope $Scope
        
        # Para variables permanentes, también establecer en la sesión actual
        if ($Scope -ne "Session") {
            Set-Item -Path "Env:$Name" -Value $Value
        }
    } else {
        Write-Host "Variable $Name ya tiene el valor correcto, saltando..."
    }
}

try {
    Import-Module powershell-yaml -ErrorAction Stop
} catch {
    Write-Error "El módulo powershell-yaml es necesario. Instálalo con 'Install-Module powershell-yaml'"
    return
}

$composeContent = Get-Content -Path "docker-compose.yaml" -Raw -Encoding UTF8
$compose = ConvertFrom-Yaml -Yaml $composeContent

# Buscar el servicio
if ($compose.services.ContainsKey($ServiceName)) {
    $service = $compose.services[$ServiceName]
    if ($service.environment) {
        Write-Host "Configurando variables de entorno para el servicio '$ServiceName' con scope '$Scope'..."
        
        if ($service.environment -is [System.Collections.IDictionary]) {
            foreach ($key in $service.environment.Keys) {
                $value = $service.environment[$key]
                $envVarName = "$ServiceName`_$key"
                Ensure-EnvVar -Name $envVarName -Value $value -Scope $Scope
            }
        } elseif ($service.environment -is [System.Collections.IEnumerable]) {
            foreach ($item in $service.environment) {
                if ($item -match "^(.*?)=(.*)$") {
                    $key = $matches[1]
                    $value = $matches[2]
                    $envVarName = "$ServiceName`_$key"
                    Ensure-EnvVar -Name $envVarName -Value $value -Scope $Scope
                }
            }
        } else {
            Write-Warning "El formato de environment no es reconocido."
        }
        
        Write-Host "Variables de entorno configuradas exitosamente para la sesión actual." -ForegroundColor Green
        
        if ($Scope -eq "Session") {
            Write-Host "`nNOTA: Las variables están disponibles solo en esta sesión de PowerShell." -ForegroundColor Yellow
        } elseif ($RestartVSAdvice) {
            Write-Host "`nNOTA: Para variables permanentes, es recomendable reiniciar Visual Studio si está abierto." -ForegroundColor Yellow
        }
        
    } else {
        Write-Warning "El servicio '$ServiceName' no tiene variables de entorno definidas."
    }
} else {
    Write-Error "No se encontró el servicio '$ServiceName' en el archivo compose."
}