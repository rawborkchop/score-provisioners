using module './ProvisionerBase.psm1'
using module './Context.psm1'

class NetFrameworkExternalProvisioner : ProvisionerBase {
    NetFrameworkExternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() {
        foreach ($container in $this.Containers) {
            $this.RegisterIdleComposeService($container)
        }
    }

    hidden [void] RegisterIdleComposeService([string]$container) {
        $launcherCommand = ".\netfx_external_launcher.ps1 -Mode $((if ([string]::IsNullOrWhiteSpace($this.HostingModel)) { 'exe' } else { $this.HostingModel }))"
        if (-not [string]::IsNullOrWhiteSpace($this.EntryPoint)) {
            $launcherCommand += " -ExecutablePath `"$($this.EntryPoint)`""
        }
        $this.RegisterSharedCommand($launcherCommand)
    }
}