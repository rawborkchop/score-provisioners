# Invoked by NetFrameworkInternalProvisioner to map docker-compose environment
# variables into launchSettings.json profiles before debugging in Visual Studio.

param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,
    [string]$ProfileName
)

Set-StrictMode -Version Latest

function Get-DockerComposeObject {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "docker-compose.yaml no encontrado en '$Path'."
    }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    return ConvertFrom-Yaml -Yaml $raw
}

function Get-ServiceEnvironmentVariables {
    param(
        [hashtable]$Service,
        [string]$ServiceName
    )
    $result = [ordered]@{}
    $environment = $Service.environment
    if (-not $environment) {
        return $result
    }
    if ($environment -is [System.Collections.IDictionary]) {
        foreach ($key in $environment.Keys) {
            $value = [string]$environment[$key]
            $result[$key] = Normalize-EnvironmentValue -Value $value
        }
        return $result
    }
    foreach ($entry in $environment) {
        if ($entry -match "^(.*?)=(.*)$") {
            $result[$matches[1]] = Normalize-EnvironmentValue -Value $matches[2]
        }
    }
    return $result
}

function Normalize-EnvironmentValue {
    param([string]$Value)
    if ($null -eq $Value) {
        return $Value
    }
    # Ensures backslashes are not over-escaped in the resulting JSON.
    return $Value -replace '\\\\', '\'
}

function Get-LaunchSettingsObject {
    param([string]$Path)
    $result = [ordered]@{}
    if (Test-Path -LiteralPath $Path) {
        $raw = Get-Content -Path $Path -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try {
                $result = ConvertFrom-Json -InputObject $raw -AsHashtable -Depth 20
            } catch {
                $result = [ordered]@{}
            }
        }
    }
    if (-not $result) {
        $result = [ordered]@{}
    }
    if (-not $result.ContainsKey("profiles") -or -not ($result["profiles"] -is [System.Collections.IDictionary])) {
        $result["profiles"] = [ordered]@{}
    }
    return $result
}

function Set-EnvironmentProfile {
    param(
        [hashtable]$LaunchSettings,
        [string]$ProfileName,
        [hashtable]$EnvironmentVariables,
        [string]$DefaultProfileName
    )

    $profiles = $LaunchSettings["profiles"]
    if (-not $profiles.ContainsKey($ProfileName) -or -not ($profiles[$ProfileName] -is [System.Collections.IDictionary])) {
        $profiles[$ProfileName] = [ordered]@{}
    }

    $profiles[$ProfileName]["commandName"] = "Project"
    $profiles[$ProfileName]["environmentVariables"] = $EnvironmentVariables

    if ([string]::IsNullOrWhiteSpace($DefaultProfileName)) {
        return
    }

    if (-not $profiles.ContainsKey($DefaultProfileName) -or -not ($profiles[$DefaultProfileName] -is [System.Collections.IDictionary])) {
        $profiles[$DefaultProfileName] = [ordered]@{}
    }

    if (-not $profiles[$DefaultProfileName].ContainsKey("commandName") -or [string]::IsNullOrWhiteSpace([string]$profiles[$DefaultProfileName]["commandName"])) {
        $profiles[$DefaultProfileName]["commandName"] = "Project"
    }

    if ($profiles[$DefaultProfileName].ContainsKey("environmentVariables")) {
        $profiles[$DefaultProfileName].Remove("environmentVariables")
    }
}

function Set-LaunchSettingsDirectory {
    param([string]$Path)
    $directory = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($directory)) {
        return
    }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

try {
    Import-Module powershell-yaml -ErrorAction Stop
} catch {
    throw "El módulo powershell-yaml es necesario. Instálalo con 'Install-Module powershell-yaml'."
}

if (-not $ProfileName) {
    $ProfileName = $ServiceName
}

$launchSettingsPath = Join-Path -Path (Get-Location) -ChildPath "Properties/launchSettings.json"

$compose = Get-DockerComposeObject -Path "docker-compose.yaml"

if (-not $compose.services.ContainsKey($ServiceName)) {
    throw "No se encontró el servicio '$ServiceName' en docker-compose.yaml."
}

$environmentVariables = Get-ServiceEnvironmentVariables -Service $compose.services[$ServiceName] -ServiceName $ServiceName

if ($environmentVariables.Count -eq 0) {
    Write-Warning "El servicio '$ServiceName' no tiene variables de entorno definidas."
}

$launchSettings = Get-LaunchSettingsObject -Path $launchSettingsPath
$defaultProfileName = "Default"
if ($defaultProfileName -eq $ProfileName) {
    $defaultProfileName = "$ProfileName-default"
}
Set-EnvironmentProfile -LaunchSettings $launchSettings -ProfileName $ProfileName -EnvironmentVariables $environmentVariables -DefaultProfileName $defaultProfileName

Set-LaunchSettingsDirectory -Path $launchSettingsPath

$jsonContent = ConvertTo-Json -InputObject $launchSettings -Depth 20
Set-Content -Path $launchSettingsPath -Value $jsonContent -Encoding UTF8

Write-Host "launchSettings.json generado en '$launchSettingsPath' con el perfil '$ProfileName'." -ForegroundColor Green