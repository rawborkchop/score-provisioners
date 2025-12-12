using module './Context.psm1'
using module './ProvisionerBase.psm1'

class NetFrameworkInternalProvisioner : ProvisionerBase {
    NetFrameworkInternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() { 
        ([ProvisionerBase]$this).Execute()
        $this.DockerProject.UpdateComposeDebugFile("NetFramework_compose_override.yaml")
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
        $modulePath = Join-Path -Path $this.Context.ParentPath -ChildPath ".score-compose\framework\LaunchSettings.psm1"
        $composePath = $this.Context.ComposePath
        
        $command = "Import-Module '$modulePath' -Force; " +
                   "Invoke-LaunchSettingsUpdate -ComposePath '$composePath' -ServiceName '$serviceName' -ProjectDirectory '$projectDirectory'"
        
        return $command
    }

    hidden [void] RegisterSharedCommand([string]$command) {
        if (-not $this.Context.SharedState.ContainsKey("commands")) {
            $this.Context.SharedState["commands"] = @()
        }
        $this.Context.SharedState["commands"] += $command
    }
}
