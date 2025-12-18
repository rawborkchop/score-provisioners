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
        $this.CreateInitFile()
    }
    
    hidden [void] UpdateComposeDebugFile() {
        $this.DockerProject.UpdateComposeDebugFile("NetCore_compose_external_override.yaml")
    }

    hidden [void] CreateInitFile() {
        $initFile = Join-Path -Path '.score-compose\framework\templates' -ChildPath 'NetCore_external_init.sh'
        $content = Get-Content -Path $initFile -Raw

        $depsFiles = Get-ChildItem -Path $this.Context.SourceWorkloadPath -Filter "*.deps.json" -File
        if ($depsFiles.Count -eq 1) {
            $dllName = [System.IO.Path]::GetFileNameWithoutExtension($depsFiles[0].Name)
        } elseif ($depsFiles.Count -gt 1) {
            $dllName = [System.IO.Path]::GetFileNameWithoutExtension($depsFiles[0].Name)
        } else {
            throw "No .deps.json file found in $($this.Context.SourceWorkloadPath)"
        }
        $content = $content.Replace('{{DLL_NAME}}', $dllName)
        targetFile = Join-Path -Path $this.Context.SourceWorkloadPath -ChildPath "NetCore_external_init.sh"
        Set-Content -Path $initFile -Value $content -Encoding UTF8
    }
}