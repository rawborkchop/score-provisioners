param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    [ValidateSet("Session", "User", "Machine")]
    [string]$Scope = "User",
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
        ${env:$Name} = $Value
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
        return ${env:$Name}
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
        Remove-Item "env:$Name" -ErrorAction SilentlyContinue
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
        if ($existingValue -ne $null) {
            Write-Host "Eliminando variable existente: $Name"
            Remove-EnvVar -Name $Name -Scope $Scope
        }
        Set-EnvVar -Name $Name -Value $Value -Scope $Scope
        if ($Scope -ne "Session") {
            ${env:$Name} = $Value
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

$composeContent = Get-Content -Path "compose.yaml" -Raw -Encoding UTF8
$compose = ConvertFrom-Yaml -Yaml $composeContent

# Buscar el servicio
if ($compose.services.ContainsKey($ServiceName)) {
    $service = $compose.services[$ServiceName]
    if ($service.environment) {
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
    } else {
        Write-Warning "El servicio '$ServiceName' no tiene variables de entorno definidas."
    }
} else {
    Write-Error "No se encontró el servicio '$ServiceName' en el archivo compose."
}