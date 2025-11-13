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
    $urls = @(
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/certificate.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/kirol_app.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/framework_spec.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/local_env_variables.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/helper_functions.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/external_app.ps1",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/01-script.provisioners.yaml",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/02-custom.volumes.provisioners.yaml",
        "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/03-container.provisioners.yaml"
    )

    foreach ($url in $urls) {
        $name = Split-Path $url -Leaf
        $out = Join-Path -Path $dest -ChildPath $name
        Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $out
    }
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