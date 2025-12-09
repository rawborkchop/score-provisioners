. .score-compose/helper_functions.ps1
Set-StrictMode -Version Latest

using module '.score-compose/framework/FrameworkProvisionerFactory.psm1'

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) {
    return
}

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = if ($data.resource_params) { $data.resource_params } else { @{} }

# Prepare data in the format Context expects
$contextData = @{
    framework = $params.framework
    version = $params.version
    workloadName = [string]$data.source_workload
    shared_state = $data.shared_state
    workload_services = $data.workload_services
    hostingModel = $params.hostingModel
    entryPoint = $params.entryPoint
}

$context = [Context]::new($contextData)
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
