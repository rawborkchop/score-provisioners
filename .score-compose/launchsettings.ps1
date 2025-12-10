# =============================================================================
# LaunchSettings Generator Script
# =============================================================================
# This script is called in deferred mode after docker-compose.yaml is generated.
# It reads environment variables from docker-compose and applies them to
# the project's launchSettings.json file.
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,
    [Parameter(Mandatory = $true)]
    [string]$ProjectDirectory,
    [string]$ProfileName,
    [string]$ComposePath
)

Set-StrictMode -Version Latest

try {
    Import-Module powershell-yaml -ErrorAction Stop
} catch {
    throw "powershell-yaml module is required. Install with 'Install-Module powershell-yaml'."
}

# Load framework classes
$frameworkPath = Join-Path -Path $PSScriptRoot -ChildPath "framework"
. "$frameworkPath\LaunchSettings.psm1"

# Set default values
if (-not $ProfileName) {
    $ProfileName = $ServiceName
}

if (-not $ComposePath) {
    $ComposePath = Join-Path -Path (Get-Location) -ChildPath "docker-compose.yaml"
}

# Create LaunchSettings instance and apply environment variables
$launchSettings = [LaunchSettings]::new($ComposePath)
$launchSettings.ApplyEnvironmentToLaunchProfile($ServiceName, $ProjectDirectory, $ProfileName)

Write-Host "launchSettings.json generated for service '$ServiceName' with profile '$ProfileName'." -ForegroundColor Green
