Remove-Item -Path ".score-compose" -Recurse -Force
#Remove-Item -Path ".score-compose/state.yaml" -Recurse -Force
score-compose init

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Instalando el módulo powershell-yaml..."
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}

$urls = @(
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/certificate.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/kirol_app.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/framework_spec.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/local_env_variables.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/helper_functions.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/docker_file_generation.ps1",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/01-script.provisioners.yaml",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/02-custom.volumes.provisioners.yaml",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/03-specification.provisioners.yaml",
  "https://raw.githubusercontent.com/rawborkchop/score-provisioners/main/templates/04-container.provisioners.yaml"
)

$dest = Join-Path -Path (Get-Location).Path -ChildPath '.score-compose'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

foreach ($url in $urls) {
    $name = Split-Path $url -Leaf
    $out = Join-Path -Path $dest -ChildPath $name
    Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $out
}

. .score-compose/helper_functions.ps1
$command = Get-ScoreComposeGenerateCommand -dirPath "./"
Invoke-Expression $command

$stateRaw = Get-Content -Path ".score-compose/state.yaml" -Raw -Encoding UTF8
Import-Module powershell-yaml -Force
$state = ConvertFrom-Yaml -Yaml $stateRaw

if ($state.shared_state -and $state.shared_state.ContainsKey("commands") -and $state.shared_state.commands) 
{
    $i = 0
    while ($i -lt $state.shared_state.commands.Count) 
    {
        Invoke-Expression $state.shared_state.commands[$i]
        if ($state.shared_state.commands[$i].StartsWith("score-compose generate")) 
        {
            $stateRaw = Get-Content -Path ".score-compose/state.yaml" -Raw -Encoding UTF8
            Import-Module powershell-yaml -Force
            $state = ConvertFrom-Yaml -Yaml $stateRaw
        }
        $i++
    }
}

Write-Host("Score compose end")