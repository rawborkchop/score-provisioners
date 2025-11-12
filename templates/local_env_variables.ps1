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
            $result[$key] = [string]$environment[$key]
        }
        return $result
    }
    foreach ($entry in $environment) {
        if ($entry -match "^(.*?)=(.*)$") {
            $result[$matches[1]] = $matches[2]
        }
    }
    return $result
}

function New-LaunchSettingsJson {
    param(
        [string]$ProfileName,
        [hashtable]$EnvironmentVariables
    )
    $profileDefinition = [ordered]@{
        commandName = "Project"
        environmentVariables = $EnvironmentVariables
    }
    $content = [ordered]@{
        profiles = [ordered]@{
            $ProfileName = $profileDefinition
        }
    }
    return ConvertTo-Json -InputObject $content -Depth 5
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

$jsonContent = New-LaunchSettingsJson -ProfileName $ProfileName -EnvironmentVariables $environmentVariables

Set-LaunchSettingsDirectory -Path $launchSettingsPath

Set-Content -Path $launchSettingsPath -Value $jsonContent -Encoding UTF8

Write-Host "launchSettings.json generado en '$launchSettingsPath' con el perfil '$ProfileName'." -ForegroundColor Green