using module './ProvisionerBase.psm1'
using module './Context.psm1'
using module './Dockerfile_.psm1'

class NetCoreExternalProvisioner : ProvisionerBase {
    NetCoreExternalProvisioner([Context]$context) : base($context) { }

    [void] Execute() {
        [ProvisionerBase]::Execute()
        $dockerfile = [Dockerfile]::new($this.Context.ParentPath, 
            $this.Context.SourceWorkloadPath, 
            $this.Context.Version, 
            "NetCore_external.Dockerfile")
        $dockerfile.SetDockerfile()
    }
    hidden [void] UpdateComposeDebugFile() {
        $this.DockerProject.UpdateComposeDebugFile("NetCore_compose_external_override.yaml")
    }
}