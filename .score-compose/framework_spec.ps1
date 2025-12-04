. .score-compose/helper_functions.ps1
. .score-compose/external_app.ps1
Set-StrictMode -Version Latest

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    return
}

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = if ($data.resource_params) { $data.resource_params } else { @{} }

$shared = Initialize-SharedState -data $data
$workloadName = [string]$data.source_workload
$parentPath = $sourceWorkloadPath = $data.shared_state.childrenPaths[$workloadName] ?? $parentPath
$isChildProject = $sourceWorkloadPath -ne $parentPath
$solutionRoot = Find-ProjectRoot -startPath $parentPath
$containers = @()
if ($data.workload_services) {
    $containers = Get-Containers -data $data
}
$composeProjectName = if ($data.compose_project_name) { [string]$data.compose_project_name } else { $null }

$framework = $params.framework
$version = $params.version

$context = [ordered]@{
    Framework = $framework
    Version = $version
    WorkloadName = $workloadName
    SharedState = $shared
    SourceWorkloadPath = $sourceWorkloadPath
    ParentPath = $parentPath
    SolutionRoot = $solutionRoot
    ComposeProjectName = $composeProjectName
    Containers = $containers
}

$provisioner = [FrameworkProvisionerFactory]::Create($context)
if ($provisioner) {
    $provisioner.Execute()
}

$output = @{
    resource_outputs = @{
        framework = $context.Framework
        version = $context.Version
    }
    shared_state = $context.SharedState
}

$outputJson = $output | ConvertTo-Json -Depth 10
[Console]::Out.Write($outputJson)