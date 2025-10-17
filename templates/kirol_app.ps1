. .score-compose/helper_functions.ps1

$inputJson = [Console]::In.ReadToEnd()
#$inputJson | Out-File -FilePath "input_data.json" -Encoding UTF8

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = $data.resource_params

$projectRoot = Find-ProjectRoot -startPath $PWD.Path

$projectPath = if ($params.path) { $params.path }
$name = if ($params.name) { $params.name }
$version = if ($params.version) { $params.version }

if($projectPath -and -not $name -and -not $version)
{
    $dirPath = Join-Path -Path $projectRoot -ChildPath $projectPath
}
elseif($name -and $version -and $projectPath)
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

$projectName = $scoreContent.metadata.name
if (-not $shared.childrenPaths.ContainsKey($projectName)) {
    $shared.childrenPaths[$projectName] = $dirPath
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
        name = $projectName
    }
    shared_state = $shared
    #se puede mejorar con el wait-for-resources pero hay que ver como hacer el tweak para evitar servicio repetido (wait for workload?)
}
$outputJson = $output | ConvertTo-Json -Depth 10
[Console]::Out.Write($outputJson)

# pwsh -Command "[Console]::Out.Write((Get-Content input_data.json -Raw))" | pwsh -File kirol_app.ps1
