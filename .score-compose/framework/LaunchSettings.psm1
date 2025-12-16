using module './DockerComposeEnvironment.psm1'
. .score-compose/helper_functions.ps1
Set-StrictMode -Version Latest

class LaunchSettings {
    [DockerComposeEnvironment]$ComposeEnvironment
    [string]$LineEnding
    [string]$DefaultProfileName

    LaunchSettings([string]$composePath) {
        $this.ComposeEnvironment = [DockerComposeEnvironment]::new($composePath)
        $this.LineEnding = "CRLF"
        $this.DefaultProfileName = "Default"
    }

    [void] ApplyEnvironmentToLaunchProfile([string]$serviceName, [string]$projectDirectory) {
        $this.ApplyEnvironmentToLaunchProfile($serviceName, $projectDirectory, $serviceName)
    }

    [void] ApplyEnvironmentToLaunchProfile([string]$serviceName, [string]$projectDirectory, [string]$profileName) {
        $environmentVariables = $this.ComposeEnvironment.GetServiceEnvironmentVariables($serviceName)
        if (-not $environmentVariables -or $environmentVariables.Count -eq 0) {
            Write-Warning "Service '$serviceName' has no environment variables defined."
            return
        }
        $path = $this.GetLaunchSettingsPath($projectDirectory)
        if (-not $path) {
            return
        }
        $this.EnsureDirectory($path)
        $settings = $this.ReadLaunchSettings($path)
        $profiles = $settings["profiles"]
        $this.ConfigureEnvironmentProfile($profiles, $profileName, $environmentVariables)
        $this.ConfigureDefaultProfile($profiles, $profileName)
        $json = ConvertTo-Json -InputObject $settings -Depth 20
        Set-Content -Path $path -Value $json -Encoding UTF8
        Set-NormalizedLineEndings -Path $path -LineEnding $this.LineEnding
    }

    hidden [void] ConfigureEnvironmentProfile([hashtable]$profiles, [string]$profileName, [hashtable]$environmentVariables) {
        $this.EnsureLaunchProfile($profiles, $profileName)
        $profiles[$profileName]["commandName"] = "Project"
        $profiles[$profileName]["environmentVariables"] = $environmentVariables
    }

    hidden [void] ConfigureDefaultProfile([hashtable]$profiles, [string]$profileName) {
        $defaultName = $this.ResolveDefaultProfileName($profileName)
        if ([string]::IsNullOrWhiteSpace($defaultName)) {
            return
        }
        $this.EnsureLaunchProfile($profiles, $defaultName)
        if ($profiles[$defaultName].ContainsKey("environmentVariables")) {
            $profiles[$defaultName].Remove("environmentVariables")
        }
    }

    hidden [string] ResolveDefaultProfileName([string]$profileName) {
        if ([string]::IsNullOrWhiteSpace($this.DefaultProfileName)) {
            return $null
        }
        if ($this.DefaultProfileName -eq $profileName) {
            return "$profileName-default"
        }
        return $this.DefaultProfileName
    }

    hidden [string] GetLaunchSettingsPath([string]$projectDirectory) {
        if ([string]::IsNullOrWhiteSpace($projectDirectory)) {
            return $null
        }
        return Join-Path -Path $projectDirectory -ChildPath "Properties\launchSettings.json"
    }

    hidden [void] EnsureLaunchProfile([hashtable]$profiles, [string]$profileName) {
        if (-not $profiles.Contains($profileName)) {
            $profiles[$profileName] = @{}
        }
        if (-not $profiles[$profileName].Contains("commandName") -or [string]::IsNullOrWhiteSpace([string]$profiles[$profileName]["commandName"])) {
            $profiles[$profileName]["commandName"] = "Project"
        }
    }

    hidden [hashtable] ReadLaunchSettings([string]$path) {
        $result = @{}
        if (Test-Path -LiteralPath $path) {
            $raw = Get-Content -Path $path -Raw
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                try {
                    $result = $raw | ConvertFrom-Json -AsHashtable -Depth 20
                } catch {
                    $result = @{}
                }
            }
        }
        if (-not $result) {
            $result = @{}
        }
        $result = [Hashtable]$result
        if (-not ($result.Contains("profiles"))) {
            $result.Add("profiles", @{})
        }
        return $result
    }   

    hidden [void] EnsureDirectory([string]$path) {
        $directory = Split-Path -Path $path -Parent
        if ([string]::IsNullOrWhiteSpace($directory)) {
            return
        }
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
    }
}