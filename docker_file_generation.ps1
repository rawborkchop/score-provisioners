$output = @{
    shared_state = @{
        arguments = @(
            'generate'
            '--build'; ''
        )
    }
}

$outputJson = $output | ConvertTo-Json
[Console]::Out.Write($outputJson)