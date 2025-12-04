$output = @{
    resource_outputs = @{
    }
}

$outputJson = $output | ConvertTo-Json
[Console]::Out.Write($outputJson)