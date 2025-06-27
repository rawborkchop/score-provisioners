param(
    [Parameter(Mandatory=$true)]
    [string]$packageId,
    
    [Parameter(Mandatory=$true)]
    [string]$packageVersion
)

function Find-NuGetConfig {
    param (
        [string]$startPath
    )
    
    $currentPath = $startPath
    while ($currentPath -ne $null) {
        $configPath = Join-Path $currentPath "nuget.config"
        if (Test-Path $configPath) {
            return $configPath
        }
        $currentPath = Split-Path $currentPath -Parent
        if ([string]::IsNullOrEmpty($currentPath)) {
            break
        }
    }
    return $null
}

$projectRoot = $PWD.Path
$nugetConfigPath = Find-NuGetConfig -startPath $projectRoot
$downloadPath = "$projectRoot\packages"

if (-not (Test-Path $nugetExePath)) {
    Write-Error "❌ No se encontró nuget.exe en $nugetExePath"
    exit 1
}

if (-not $nugetConfigPath) {
    Write-Error "❌ No se encontró nuget.config en ningún directorio padre"
    exit 1
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
} else {
    Write-Error "❌ Error al instalar el paquete."
}
