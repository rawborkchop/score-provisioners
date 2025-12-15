using module 'framework/FrameworkProvisionerFactory.psm1'
using module 'framework/Context.psm1'

. .score-compose/helper_functions.ps1
Set-StrictMode -Version Latest

trap {
    Write-Error "Error fatal: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Error "Stack trace:`n$($_.ScriptStackTrace)"
    }
    break
}

$inputJson = [Console]::In.ReadToEnd()
#$inputJson | Out-File -FilePath "input_data.json" -Encoding UTF8

$data = $inputJson | ConvertFrom-Json -AsHashtable -Depth 10

$context = [Context]::new($data)

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

# pwsh -Command "[Console]::Out.Write((Get-Content input_data.json -Raw))" | pwsh -File framework_spec.ps1