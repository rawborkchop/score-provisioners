param(
    [switch]$debug = $false
)

function Clear-SharedState {
    $statePath = ".score-compose/state.yaml"
    if (Test-Path $statePath) {
        $yamlContent = Get-Content $statePath -Raw
        $stateObj = ConvertFrom-Yaml -Yaml $yamlContent
        if ($stateObj.shared_state -and $stateObj.shared_state.commands) {
            $stateObj.shared_state.commands = @()
            $stateObj.workloads= $null
            $newYaml = ConvertTo-Yaml $stateObj
            Set-Content -Path $statePath -Value $newYaml
        }
    }
}

Clear-SharedState
if (-not (Test-Path "./score.yaml")) {
    Write-Host "Score file not found in current directory"
    Exit 1
}

score-compose init
$dest = Join-Path -Path (Get-Location).Path -ChildPath '.score-compose'

if ($debug) 
{
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    Write-Host "DEBUG MODE: templates will be updated from local source at $scriptDir..."

    $templates = @(
        "certificate.ps1",
        "kirol_app.ps1",
        "framework_spec.ps1",
        "local_env_variables.ps1",
        "helper_functions.ps1",
        "external_app.ps1",
        "docker_file_generation.ps1",
        "01-script.provisioners.yaml",
        "02-custom.volumes.provisioners.yaml",
        "03-container.provisioners.yaml"
    )

    foreach ($template in $templates) {
        $src = Join-Path -Path $scriptDir -ChildPath "templates\$template"
        $dst = Join-Path -Path $dest -ChildPath $template
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $dst -Force
        } else {
            Write-Host "ADVERTENCIA: No se encontró el template $template en $src"
        }
    }
}
else
{
    $repoOwner = "rawborkchop"
    $repoName = "score-provisioners"
    $branch = "main"
    $sourcePath = ".score-compose"

    function Get-GitHubDirectoryContents {
        param(
            [string]$Owner,
            [string]$Repo,
            [string]$Path,
            [string]$Branch,
            [string]$DestinationBase
        )
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/$Path`?ref=$Branch"
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell" }
        foreach ($item in $response) {
            $relativePath = $item.path -replace "^$([regex]::Escape($sourcePath))/?", ""
            $localPath = Join-Path -Path $DestinationBase -ChildPath $relativePath
            if ($item.type -eq "dir") {
                if (-not (Test-Path -LiteralPath $localPath)) {
                    New-Item -ItemType Directory -Path $localPath -Force | Out-Null
                }
                Get-GitHubDirectoryContents -Owner $Owner -Repo $Repo -Path $item.path -Branch $Branch -DestinationBase $DestinationBase
            }
            elseif ($item.type -eq "file") {
                $parentDir = Split-Path -Path $localPath -Parent
                if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                Invoke-WebRequest -Uri $item.download_url -UseBasicParsing -OutFile $localPath
            }
        }
    }

    Write-Host "Downloading .score-compose from GitHub repository..."
    Get-GitHubDirectoryContents -Owner $repoOwner -Repo $repoName -Path $sourcePath -Branch $branch -DestinationBase $dest
}

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing powershell-yaml..."
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}

. .score-compose/helper_functions.ps1
$command = Get-ScoreComposeGenerateCommand -dirPath "./"
Invoke-Expression $command

$stateRaw = Get-Content -Path ".score-compose/state.yaml" -Raw -Encoding UTF8
Import-Module powershell-yaml -Force
$state = ConvertFrom-Yaml -Yaml $stateRaw

if ($state.shared_state -and $state.shared_state.ContainsKey("commands") -and $state.shared_state.commands) {
    $i = 0
    while ($i -lt $state.shared_state.commands.Count) {
        Invoke-Expression $state.shared_state.commands[$i]
        if ($state.shared_state.commands[$i].StartsWith("score-compose generate")) {
            $stateRaw = Get-Content -Path ".score-compose/state.yaml" -Raw -Encoding UTF8
            Import-Module powershell-yaml -Force
            $state = ConvertFrom-Yaml -Yaml $stateRaw
        }
        $i++
    }
}

Write-Host("Score compose end")