using module './Context.psm1'
using module './ProvisionerBase.psm1'

class NetFrameworkInternalProvisioner : ProvisionerBase {
    NetFrameworkInternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() { 
        $this.DockerProject.EnsureDockerComposeProject()
        $this.RegisterLaunchSettingsCommands()
    }

    hidden [void] RegisterLaunchSettingsCommands() {
        if (-not $this.Context.Containers -or $this.Context.Containers.Count -eq 0) {
            return
        }
        foreach ($container in $this.Context.Containers) {
            $serviceName = "$($this.Context.WorkloadName)-$container"
            $projectDirectory = $this.Context.SourceWorkloadPath
            $command = $this.BuildLaunchSettingsCommand($serviceName, $projectDirectory)
            $this.RegisterSharedCommand($command)
        }
    }

    hidden [string] BuildLaunchSettingsCommand([string]$serviceName, [string]$projectDirectory) {
        $scriptPath = Join-Path -Path $this.Context.ParentPath -ChildPath ".score-compose\launchsettings.ps1"
        return "$scriptPath -ServiceName `"$serviceName`" -ProjectDirectory `"$projectDirectory`""
    }

    hidden [void] RegisterSharedCommand([string]$command) {
        if (-not $this.Context.SharedState.ContainsKey("commands")) {
            $this.Context.SharedState["commands"] = @()
        }
        $this.Context.SharedState["commands"] += $command
    }
}
