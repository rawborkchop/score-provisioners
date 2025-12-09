param(
    [Parameter(Mandatory = $true)]
    [string] $Mode,
    [Parameter(Mandatory = $true)]
    [string] $ServiceName,
    [string] $ComposePath,
    [string] $ExecutablePath,
    [string] $SitePath = $PSScriptRoot,
    [int] $IisPort = 8080
)

Set-StrictMode -Version Latest

$frameworkPath = Split-Path -Path $PSScriptRoot -Parent
. "$frameworkPath\DockerComposeEnvironment.ps1"

function Set-SessionEnvironment {
    param([hashtable] $Data)
    foreach ($key in $Data.Keys) {
        [Environment]::SetEnvironmentVariable($key, [string]$Data[$key])
    }
}

function Get-ComposePath {
    param([string] $CustomPath)
    if (-not [string]::IsNullOrWhiteSpace($CustomPath)) {
        return $CustomPath
    }
    return Join-Path -Path $PSScriptRoot -ChildPath "docker-compose.yaml"
}

function Start-ExecutableMode {
    param([string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "ExecutablePath is required when Mode is exe."
    }
    & $Path
    exit $LASTEXITCODE
}

function Start-IisExpressMode {
    param(
        [string] $SitePath,
        [int] $Port
    )
    $iisExpress = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "IIS Express\iisexpress.exe"
    if (-not (Test-Path -LiteralPath $iisExpress)) {
        throw "IIS Express was not found on this machine."
    }
    & $iisExpress "/path:$SitePath" "/port:$Port"
    exit $LASTEXITCODE
}

# Load environment variables from docker-compose
$composePath = Get-ComposePath -CustomPath $ComposePath
$composeEnv = [DockerComposeEnvironment]::new($composePath)
$envData = $composeEnv.GetServiceEnvironmentVariables($ServiceName)
if ($envData -and $envData.Count -gt 0) {
    Set-SessionEnvironment -Data $envData
}

# Execute based on mode
$normalizedMode = $Mode.ToLowerInvariant()
switch ($normalizedMode) {
    "exe" {
        Start-ExecutableMode -Path $ExecutablePath
    }
    "iis" {
        Start-IisExpressMode -SitePath $SitePath -Port $IisPort
    }
    default {
        throw "Unsupported Mode '$Mode'. Use 'exe' or 'iis'."
    }
}
