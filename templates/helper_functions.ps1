function Get-ScoreContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$dirPath
    )
    $scorePath = Join-Path -Path $dirPath -ChildPath "score.yaml"
    Import-Module powershell-yaml -Force
    $scoreRaw = Get-Content -Path $scorePath -Raw -Encoding UTF8
    $scoreContent = ConvertFrom-Yaml -Yaml $scoreRaw
    return $scoreContent
}

function Initialize-SharedState {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$data
    )
    
    $shared = @{}
    
    if ($data.shared_state) {
        $shared = $data.shared_state
    }

    if (-not $shared.ContainsKey("commands")) 
    {
        $shared.Add("commands", @())
    }

    if (-not $shared.ContainsKey("childrenPaths")) 
    {
        $shared.Add("childrenPaths", @{})
    }
    
    return $shared
}

function Find-ProjectRoot {
    param (
        [string]$startPath
    )
    
    $currentPath = $startPath
    while ($currentPath -ne $null) {
        $slnFiles = Get-ChildItem -Path $currentPath -Filter "*.sln" -ErrorAction SilentlyContinue
        if ($slnFiles.Count -gt 0) {
            return $currentPath
        }
        $currentPath = Split-Path $currentPath -Parent
        if ([string]::IsNullOrEmpty($currentPath)) {
            break
        }
    }
    return $null
}

function Get-ScoreComposeGenerateCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$dirPath
    )
    $scorePath = Join-Path -Path $dirPath -ChildPath "score.yaml"
    $overrides = Get-ChildItem -Path $dirPath -Filter "*score*.yaml" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "score.yaml" }
    $scoreContent = Get-ScoreContent -dirPath $dirPath
    $containers = @{}
    $containerIndex = 0
    foreach ($key in $scoreContent.containers.Keys) 
    {
        $containers["$containerIndex"] = $key
        $containerIndex++
    }
    $command = "score-compose generate $scorePath --output docker-compose.yaml"
    foreach ($container in $containers.Values) 
    {
        $command += " --build `"$container={'context':'$dirPath', 'dockerfile':'Dockerfile'}`""
    }
    foreach ($override in $overrides) 
    {
        $command += " --overrides-file `"$($override.FullName)`""
    }
    return $command
}

#. templates/helper_functions.ps1; Get-ScoreComposeGenerateCommand -dirPath "../lsports/src/Ksoft.IntegrationServices.LSports.Racing.Host"