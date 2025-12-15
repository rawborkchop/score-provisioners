using module './ProvisionerBase.psm1'
using module './Context.psm1'
using module './Dockerfile_.psm1'

class NetCoreInternalProvisioner : ProvisionerBase {
    NetCoreInternalProvisioner([Context]$context) : base($context) {}

    [void] Execute() {
        ([ProvisionerBase]$this).Execute()
        $dockerfile = [Dockerfile]::new($this.Context.ParentPath,
            $this.Context.SourceWorkloadPath,
            $this.Context.Version,
            "NetCore_internal.Dockerfile")
        $dockerfile.SetDockerfile()
    }

    hidden [void] UpdateComposeDebugFile() {
        $this.DockerProject.UpdateComposeDebugFile("NetCore_compose_override.yaml")
    }
}