using module './Context.psm1'
using module './DockerProject.psm1'

class ProvisionerBase {
    [Context]$Context
    [DockerProject]$DockerProject

    ProvisionerBase([Context]$context) {
        $this.Context = $context
        $this.DockerProject = new DockerProject($this.Context)
    }

    [void] Execute() {
        $this.DockerProject.EnsureDockerComposeProject()       
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

    hidden [void] OverrideIdleComposeServices()
    {
        foreach ($container in $this.Context.Containers) 
        {
            $workloadName = $this.Context.WorkloadName
            $container = $this.Context.Containers[$container]
            $filePath = ".score-compose/idle-$workloadName-$container.yaml"
            $override_file = $this.GetIdleComposeOverrideFile($workloadName, $container)
            $override_file | Out-File $filePath -Encoding utf8
            $this.Context.SharedState.commands += ".score-compose\debbugeable_net_framework.ps1 -ServiceName $($workloadName + "-" + $container)"
            $this.Context.SharedState.commands += "docker compose -f docker-compose.yaml -f $filePath config > merged.yaml"
            $this.Context.SharedState.commands += "Remove-Item $filePath -Force"
            $this.Context.SharedState.commands += "Move-Item merged.yaml docker-compose.yaml -Force"
        }
    }

    hidden [string] GetIdleComposeOverrideFile([string]$workloadName, [string]$container) {
        $templatePath = Join-Path -Path $this.Context.parentPath  -ChildPath "templates/idle_compose.yaml"
        if (-not (Test-Path -LiteralPath $templatePath)) {
            throw "Idle compose template not found at '$templatePath'"
        }
        $content = Get-Content -Path $templatePath -Raw
        return $content -replace '{{WORKLOAD_NAME}}', $workloadName -replace '{{CONTAINER}}', $container
    }
}

