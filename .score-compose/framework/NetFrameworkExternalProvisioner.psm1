using module './ProvisionerBase.psm1'
using module './Context.psm1'

class NetFrameworkExternalProvisioner : ProvisionerBase {
    [string]$HostingModel
    [string]$EntryPoint

    NetFrameworkExternalProvisioner([Context]$context) : base($context) {
        $this.HostingModel = $context.Data.hostingModel
        $this.EntryPoint = $context.Data.entryPoint
    }

    [void] Execute() {
        $this.DockerProject.EnsureDockerComposeProject()
        $this.RegisterLauncherCommandsForContainers()
    }

    hidden [void] RegisterLauncherCommandsForContainers() {
        if (-not $this.Context.Containers -or $this.Context.Containers.Count -eq 0) {
            return
        }
        foreach ($container in $this.Context.Containers) {
            $this.RegisterLauncherCommand($container)
        }
    }

    hidden [void] RegisterLauncherCommand([string]$container) {
        $serviceName = $this.GetServiceName($container)
        $mode = $this.ResolveMode()
        $launcherCommand = ".\netfx_external_launcher.ps1 -Mode $mode -ServiceName `"$serviceName`""
        if (-not [string]::IsNullOrWhiteSpace($this.EntryPoint)) {
            $launcherCommand += " -ExecutablePath `"$($this.EntryPoint)`""
        }
        $this.RegisterSharedCommand($launcherCommand)
    }

    hidden [string] GetServiceName([string]$container) {
        $workloadName = $this.Context.WorkloadName
        if ([string]::IsNullOrWhiteSpace($container)) {
            return $workloadName
        }
        return "$workloadName-$container"
    }

    hidden [string] ResolveMode() {
        if ([string]::IsNullOrWhiteSpace($this.HostingModel)) {
            return "exe"
        }
        return $this.HostingModel
    }

    hidden [void] RegisterSharedCommand([string]$command) {
        if (-not $this.Context.SharedState.ContainsKey("commands")) {
            $this.Context.SharedState["commands"] = @()
        }
        $this.Context.SharedState["commands"] += $command
    }
}
