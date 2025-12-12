Set-StrictMode -Version Latest

class Context {
    [string]$Framework
    [string]$Version
    [string]$WorkloadName
    [hashtable]$SharedState
    [string]$SourceWorkloadPath
    [string]$ParentPath
    [string]$SolutionRoot
    [string[]]$Containers
    [bool]$IsChildProject
    [hashtable]$Data

    [string]$ComposePath

    Context(
        [hashtable]$data
    ) {
        $this.Framework = $data.resource_params.framework
        $this.Version = $data.resource_params.version
        $this.WorkloadName = $data.source_workload
        $this.SharedState = Initialize-SharedState -data $data
        $this.ParentPath = $PWD.Path
        $this.SourceWorkloadPath = $data.shared_state.childrenPaths[$this.WorkloadName] ?? $this.ParentPath
        $this.SolutionRoot = Find-ProjectRoot -startPath $this.ParentPath
        $this.Containers = Get-Containers -data $data
        $this.IsChildProject = $this.SourceWorkloadPath -ne $this.ParentPath
        $this.Data = $data
        
        $this.ComposePath = Join-Path -Path $this.ParentPath -ChildPath "docker-compose.yaml"

        $netFrameworkVersions = @("45", "451", "452", "46", "461", "462", "47", "471", "472", "48", "481")

        if ($this.Framework -eq "net") {
            if($this.Version -and ($netFrameworkVersions -contains $this.Version)) {
                $this.Framework = "netframework"
            } else {
                $this.Framework = "netcore"
            }
        }
    }

    [hashtable] ToHashtable() {
        return [ordered]@{
            Framework = $this.Framework
            Version = $this.Version
            WorkloadName = $this.WorkloadName
            SharedState = $this.SharedState
            SourceWorkloadPath = $this.SourceWorkloadPath
            ParentPath = $this.ParentPath
            SolutionRoot = $this.SolutionRoot
            Containers = $this.Containers
            IsChildProject = $this.IsChildProject
            Data = $this.Data
            ComposePath = $this.ComposePath
        }
    }
}
