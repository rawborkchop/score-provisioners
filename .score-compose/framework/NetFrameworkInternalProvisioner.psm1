using module './Context.psm1'
using module './ProvisionerBase.psm1'

class NetFrameworkInternalProvisioner : ProvisionerBase {
    NetFrameworkInternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() { 
        $this.OverrideIdleComposeServices
        $launchSettings = new LaunchSettings($this.Context)
        $launchSettings.EnsureLaunchProfile()
    }
}
