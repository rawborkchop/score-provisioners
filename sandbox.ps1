[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Project,

    [Parameter(Position = 1)]
    [Alias("Host")]
    [string]$GitLabHost = "gitlab.com",

    [Parameter()]
    [string]$Token = $env:GITLAB_TOKEN,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter()]
    [string]$JobName = "build",

    [Parameter()]
    [string]$ArtifactName = "artifacts.zip",

    [Parameter()]
    [string]$OutputPath
)

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Provide a GitLab access token using -Token or the GITLAB_TOKEN environment variable."
}

function Get-GitLabApiBaseUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabHost
    )

    $normalized = $GitLabHost.Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "GitLab host cannot be empty."
    }

    if ($normalized -notmatch '^https?://') {
        $normalized = "https://$normalized"
    }

    try {
        $builder = [System.UriBuilder]::new($normalized)
    } catch {
        throw "Unable to parse GitLabHost '$GitLabHost' as a valid URI."
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

function Invoke-GitLabRestApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$Route,

        [hashtable]$Query,

        [ref]$ResponseHeaders
    )

    $uri = Build-GitLabApiUri -BaseUrl $BaseUrl -Route $Route -Query $Query
    $headers = @{ "PRIVATE-TOKEN" = $Token }

    Write-Verbose ("Calling GitLab REST API: {0}" -f $uri)

    try {
        $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop -ResponseHeadersVariable respHeaders

        if ($PSBoundParameters.ContainsKey('ResponseHeaders')) {
            $headerTable = @{}
            if ($respHeaders -is [System.Collections.IDictionary]) {
                foreach ($key in $respHeaders.Keys) {
                    $headerTable[$key] = $respHeaders[$key]
                }
            } elseif ($respHeaders -and $respHeaders.PSObject.Properties.Name -contains "GetEnumerator") {
                foreach ($entry in $respHeaders.GetEnumerator()) {
                    $headerTable[$entry.Key] = $entry.Value
                }
            }

            $ResponseHeaders.Value = $headerTable
        }

        return $result
    } catch {
        $errorRecord = $_
        $details = $null

        if ($errorRecord.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($errorRecord.ErrorDetails.Message)) {
            $details = $errorRecord.ErrorDetails.Message
        } elseif ($errorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($errorRecord.Exception.Message)) {
            $details = $errorRecord.Exception.Message
        }

        if (-not [string]::IsNullOrWhiteSpace($details)) {
            throw "GitLab API call to '$uri' failed: $details"
        }

        throw "GitLab API call to '$uri' failed."
    }
}

function Get-GitLabIdentityMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    try {
        $user = Invoke-GitLabRestApi -BaseUrl $ApiBaseUrl -Token $Token -Route "user"
        if ($null -eq $user) {
            return $null
        }

        if ($user.PSObject.Properties.Name -contains "username" -and $user.username) {
            return "Connected to GitLab as $($user.username)."
        }

        if ($user.PSObject.Properties.Name -contains "name" -and $user.name) {
            return "Connected to GitLab as $($user.name)."
        }

        return "Connected to GitLab successfully."
    } catch {
        Write-Verbose ("Unable to confirm GitLab identity: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Get-ProjectId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$Project
    )

    $route = "projects/{0}" -f ([System.Web.HttpUtility]::UrlEncode($Project))
    $projectInfo = Invoke-GitLabRestApi -BaseUrl $BaseUrl -Token $Token -Route $route
    if (-not $projectInfo) {
        throw "No se encontró el proyecto '$Project'."
    }

    return $projectInfo.id
}
function Get-JobArtifactUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [int]$ProjectId,

        [Parameter(Mandatory = $true)]
        [int]$PipelineId,

        [Parameter(Mandatory = $true)]
        [string]$JobName,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactName
    )

    $route = "projects/$ProjectId/pipelines/$PipelineId/jobs"
    $jobs = Invoke-GitLabRestApi -BaseUrl $BaseUrl -Token $Token -Route $route -Query @{ "per_page" = 100 }
    if (-not $jobs) {
        throw "No se encontraron jobs en el pipeline '$PipelineId'."
    }

    $job = $jobs | Where-Object { $_.name -eq $JobName }
    if (-not $job) {
        throw "No se encontró el job '$JobName' en el pipeline '$PipelineId'."
    }

    $route = "projects/$ProjectId/jobs/$($job.id)/artifacts/$ArtifactName"
    return "$BaseUrl/$route"
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

    $encodedProject = [System.Web.HttpUtility]::UrlEncode($Project)
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

$apiBaseUrl = Get-GitLabApiBaseUrl -GitLabHost $GitLabHost
$artifactUrl = Get-ArtifactDownloadUrl -BaseUrl $apiBaseUrl -Project $Project -Version $Version -JobName $JobName

if ($OutputPath) {
    $destination = $null
    if (Test-Path -LiteralPath $OutputPath) {
        $item = Get-Item -LiteralPath $OutputPath
        if ($item.PSIsContainer) {
            $destination = Join-Path -Path $item.FullName -ChildPath $ArtifactName
        } else {
            $destination = $item.FullName
        }
    } else {
        $parentDir = Split-Path -Parent $OutputPath
        if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetFileName($OutputPath))) {
            $destination = Join-Path -Path $OutputPath -ChildPath $ArtifactName
        } else {
            $destination = $OutputPath
        }
    }

    Download-Artifact -ArtifactUrl $artifactUrl -Token $Token -Destination $destination
    Write-Output (@{
        project = $Project
        version = $Version
        jobName = $JobName
        artifactUrl = $artifactUrl
        destination = $destination
    } | ConvertTo-Json -Depth 5)
} else {
    Write-Output (@{
        project = $Project
        version = $Version
        jobName = $JobName
        artifactUrl = $artifactUrl
    } | ConvertTo-Json -Depth 5)
}

# pwsh ./sandbox.ps1 -Project "kirol-igb/servidor/lsports" -Version "pre1.11.0-beta.0.3" -OutputPath "C:\users\b.leon\desktop"