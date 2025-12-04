param(
    [Parameter(Mandatory = $true)]
    [string] $Mode,
    [string] $ExecutablePath,
    [string] $SitePath = $PSScriptRoot,
    [int] $IisPort = 8080
)

Set-StrictMode -Version Latest

function Set-SessionEnvironment {
    param([hashtable] $Data)
    foreach ($key in $Data.Keys) {
        [Environment]::SetEnvironmentVariable($key, [string]$Data[$key])
    }
}

$envFile = Join-Path -Path $PSScriptRoot -ChildPath "env.json"
if (Test-Path -LiteralPath $envFile) {
    $envData = Get-Content -Path $envFile -Raw | ConvertFrom-Json -AsHashtable -Depth 10
    if ($envData) { Set-SessionEnvironment -Data $envData }
}

if ("exe" -eq $Mode.ToLowerInvariant()) {
    if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
        throw "ExecutablePath is required when Mode is exe."
    }
    & $ExecutablePath
    exit $LASTEXITCODE
}

if ("iis" -eq $Mode.ToLowerInvariant()) {
    $iisExpress = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "IIS Express\iisexpress.exe"
    if (-not (Test-Path -LiteralPath $iisExpress)) {
        throw "IIS Express was not found on this machine."
    }
    & $iisExpress "/path:$SitePath" "/port:$IisPort"
    exit $LASTEXITCODE
}

throw "Unsupported Mode '$Mode'. Use 'exe' or 'iis'."

