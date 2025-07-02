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
function Get-NugetPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$packageId,
        
        [Parameter(Mandatory=$true)]
        [string]$packageVersion,

        [Parameter(Mandatory=$true)]
        [string]$downloadPath
    )

    $projectRoot = Find-ProjectRoot -startPath $PWD.Path
    $nugetConfigPath = Join-Path -Path $projectRoot -ChildPath "nuget.config"

    if (-not $nugetConfigPath) {
        Write-Error "❌ No se encontró nuget.config en ningún directorio padre"
        return $false
    }

    if (-not (Test-Path $downloadPath)) {
        New-Item -ItemType Directory -Path $downloadPath | Out-Null
    }

    & nuget install $packageId `
        -Version $packageVersion `
        -ConfigFile $nugetConfigPath `
        -OutputDirectory $downloadPath `
        -NonInteractive

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Paquete instalado correctamente en: $downloadPath"
        return $true
    } else {
        Write-Error "❌ Error al instalar el paquete."
        return $false
    }
}

$inputJson = [Console]::In.ReadToEnd()

$data = $inputJson | ConvertFrom-Json
$params = $data.resource_params

$projectRoot = Find-ProjectRoot -startPath $PWD.Path

$projectPath = if ($params.path) { $params.path }
$name = if ($params.name) { $params.name }
$version = if ($params.version) { $params.version }

if($projectPath) {
    $path = Join-Path -Path $projectRoot -ChildPath $projectPath
} elseif($name -and $version) {
    $downloadPath = Join-Path -Path $projectRoot -ChildPath "packages"
    Get-NugetPackage -packageId $name -packageVersion $version -downloadPath $downloadPath
    $path = $downloadPath
} else {
    #Write-Error "No name, version or path provided"
}

$path = Join-Path -Path $path -ChildPath "score.yaml"
if((Test-Path $path) -and ($path -ne "score.yaml")) {
    score-compose generate $path --build "app={'context':'.', 'dockerfile':'Dockerfile'}"

    $scoreContent = Get-Content -Path $path 
    $name = ($scoreContent -split '\n' | Where-Object { $_ -match '^\s*name:\s*(.+)$' } | Select-Object -First 1) -replace '^\s*name:\s*', ''
    $distinctPorts = @()
    $service = $data.workload_services.$name
    if ($service.ports) {
        foreach ($portName in $service.ports.PSObject.Properties.Name) {
            $port = $service.ports.$portName
            if ($port.port -and $distinctPorts -notcontains $port.port) {
                $distinctPorts += $port.port
            }
        }
    }
}

$output = @{
    resource_outputs = @{
        ports = $distinctPorts
    }
}

$outputJson = $output | ConvertTo-Json
[Console]::Out.Write($outputJson)