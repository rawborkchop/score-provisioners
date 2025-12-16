using module './Context.psm1'
using module './ProvisionerBase.psm1'
using module './PostRunCommandManager.psm1'

class NetFrameworkInternalProvisioner : ProvisionerBase {
    NetFrameworkInternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() { 
        ([ProvisionerBase]$this).Execute()
        $postRunCommandManager = [PostRunCommandManager]::new($this.Context)
        $postRunCommandManager.OverrideIdleComposeServices()
        $postRunCommandManager.RegisterLaunchSettingsCommands()
    }

    hidden [void] UpdateComposeDebugFile() {
        $this.DockerProject.UpdateComposeDebugFile("NetFramework_compose_override.yaml")
    }
}