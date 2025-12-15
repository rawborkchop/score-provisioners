using module './Context.psm1'

class PostRunCommandManager {
    [Context]$Context

    PostRunCommandManager([Context]$context) {
        $this.Context = $context
    }

    [void] OverrideIdleComposeServices()
    {
        foreach ($container in $this.Context.Containers) 
        {
            $workloadName = $this.Context.WorkloadName
            $container = $container
            $filePath = ".score-compose/idle-$workloadName-$container.yaml"
            $override_file = $this.GetIdleComposeOverrideFile($workloadName, $container)
            $override_file | Out-File $filePath -Encoding utf8
            $this.Context.SharedState.commands += "docker compose -f docker-compose.yaml -f $filePath config > merged.yaml"
            $this.Context.SharedState.commands += "Remove-Item $filePath -Force"
            $this.Context.SharedState.commands += "Move-Item merged.yaml docker-compose.yaml -Force"
        }
    }

    hidden [string] GetIdleComposeOverrideFile([string]$workloadName, [string]$container) {
        $templatePath = Join-Path -Path $this.Context.parentPath  -ChildPath ".score-compose/framework/templates/idle_compose.yaml"
        if (-not (Test-Path -LiteralPath $templatePath)) {
            throw "Idle compose template not found at '$templatePath'"
        }
        $content = Get-Content -Path $templatePath -Raw
        return $content -replace '{{WORKLOAD_NAME}}', $workloadName -replace '{{CONTAINER}}', $container
    }

    [void] RegisterLaunchSettingsCommands() {
        foreach ($container in $this.Context.Containers) {
            $serviceName = "$($this.Context.WorkloadName)-$container"
            $projectDirectory = $this.Context.SourceWorkloadPath
            $command = $this.BuildLaunchSettingsCommand($serviceName, $projectDirectory)
            $this.Context.SharedState.commands += $command
        }
    }

    hidden [string] BuildLaunchSettingsCommand([string]$serviceName, [string]$projectDirectory) {
        $modulePath = Join-Path -Path $this.Context.ParentPath -ChildPath ".score-compose\framework\LaunchSettings.psm1"
        $composePath = $this.Context.ComposePath
        
        $command = "using module '.score-compose\framework\LaunchSettings.psm1';" +
                   "[LaunchSettings]::new('$composePath').ApplyEnvironmentToLaunchProfile('$serviceName', '$projectDirectory')"
        
        return $command
    }
}