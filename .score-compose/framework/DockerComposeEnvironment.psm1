
Set-StrictMode -Version Latest

class DockerComposeEnvironment {
    [string]$ComposePath
    [hashtable]$ComposeData

    DockerComposeEnvironment([string]$composePath) {
        $this.ComposePath = $composePath
        $this.ComposeData = $null
    }

    [hashtable] GetServiceEnvironmentVariables([string]$serviceName) {
        $this.EnsureComposeLoaded()
        $this.ValidateService($serviceName)
        $service = $this.ComposeData.services[$serviceName]
        return $this.ExtractEnvironmentVariables($service)
    }

    [void] ExportToJsonFile([string]$serviceName, [string]$outputPath) {
        $variables = $this.GetServiceEnvironmentVariables($serviceName)
        $json = ConvertTo-Json -InputObject $variables -Depth 10
        $directory = Split-Path -Path $outputPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Set-Content -Path $outputPath -Value $json -Encoding UTF8
    }

    hidden [void] EnsureComposeLoaded() {
        if ($this.ComposeData) {
            return
        }
        if (-not (Test-Path -LiteralPath $this.ComposePath)) {
            throw "docker-compose.yaml not found at '$($this.ComposePath)'."
        }
        $raw = Get-Content -Path $this.ComposePath -Raw -Encoding UTF8
        $this.ComposeData = ConvertFrom-Yaml -Yaml $raw
    }

    hidden [void] ValidateService([string]$serviceName) {
        if (-not $this.ComposeData.services) {
            throw "No services found in docker-compose.yaml."
        }
        if (-not $this.ComposeData.services.ContainsKey($serviceName)) {
            throw "Service '$serviceName' not found in docker-compose.yaml."
        }
    }

    hidden [hashtable] ExtractEnvironmentVariables([hashtable]$service) {
        $result = [ordered]@{}
        $environment = $service.environment
        if (-not $environment) {
            return $result
        }
        if ($environment -is [System.Collections.IDictionary]) {
            return $this.ExtractFromDictionary($environment)
        }
        return $this.ExtractFromArray($environment)
    }

    hidden [hashtable] ExtractFromDictionary([System.Collections.IDictionary]$environment) {
        $result = [ordered]@{}
        foreach ($key in $environment.Keys) {
            $value = [string]$environment[$key]
            $result[$key] = $this.NormalizeValue($value)
        }
        return $result
    }

    hidden [hashtable] ExtractFromArray([array]$environment) {
        $result = [ordered]@{}
        foreach ($entry in $environment) {
            if ($entry -match "^(.*?)=(.*)$") {
                $result[$matches[1]] = $this.NormalizeValue($matches[2])
            }
        }
        return $result
    }

    hidden [string] NormalizeValue([string]$value) {
        if ($null -eq $value) {
            return $value
        }
        return $value -replace '\\\\', '\'
    }
}

