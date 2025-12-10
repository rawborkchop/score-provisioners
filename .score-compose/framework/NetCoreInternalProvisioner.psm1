using module './ProvisionerBase.psm1'
using module './Context.psm1'
using module './Dockerfile_.psm1'

class NetCoreInternalProvisioner : ProvisionerBase {
    NetCoreInternalProvisioner([Context]$context) : base($context) {}

    [void] Execute() {
        [ProvisionerBase]::Execute()
        $dockerfile = new Dockerfile($this.Context.ParentPath,
            $this.Context.SourceWorkloadPath,
            $this.Context.Version,
            "netcore_internal.Dockerfile")
        $dockerfile.SetDockerfile()
        $this.DockerProject.UpdateComposeDebugFile("NetCoreInternal_compose_override.yaml")
    }
}