[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Project,

    [Parameter(Position = 1)]
    [Alias("Host")]
    [string]$GitLabHost = "gitlab.com",

    [Parameter()]
    [string]$Token = $env:GITLAB_TOKEN,

    [ValidateRange(1, 100)]
    [int]$PerPage = 20,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Page = 1,

    [switch]$AllPages
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


function Get-GitLabProjectArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Project,

        [Parameter(Mandatory = $true)]
        [string]$ApiBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [ValidateRange(1, 100)]
        [int]$PerPage = 20,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Page = 1,

        [switch]$AllPages
    )

    $encodedProject = [System.Net.WebUtility]::UrlEncode($Project)
    $results = [System.Collections.Generic.List[object]]::new()
    $pageNumber = $Page

    do {
        $headersContainer = $null
        $jobs = Invoke-GitLabRestApi `
            -BaseUrl $ApiBaseUrl `
            -Token $Token `
            -Route "projects/$encodedProject/jobs" `
            -Query @{ per_page = $PerPage; page = $pageNumber; include_retried = "true" } `
            -ResponseHeaders ([ref]$headersContainer)

        if ($jobs -isnot [System.Array]) {
            if ($null -eq $jobs) {
                $jobList = @()
            } else {
                $jobList = @($jobs)
            }
        } else {
            $jobList = $jobs
        }

        if ($jobList.Count -eq 1 -and ($jobList[0].PSObject.Properties.Name -contains "message") -and -not ($jobList[0].PSObject.Properties.Name -contains "id")) {
            throw "GitLab API error: $($jobList[0].message)"
        }

        if ($jobList.Count -eq 0) {
            Write-Verbose "No more jobs returned."
            break
        }

        foreach ($job in $jobList) {
            if ($null -eq $job) {
                continue
            }

            $artifactCandidates = @()

            if ($job.PSObject.Properties.Name -contains "artifacts" -and $null -ne $job.artifacts) {
                $artifactCandidates = @($job.artifacts | Where-Object { $_ -ne $null })
            }

            if ($artifactCandidates.Count -eq 0 -and $job.PSObject.Properties.Name -contains "artifacts_file" -and $job.artifacts_file) {
                $artifactCandidates = @($job.artifacts_file)
            }

            if ($artifactCandidates.Count -eq 0) {
                continue
            }

            $pipelineId = $null
            if ($job.PSObject.Properties.Name -contains "pipeline" -and $job.pipeline) {
                $pipelineId = $job.pipeline.id
            }

            $downloadRoute = "projects/$encodedProject/jobs/$($job.id)/artifacts"
            $httpDownloadUrl = Build-GitLabApiUri -BaseUrl $ApiBaseUrl -Route $downloadRoute

            foreach ($artifact in $artifactCandidates) {
                if ($null -eq $artifact) {
                    continue
                }

                $filename = $null
                $filesize = $null
                $filetype = $null
                $fileformat = $null
                $expiresAt = $null

                foreach ($property in @("filename", "file_name")) {
                    if ($artifact.PSObject.Properties.Name -contains $property) {
                        $filename = $artifact.$property
                        break
                    }
                }

                foreach ($property in @("size", "filesize")) {
                    if ($artifact.PSObject.Properties.Name -contains $property) {
                        $filesize = $artifact.$property
                        break
                    }
                }

                foreach ($property in @("file_type", "type")) {
                    if ($artifact.PSObject.Properties.Name -contains $property) {
                        $filetype = $artifact.$property
                        break
                    }
                }

                if ($artifact.PSObject.Properties.Name -contains "file_format") {
                    $fileformat = $artifact.file_format
                }

                if ($artifact.PSObject.Properties.Name -contains "expire_at") {
                    $expiresAt = $artifact.expire_at
                }

                if ($filesize -is [double] -or $filesize -is [float]) {
                    $filesize = [long][Math]::Round($filesize)
                }

                $commitSha = $null
                if ($job.PSObject.Properties.Name -contains "commit" -and $job.commit) {
                    if ($job.commit.PSObject.Properties.Name -contains "sha") {
                        $commitSha = $job.commit.sha
                    } elseif ($job.commit.PSObject.Properties.Name -contains "id") {
                        $commitSha = $job.commit.id
                    }
                }

                $curlCommand = "curl --header `"PRIVATE-TOKEN: <token>`" `"$httpDownloadUrl`" --output artifact.zip"

                $results.Add([pscustomobject]@{
                    JobId           = $job.id
                    JobName         = $job.name
                    Stage           = $job.stage
                    Status          = $job.status
                    PipelineId      = $pipelineId
                    Ref             = $job.ref
                    CommitSha       = $commitSha
                    FileName        = $filename
                    FileType        = $filetype
                    FileFormat      = $fileformat
                    FileSizeBytes   = $filesize
                    ExpiresAt       = $expiresAt
                    DownloadUrl     = $httpDownloadUrl
                    CurlCommandHint = $curlCommand
                    CreatedAt       = $job.created_at
                    FinishedAt      = $job.finished_at
                })
            }
        }

        if (-not $AllPages) {
            break
        }

        $nextPageValue = $null
        if ($headersContainer -and $headersContainer.ContainsKey("X-Next-Page")) {
            $nextPageValue = $headersContainer["X-Next-Page"]
        }

        if ([string]::IsNullOrWhiteSpace($nextPageValue)) {
            break
        }

        $pageNumber = [int]$nextPageValue
        if ($pageNumber -le 0) {
            break
        }
    } while ($true)

    return $results.ToArray()
}

$apiBaseUrl = Get-GitLabApiBaseUrl -GitLabHost $GitLabHost

$identityMessage = Get-GitLabIdentityMessage -ApiBaseUrl $apiBaseUrl -Token $Token
if ($identityMessage) {
    Write-Host $identityMessage
}

$artifacts = Get-GitLabProjectArtifacts -Project $Project -ApiBaseUrl $apiBaseUrl -Token $Token -PerPage $PerPage -Page $Page -AllPages:$AllPages

if (-not $artifacts -or $artifacts.Count -eq 0) {
    Write-Verbose "No artifacts available for project '$Project'."
    return
}

$artifacts

# pwsh ./sandbox.ps1 -Project "kirol-igb/servidor/lsports" -AllPages -Verbose