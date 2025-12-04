function Get-ParamValue {
    param(
        [hashtable]$Params,
        [string[]]$Keys,
        $Default = $null
    )

    foreach ($key in $Keys) {
        if ($Params.ContainsKey($key)) {
            $value = $Params[$key]
            if ($null -ne $value) {
                $stringValue = [string]$value
                if (-not [string]::IsNullOrWhiteSpace($stringValue)) {
                    return $value
                }
            }
        }
    }

    return $Default
}

function Resolve-GitLabToken {
    param(
        [hashtable]$Params
    )

    $token = Get-ParamValue -Params $Params -Keys @("token", "gitlab_token", "gitlabToken", "private_token", "privateToken")
    if (-not $token) {
        $token = $env:GITLAB_TOKEN
    }

    if ([string]::IsNullOrWhiteSpace([string]$token)) {
        throw "Se requiere un token de acceso a GitLab. Define resource_params.token o la variable de entorno GITLAB_TOKEN."
    }

    return $token
}

function Get-GitLabApiBaseUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabHost
    )

    $normalized = $GitLabHost.Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "GitLab host no puede estar vacío."
    }

    if ($normalized -notmatch '^https?://') {
        $normalized = "https://$normalized"
    }

    try {
        $builder = [System.UriBuilder]::new($normalized)
    } catch {
        throw "No se pudo interpretar '$GitLabHost' como una URI válida."
    }

    $path = $builder.Path
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "/"
    }

    $path = $path.TrimEnd('/')
    if ($path -match '/api/v4$') {
        $builder.Path = $path
    } elseif ($path.Length -le 1) {
        $builder.Path = "/api/v4"
    } else {
        $builder.Path = "$path/api/v4"
    }

    return $builder.Uri.AbsoluteUri.TrimEnd('/')
}

function Build-GitLabApiUri {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Route,

        [hashtable]$Query
    )

    $cleanRoute = $Route.TrimStart('/')
    $uri = "$BaseUrl/$cleanRoute"

    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($key in $Query.Keys) {
            $value = $Query[$key]
            if ($null -eq $value) { continue }
            $encodedKey = [System.Net.WebUtility]::UrlEncode([string]$key)
            $encodedValue = [System.Net.WebUtility]::UrlEncode([string]$value)
            "$encodedKey=$encodedValue"
        }

        if ($pairs) {
            $uri = $uri + "?" + ($pairs -join "&")
        }
    }

    return $uri
}

function Get-ArtifactDownloadUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$JobName
    )

    $encodedProject = [System.Net.WebUtility]::UrlEncode($Project)
    $route = "projects/$encodedProject/jobs/artifacts/$Version/download"
    return Build-GitLabApiUri -BaseUrl $BaseUrl -Route $route -Query @{ job = $JobName }
}

function Download-Artifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $headers = @{ "PRIVATE-TOKEN" = $Token }
    Invoke-WebRequest -Uri $ArtifactUrl -Headers $headers -OutFile $Destination
}

function Get-KirolAppPackagePath {
    param(
        [hashtable]$Params,
        [string]$DownloadRoot,
        [string]$AppName,
        [string]$AppVersion,
        [string]$ProjectPath
    )

    if (-not (Test-Path -LiteralPath $DownloadRoot)) {
        New-Item -ItemType Directory -Path $DownloadRoot | Out-Null
    }

    $project = Get-ParamValue -Params $Params -Keys @("project", "gitlab_project", "gitlabProject")
    if (-not $project) {
        throw "resource_params.project es obligatorio para descargar el artefacto."
    }

    $token = Resolve-GitLabToken -Params $Params
    $gitlabHost = Get-ParamValue -Params $Params -Keys @("gitlab_host", "gitlabHost") -Default "gitlab.com"
    $jobName = Get-ParamValue -Params $Params -Keys @("job_name", "jobName") -Default "build"

    $artifactFileName = "$AppName-$AppVersion.zip"
    $artifactPath = Join-Path -Path $DownloadRoot -ChildPath $artifactFileName
    if (Test-Path -LiteralPath $artifactPath) {
        Remove-Item -Path $artifactPath -Force
    }

    $packageRoot = Join-Path -Path $DownloadRoot -ChildPath "$AppName-$AppVersion"
    if (Test-Path -LiteralPath $packageRoot) {
        Remove-Item -Path $packageRoot -Recurse -Force
    }

    $apiBaseUrl = Get-GitLabApiBaseUrl -GitLabHost $gitlabHost
    $artifactUrl = Get-ArtifactDownloadUrl -BaseUrl $apiBaseUrl -Project $project -Version $AppVersion -JobName $jobName

    Download-Artifact -ArtifactUrl $artifactUrl -Token $token -Destination $artifactPath

    Expand-Archive -LiteralPath $artifactPath -DestinationPath $packageRoot -Force

    $keepArtifact = Get-ParamValue -Params $Params -Keys @("keep_artifact", "keepArtifact", "preserve_artifact", "preserveArtifact")
    if (-not $keepArtifact) {
        Remove-Item -Path $artifactPath -Force
    }

    $normalizedProjectPath = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$ProjectPath)) {
        $normalizedProjectPath = ([string]$ProjectPath).TrimStart('/', '\\')
    }

    if ([string]::IsNullOrWhiteSpace([string]$normalizedProjectPath)) {
        $candidate = $packageRoot
    } else {
        $candidate = Join-Path -Path $packageRoot -ChildPath $normalizedProjectPath
        if (-not (Test-Path -LiteralPath $candidate)) {
            $subDirs = Get-ChildItem -Path $packageRoot -Directory -ErrorAction SilentlyContinue
            if ($subDirs.Count -eq 1) {
                $candidate = Join-Path -Path $subDirs[0].FullName -ChildPath $normalizedProjectPath
            }
        }
    }

    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "No se encontró la ruta '$ProjectPath' dentro del artefacto descargado."
    }

    $scorePath = Join-Path -Path $candidate -ChildPath "score.yaml"
    if (-not (Test-Path -LiteralPath $scorePath)) {
        $scoreFile = Get-ChildItem -Path $packageRoot -Filter "score.yaml" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($scoreFile) {
            $candidate = Split-Path -Path $scoreFile.FullName -Parent
        } else {
            throw "No se encontró un archivo score.yaml dentro del artefacto descargado."
        }
    }

    return $candidate
}

function Invoke-ExternalArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Params,
        [Parameter(Mandatory = $true)]
        [string]$DownloadRoot,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$AppVersion,
        [string]$ProjectPath
    )

    $packagePath = Get-KirolAppPackagePath -Params $Params -DownloadRoot $DownloadRoot -AppName $AppName -AppVersion $AppVersion -ProjectPath $ProjectPath
    $manifestPath = Join-Path -Path $packagePath -ChildPath "manifest.json"
    $hashValue = $null
    $expectedHash = Get-ParamValue -Params $Params -Keys @("artifact_hash", "artifactHash", "sha256")
    if ($expectedHash) {
        $hashSource = if (Test-Path -LiteralPath $manifestPath) { $manifestPath } else { Join-Path -Path $packagePath -ChildPath "score.yaml" }
        if (-not (Test-Path -LiteralPath $hashSource)) {
            throw "No fue posible validar el hash del artefacto. Proporciona un manifest.json o score.yaml."
        }
        $hashValue = (Get-FileHash -Path $hashSource -Algorithm SHA256).Hash
        if (-not $hashValue.Equals([string]$expectedHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "El hash del artefacto no coincide con el esperado."
        }
    }

    return @{
        PackagePath = $packagePath
        ManifestPath = if (Test-Path -LiteralPath $manifestPath) { $manifestPath } else { $null }
        Hash = $hashValue
    }
}