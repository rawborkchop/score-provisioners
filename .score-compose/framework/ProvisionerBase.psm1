using module './Context.psm1'
using module './DockerProject.psm1'

class ProvisionerBase {
    [Context]$Context
    [DockerProject]$DockerProject

    ProvisionerBase([Context]$context) {
        $this.Context = $context
        $this.DockerProject = [DockerProject]::new($this.Context)
    }

    [void] Execute() {
        if ($this.Context.IsChildProject) {
            $this.DockerProject.EnsureDockerComposeProject()
            $this.UpdateComposeDebugFile()
        }
        
    }

    hidden [void] UpdateComposeDebugFile() {
        throw "Not implemented"
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