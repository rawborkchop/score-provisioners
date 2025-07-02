$output = @{
}

$outputJson = $output | ConvertTo-Json
[Console]::Out.Write($outputJson)