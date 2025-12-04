
Set-StrictMode -Version Latest

class LaunchSettings {
    [hashtable]$EnvironmentVariables
    [string]$LineEnding

    LaunchSettings([hashtable]$environmentVariables) {
        $this.EnvironmentVariables = if ($environmentVariables) { $environmentVariables } else { throw "Environment variables are required" }
        $this.LineEnding = "CRLF"
    }

    [void] ApplyEnvironmentToLaunchProfile([string]$projectDirectory, [string]$profileName) {
        if (-not $this.EnvironmentVariables -or $this.EnvironmentVariables.Count -eq 0) {
            return
        }
        $path = $this.GetLaunchSettingsPath($projectDirectory)
        if (-not $path) {
            return
        }
        $this.EnsureDirectory($path)
        $settings = $this.ReadLaunchSettings($path)
        $profiles = $settings["profiles"]
        $this.EnsureLaunchProfile($profiles, $profileName)
        $profiles[$profileName]["environmentVariables"] = $this.EnvironmentVariables
        $json = ConvertTo-Json -InputObject $settings -Depth 20
        Set-Content -Path $path -Value $json -Encoding UTF8
        Set-NormalizedLineEndings -Path $path -LineEnding $this.LineEnding
    }

    hidden [string] GetLaunchSettingsPath([string]$projectDirectory) {
        if ([string]::IsNullOrWhiteSpace($projectDirectory)) {
            return $null
        }
        return Join-Path -Path $projectDirectory -ChildPath "Properties\launchSettings.json"
    }

    hidden [hashtable] ReadLaunchSettings([string]$path) {
        $result = [ordered]@{}
        if (Test-Path -LiteralPath $path) {
            $raw = Get-Content -Path $path -Raw
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                try {
                    $result = ConvertFrom-Json -InputObject $raw -AsHashtable -Depth 20
                } catch {
                    $result = [ordered]@{}
                }
            }
        }
        if (-not $result) {
            $result = [ordered]@{}
        }
        if (-not $result.ContainsKey("profiles") -or -not ($result["profiles"] -is [System.Collections.IDictionary])) {
            $result["profiles"] = [ordered]@{}
        }
        return $result
    }

    hidden [void] EnsureLaunchProfile([hashtable]$profiles, [string]$profileName) {
        if (-not $profiles.ContainsKey($profileName) -or -not ($profiles[$profileName] -is [System.Collections.IDictionary])) {
            $profiles[$profileName] = [ordered]@{}
        }
        if (-not $profiles[$profileName].ContainsKey("commandName") -or [string]::IsNullOrWhiteSpace([string]$profiles[$profileName]["commandName"])) {
            $profiles[$profileName]["commandName"] = "Project"
        }
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