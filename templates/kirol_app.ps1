. .score-compose/helper_functions.ps1

function Get-NugetPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$packageId,
        
        [Parameter(Mandatory=$true)]
        [string]$packageVersion,

        [Parameter(Mandatory=$true)]
        [string]$downloadPath
    )

    $projectRoot = Find-ProjectRoot -startPath $PWD.Path
    $nugetConfigPath = Join-Path -Path $projectRoot -ChildPath "nuget.config"

    if (-not $nugetConfigPath) {
        return $false
    }

    if (-not (Test-Path $downloadPath)) {
        New-Item -ItemType Directory -Path $downloadPath | Out-Null
    }

    & nuget install $packageId `
        -Version $packageVersion `
        -ConfigFile $nugetConfigPath `
        -OutputDirectory $downloadPath `
        -NonInteractive

    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return $false
    }
}

$inputJson = [Console]::In.ReadToEnd()
$inputJson | Out-File -FilePath "input_data.json" -Encoding UTF8

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = $data.resource_params

$projectRoot = Find-ProjectRoot -startPath $PWD.Path

$projectPath = if ($params.path) { $params.path }
$name = if ($params.name) { $params.name }
$version = if ($params.version) { $params.version }

if($projectPath) 
{
    $dirPath = Join-Path -Path $projectRoot -ChildPath $projectPath
} 
elseif($name -and $version) 
{
    $downloadPath = Join-Path -Path $projectRoot -ChildPath "packages"
    Get-NugetPackage -packageId $name -packageVersion $version -downloadPath $downloadPath
    $dirPath = $downloadPath
} 
else 
{
    Exit 1
}

$scoreContent = Get-ScoreContent -dirPath $dirPath

$shared = Initialize-SharedState -data $data
$command = Get-ScoreComposeGenerateCommand -dirPath $dirPath

if (-not $shared.commands.Contains($command))
{
    $shared.commands += $command
}

$ports = @{}
$portIndex = 0
foreach ($key in $scoreContent.service.ports.Keys) 
{
    $ports["$portIndex"] = $scoreContent.service.ports[$key].port
    $portIndex++
}

$output = @{
    resource_outputs = @{
        ports = $ports
        connectionStrings = $connectionStrings
        name = $scoreContent.metadata.name
    }
    shared_state = $shared
    #se puede mejorar con el wait-for-resources pero hay que ver como hacer el tweak para evitar servicio repetido (wait for workload?)
}
$outputJson = $output | ConvertTo-Json -Depth 10
[Console]::Out.Write($outputJson)

# score-compose generate `
# score.yaml `
# D:\GIT\lsports\src\KSoft.IntegrationServices.LSports.UCBets.gRPC.Server\score.yaml `
# --image mcr.microsoft.com/dotnet/aspnet:8.0
# --build "webservice={'context':'.', 'dockerfile':'Dockerfile'}" `
# --output D:\GIT\lsports\src\KSoft.IntegrationServices.LSports.UCBets.gRPC.Server\compose.yaml

# pwsh -Command "[Console]::Out.Write((Get-Content input_data.json -Raw))" | pwsh -File .score-compose\kirol_app.ps1