class Dockerfile {
    [string]$Content
    [string]$ParentPath
    [string]$SourceWorkloadPath
    [string]$Version
    [string]$TemplateName

    Dockerfile([string]$parentPath, [string]$sourceWorkloadPath, [string]$version, [string]$templateName) {
        $this.ParentPath = $parentPath
        $this.SourceWorkloadPath = $sourceWorkloadPath
        $this.Version = $version
        $this.TemplateName = $templateName
    }

    [void] SetDockerfile() {
            $this.PrepareContent()
            $this.WriteDockerfile()
        }

    hidden [void] PrepareContent() {
        $templatePath = Join-Path -Path $this.ParentPath -ChildPath ".score-compose/templates/"  + $this.TemplateName
        if (-not (Test-Path -LiteralPath $templatePath)) {
            throw "Dockerfile template not found at '$templatePath'"
        }
        $this.Content = Get-Content -Path $templatePath -Raw
        if (-not [string]::IsNullOrWhiteSpace($this.Version)) {
            $this.Content = $this.Content -replace '{{DOTNET_VERSION}}', $this.Version
        }
    }

    hidden [void] WriteDockerfile() {
        if ([string]::IsNullOrWhiteSpace($this.SourceWorkloadPath)) {
            return
        }
        if (-not (Test-Path -LiteralPath $this.SourceWorkloadPath)) {
            return
        }
        $dockerfilePath = Join-Path -Path $this.SourceWorkloadPath -ChildPath "Dockerfile"
        Set-Content -Path $dockerfilePath -Value $this.Content -Encoding UTF8
    }
}