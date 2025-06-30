$inputJson = [Console]::In.ReadToEnd()
$data = $inputJson | ConvertFrom-Json
$params = $data.resource_params

$path = if ($params.path) { $params.path } else { (Join-Path -Path $env:USERPROFILE -ChildPath "certs/aspnet.pfx")} #"C:/certs/aspnet.pfx"}
$path = Join-Path -Path $path -ChildPath "score.yaml"

.Shared.