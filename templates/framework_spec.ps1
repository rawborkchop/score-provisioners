. .score-compose/helper_functions.ps1

$inputJson = [Console]::In.ReadToEnd()
#$inputJson | Out-File -FilePath "input_data.json" -Encoding UTF8

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10
$params = $data.resource_params

$framework = if ($params.framework) { $params.framework }
$apptype = if ($params.apptype) { $params.apptype }
$version = if ($params.version) { $params.version }

if ($framework -eq "net" -and $version -eq "472")
{
    $containers = @()
    $workload_name = $data.source_workload
    foreach ($key in $data.workload_services[$workload_name].ports.Keys) 
    {
        if ($key -notmatch '^\d+$') {
            $containers += $key
        }
    }

    $shared = Initialize-SharedState -data $data
    foreach ($container in $containers) 
    {
        $filePath = ".score-compose/idle-$workload_name.yaml"
        $override_file = @"
services:
    $($workload_name + "-" + $container): !reset null
"@
        $override_file | Out-File $filePath -Encoding utf8
        $shared.commands += ".score-compose\local_env_variables.ps1 -ServiceName $($workload_name + "-" + $container)"
        $shared.commands += "docker compose -f docker-compose.yaml -f $filePath config > merged.yaml"
        $shared.commands += "Remove-Item $filePath -Force"
        $shared.commands += "Move-Item merged.yaml docker-compose.yaml -Force"
    }
}

$output = @{
    resource_outputs = @{
        framework = $framework
        apptype = $apptype
        version = $version
    }
    shared_state = $shared
}

$outputJson = $output | ConvertTo-Json -Depth 10
[Console]::Out.Write($outputJson)

# powershell -Command "Get-Content input_data.json | pwsh -File .score-compose\framework_spec.ps1"