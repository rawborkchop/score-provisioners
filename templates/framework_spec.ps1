. .score-compose/helper_functions.ps1

function ManageNetFramework
{
    param(
        [hashtable]$data
    )

    $containers = Get-Containers -data $data

    $shared = Initialize-SharedState -data $data
    $workloadName = $data.source_workload

    if (-not $workloadName) {
        return $shared
    }

    foreach ($container in $containers) 
    {
        $filePath = ".score-compose/idle-$workloadName.yaml"
        $override_file = @"
services:
    $($workloadName + "-" + $container):
        build: !reset null
        image: mcr.microsoft.com/dotnet/sdk:8.0
"@
        $override_file | Out-File $filePath -Encoding utf8
        $shared.commands += ".score-compose\local_env_variables.ps1 -ServiceName $($workloadName + "-" + $container)"
        $shared.commands += "docker compose -f docker-compose.yaml -f $filePath config > merged.yaml"
        $shared.commands += "Remove-Item $filePath -Force"
        $shared.commands += "Move-Item merged.yaml docker-compose.yaml -Force"
    }

    return $shared
}

function Set-NetCoreDockerfile
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$targetDirectory
    )

    if (-not $targetDirectory) {
        return
    }

    if (-not (Test-Path -Path $targetDirectory)) {
        return
    }

    $dockerfilePath = Join-Path -Path $targetDirectory -ChildPath "Dockerfile"
    $dockerfileContent = @"
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS base
WORKDIR /app
RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        libssl-dev \
        iputils-ping \
        curl \
    && update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*
"@
    Set-Content -Path $dockerfilePath -Value $dockerfileContent -Encoding UTF8
}

function Set-NormalizedLineEndings
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [ValidateSet("LF", "CRLF")]
        [string]$LineEnding = "CRLF"
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $normalized = $content -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"

    if ($LineEnding -eq "CRLF") {
        $normalized = $normalized -replace "`n", "`r`n"
        if ($normalized.Length -gt 0 -and -not $normalized.EndsWith("`r`n")) {
            $normalized += "`r`n"
        }
    }
    else {
        if ($normalized.Length -gt 0 -and -not $normalized.EndsWith("`n")) {
            $normalized += "`n"
        }
    }

    [System.IO.File]::WriteAllText($Path, $normalized, [System.Text.Encoding]::UTF8)
}

function Ensure-DockerComposeProject
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$solutionRoot,
        [Parameter(Mandatory=$true)]
        [string]$dcprojName,
        [Parameter(Mandatory=$true)]
        [string]$refProjPath,
        [string]$composeProjectName,
        [string]$serviceName,
        [string[]]$serviceContainers
    )

    $projectFileName = "$dcprojName.dcproj"
    $projectRelDir = Join-Path -Path "docker" -ChildPath $dcprojName
    $targetDir = Join-Path -Path $solutionRoot -ChildPath $projectRelDir
    $baseUrl = "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/dcproj%20template"
    $dockerComposePath = Join-Path -Path $refProjPath -ChildPath "docker-compose"

    if (-not $serviceName) {
        $serviceName = $dcprojName
    }

    $serviceName = $serviceName + "-" + $serviceContainers[0]
    if (-not $composeProjectName) {
        $composeProjectName = $dcprojName
    }

    $projGuid = ([guid]::NewGuid()).ToString()
    if (Test-Path $targetDir) {
        $c = Get-Content -Path "$targetDir\$projectFileName" -Raw
        if ($c -match '<ProjectGuid>(.*?)</ProjectGuid>') {
            $projGuid = $matches[1]
        }
        Remove-Item -Path $targetDir -Recurse -Force
        $isNewProject = $false
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    Invoke-WebRequest -Uri "$baseUrl/projectname.dcproj" -UseBasicParsing -OutFile "$targetDir\$projectFileName"
    Invoke-WebRequest -Uri "$baseUrl/launchSettings.json" -UseBasicParsing -OutFile "$targetDir\launchSettings.json"
    Invoke-WebRequest -Uri "$baseUrl/docker-compose.vs.debug.yml" -UseBasicParsing -OutFile "$targetDir\docker-compose.vs.debug.yml"
    Invoke-WebRequest -Uri "$baseUrl/entrypoint.sh" -UseBasicParsing -OutFile "$targetDir\entrypoint.sh"
    Invoke-WebRequest -Uri "$baseUrl/.dockerignore" -UseBasicParsing -OutFile "$targetDir\.dockerignore"

    Set-NormalizedLineEndings -Path "$targetDir\.dockerignore" -LineEnding "CRLF"

    $c = Get-Content -Path "$targetDir\$projectFileName" -Raw
    $c = $c.Replace('__PATH_TO_GENERATED_DOCKER_COMPOSE__', $dockerComposePath.Replace('\', '/'))
    $c = $c.Replace('docker-compose.vs.debug.yaml', 'docker-compose.vs.debug.yml')
    $c = [regex]::Replace($c, '<ProjectGuid>\s*__PROJECT_GUID__\?\s*</ProjectGuid>', "<ProjectGuid>$projGuid</ProjectGuid>")
    Set-Content -Path "$targetDir\$projectFileName" -Value $c -Encoding UTF8
    Set-NormalizedLineEndings -Path "$targetDir\$projectFileName" -LineEnding "CRLF"

    $c = Get-Content -Path "$targetDir\launchSettings.json" -Raw
    $c = $c.Replace('__PATH_TO_GENERATED_DOCKER_COMPOSE__', $dockerComposePath.Replace('\', '/'))
    $c = $c.Replace('__SERVICE_NAME__', $serviceName)
    Set-Content -Path "$targetDir\launchSettings.json" -Value $c -Encoding UTF8
    Set-NormalizedLineEndings -Path "$targetDir\launchSettings.json" -LineEnding "CRLF"

    $c = Get-Content -Path "$targetDir\docker-compose.vs.debug.yml" -Raw
    $c = $c.Replace('__ABSOLUTE_PATH_TO_ENTRYPOINT_SH__', $targetDir)
    $c = $c.Replace('__COMPOSE_PROJECT_NAME__', $composeProjectName)
    $c = $c.Replace('__SERVICE_NAME__', $serviceName)
    Set-Content -Path "$targetDir\docker-compose.vs.debug.yml" -Value $c -Encoding UTF8
    Set-NormalizedLineEndings -Path "$targetDir\docker-compose.vs.debug.yml" -LineEnding "CRLF"

    if ($isNewProject -eq $false) {
        return
    }

    $slnFile = Get-ChildItem -Path $solutionRoot -Filter "*.sln" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $projectTypeGuid = "{E53339B2-1760-4266-BCC7-CA923CBCF16C}"
    $projGuidBraced = "{" + ($projGuid.ToUpper()) + "}"
    $projectRelPath = Join-Path -Path $projectRelDir -ChildPath $projectFileName
    $slnLines = Get-Content -Path $slnFile.FullName -Encoding UTF8

    $insertIndex = 0
    for ($i = 0; $i -lt $slnLines.Count; $i++) { if ($slnLines[$i] -eq 'Global') { $insertIndex = $i; break } }
    $projectBlock = @(
        "Project(`"$projectTypeGuid`") = `"$dcprojName`", `"$projectRelPath`", `"$projGuidBraced`"",
        "EndProject"
    )
    if ($insertIndex -gt 0) {
        $slnLines = $slnLines[0..($insertIndex-1)] + $projectBlock + $slnLines[$insertIndex..($slnLines.Count-1)]
    } else {
        $slnLines = $projectBlock + $slnLines
    }

    $pcpStart = -1; $pcpEnd = -1
    for ($i = 0; $i -lt $slnLines.Count; $i++) {
        if ($pcpStart -eq -1 -and ($slnLines[$i] -match '^\s*GlobalSection\(ProjectConfigurationPlatforms\)')) { $pcpStart = $i; continue }
        if ($pcpStart -ne -1 -and ($slnLines[$i] -match '^\s*EndGlobalSection')) { $pcpEnd = $i; break }
    }
    $cfgLines = @(
        "`t`t$projGuidBraced.Debug|Any CPU.ActiveCfg = Debug|Any CPU",
        "`t`t$projGuidBraced.Debug|Any CPU.Build.0 = Debug|Any CPU",
        "`t`t$projGuidBraced.NoVariablesDefault|Any CPU.ActiveCfg = NoVariablesDefault",
        "`t`t$projGuidBraced.NoVariablesDefault|Any CPU.Build.0 = NoVariablesDefault",
        "`t`t$projGuidBraced.Release|Any CPU.ActiveCfg = Release|Any CPU",
        "`t`t$projGuidBraced.Release|Any CPU.Build.0 = Release|Any CPU"
    )
    if ($pcpStart -ne -1 -and $pcpEnd -ne -1) {
        $before = $slnLines[0..($pcpEnd-1)]
        $after = $slnLines[$pcpEnd..($slnLines.Count-1)]
        $slnLines = $before + $cfgLines + $after
    } else {
        $globalEndIdx = -1
        for ($i = $slnLines.Count - 1; $i -ge 0; $i--) { if ($slnLines[$i] -eq 'EndGlobal') { $globalEndIdx = $i; break } }
            $newSection = @("`tGlobalSection(ProjectConfigurationPlatforms) = postSolution") + $cfgLines + @("`tEndGlobalSection")
        if ($globalEndIdx -gt 0) {
            $slnLines = $slnLines[0..($globalEndIdx-1)] + $newSection + $slnLines[$globalEndIdx..($slnLines.Count-1)]
        } else {
            $slnLines = $slnLines + @('Global') + $newSection + @('EndGlobal')
        }
    }
    Set-Content -Path $slnFile.FullName -Value ($slnLines -join "`r`n") -Encoding UTF8
}

$inputJson = [Console]::In.ReadToEnd()

#$inputJson | Out-File -FilePath "input_data.json" -Encoding UTF8

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = $data.resource_params

$framework = if ($params.framework) { $params.framework }
$version = if ($params.version) { $params.version }
$composeProjectName = if ($data.compose_project_name) { $data.compose_project_name }

$netFrameworkAvailableVersions = @("45", "451", "452", "46", "461", "462", "47", "471", "472", "48", "481")

$solutionRoot = Find-ProjectRoot -startPath $PWD.Path
$workloadName = $data.source_workload
$shared = Initialize-SharedState -data $data
$parentPath = $PWD.Path
$sourceWorkloadPath = $data.shared_state.childrenPaths[$workloadName] ?? $parentPath
$isChildProject = $sourceWorkloadPath -ne $parentPath
$containers = Get-Containers -data $data

if ($framework -eq "net" -and $netFrameworkAvailableVersions -contains $version)
{
    $shared = ManageNetFramework -data $data
}
elseif ($framework -eq "net")
{
    Set-NetCoreDockerfile -targetDirectory $sourceWorkloadPath 
}

if ($solutionRoot)
{
    if ($isChildProject) {
        # $parentName = (Get-ScoreContent -dirPath $parentPath).metadata.name
        # $parentDcProjectPath = Join-Path -Path $solutionRoot -ChildPath "docker" -ChildPath $parentName
        # $c = Get-Content -Path "$parentDcProjectPath\launchSettings.json" -Raw
        # $launchSettingsContent = $c | ConvertFrom-Json -AsHashtable -Depth 10
        # $launchSettingsContent.profiles.Docker_Compose.serviceActions[$workloadName] = "StartDebugging"
        #Set-Content -Path "$parentDcProjectPath\launchSettings.json" -Value $launchSettingsContent -Encoding UTF8

    }else{
        Ensure-DockerComposeProject -solutionRoot $solutionRoot -dcprojName $workloadName -refProjPath $sourceWorkloadPath -composeProjectName $composeProjectName -serviceName $workloadName -serviceContainers $containers
    }
}

$output = @{
    resource_outputs = @{
        framework = $framework
        version = $version
    }
    shared_state = $shared
}

$outputJson = $output | ConvertTo-Json -Depth 10
[Console]::Out.Write($outputJson)

# powershell -Command "Get-Content input_data.json | pwsh -File .score-compose\framework_spec.ps1"