using module './Context.psm1'

class DockerProject {
    [Context]$Context
    [string]$TemplatesPath
    [string]$FrameworkTemplatesPath
    [hashtable]$Paths

    DockerProject([Context]$context) {
        $this.Context = $context
        $this.TemplatesPath = Join-Path -Path $context.ParentPath -ChildPath ".score-compose/framework/templates/dcproj template"
        $this.FrameworkTemplatesPath = Join-Path -Path $context.ParentPath -ChildPath ".score-compose/framework/templates"
    }

    [void] EnsureDockerComposeProject() {
        if (-not $this.ShouldCreateProject()) {
            return
        }
        $this.Paths = $this.GetDockerProjectPaths()
        $init = $this.InitializeDockerProjectDirectory($this.Paths)
        $this.CopyDockerProjectTemplates($this.Paths)
        $this.UpdateDockerProjectFiles($this.Paths, $init.ProjectGuid)
        if ($init.IsNew) {
            write-host "Registering project in solution"
            $this.RegisterProjectInSolution($this.Paths, $init.ProjectGuid)
        }
    }

    hidden [bool] ShouldCreateProject() {
        if ($this.Context.IsChildProject) {
            return $false
        }
        return $true
    }

    hidden [string] ResolveDockerComposePath() {
        return Join-Path -Path $this.Context.SourceWorkloadPath -ChildPath "docker-compose.yaml"
    }

    hidden [string] GetServiceLabel() {
        $label = $this.Context.WorkloadName
        if ($this.Context.Containers -and $this.Context.Containers.Count -gt 0) {
            $firstContainer = [string]$this.Context.Containers[0]
            $label = "$label-$firstContainer"
        }
        return $label
    }

    hidden [hashtable] GetDockerProjectPaths() {
        $result = [ordered]@{}
        $dcprojName = $this.Context.WorkloadName
        $projectFileName = "$dcprojName.dcproj"
        $projectRelDir = Join-Path -Path "docker" -ChildPath $dcprojName
        $targetDir = Join-Path -Path $this.Context.SolutionRoot -ChildPath $projectRelDir
        $result["ProjectRelDir"] = $projectRelDir
        $result["TargetDir"] = $targetDir
        $result["ProjectRelPath"] = Join-Path -Path $projectRelDir -ChildPath $projectFileName
        return $result
    }

    hidden [hashtable] InitializeDockerProjectDirectory([hashtable]$paths) {
        $result = @{
            ProjectGuid = ([guid]::NewGuid()).ToString()
            IsNew = $true
        }
        $targetDir = $paths["TargetDir"]
        $projectFile = Join-Path -Path $targetDir -ChildPath "$($this.Context.WorkloadName).dcproj"
        if (Test-Path -LiteralPath $targetDir) {
            $existing = $null
            if (Test-Path -LiteralPath $projectFile) {
                $existing = Get-Content -Path $projectFile -Raw -ErrorAction SilentlyContinue
            }
            if ($existing -and $existing -match '<ProjectGuid>(.*?)</ProjectGuid>') {
                $result.ProjectGuid = $matches[1]
            }
            Remove-Item -Path $targetDir -Recurse -Force
            $result.IsNew = $false
        }
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        return $result
    }

    hidden [void] CopyDockerProjectTemplates([hashtable]$paths) {
        $targetDir = $paths["TargetDir"]
        $this.CopyTemplateFile("projectname.dcproj", (Join-Path -Path $targetDir -ChildPath $paths["ProjectFileName"]))
        $this.CopyTemplateFile("launchSettings.json", (Join-Path -Path $targetDir -ChildPath "launchSettings.json"))
        $this.CopyTemplateFile("docker-compose.vs.debug.yml", (Join-Path -Path $targetDir -ChildPath "docker-compose.vs.debug.yml"))
        $this.CopyTemplateFile("entrypoint.sh", (Join-Path -Path $targetDir -ChildPath "entrypoint.sh"))
        $dockerIgnore = Join-Path -Path $targetDir -ChildPath ".dockerignore"
        $this.CopyTemplateFile(".dockerignore", $dockerIgnore)
        Set-NormalizedLineEndings -Path $dockerIgnore -LineEnding "CRLF"
    }

    hidden [void] CopyTemplateFile([string]$fileName, [string]$destination) {
        $sourcePath = Join-Path -Path $this.TemplatesPath -ChildPath $fileName
        if (Test-Path -LiteralPath $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destination -Force
        } else {
            throw "Template file not found: $sourcePath"
        }
    }

    hidden [void] UpdateDockerProjectFiles([hashtable]$paths, [string]$projectGuid) {
        $targetDir = $paths["TargetDir"]
        $projectFile = Join-Path -Path $targetDir -ChildPath $paths["ProjectFileName"]
        $this.UpdateProjectFile($projectFile, $projectGuid)
        $this.UpdateDockerIgnore($targetDir)
        $this.UpdateLaunchSettingsFile($targetDir)
    }

    hidden [void] UpdateProjectFile([string]$projectFile, [string]$projectGuid) {
        if (-not (Test-Path -LiteralPath $projectFile)) {
            return
        }
        $content = Get-Content -Path $projectFile -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            return
        }
        $dockerComposePath = $this.ResolveDockerComposePath()
        if ($dockerComposePath) {
            $normalizedPath = $dockerComposePath.Replace('\', '/')
            $content = $content.Replace('__PATH_TO_GENERATED_DOCKER_COMPOSE__', $normalizedPath)
        }
        $content = $content.Replace('docker-compose.vs.debug.yaml', 'docker-compose.vs.debug.yml')
        $content = [regex]::Replace($content, '<ProjectGuid>\s*__PROJECT_GUID__\?\s*</ProjectGuid>', "<ProjectGuid>$projectGuid</ProjectGuid>")
        Set-Content -Path $projectFile -Value $content -Encoding UTF8
        Set-NormalizedLineEndings -Path $projectFile -LineEnding "CRLF"
    }

    hidden [void] UpdateDockerIgnore([string]$targetDir) {
        $dockerIgnore = Join-Path -Path $targetDir -ChildPath ".dockerignore"
        if (Test-Path -LiteralPath $dockerIgnore) {
            Set-NormalizedLineEndings -Path $dockerIgnore -LineEnding "CRLF"
        }
    }

    hidden [void] UpdateLaunchSettingsFile([string]$targetDir) {
        $launchSettingsFile = Join-Path -Path $targetDir -ChildPath "launchSettings.json"
        if (-not (Test-Path -LiteralPath $launchSettingsFile)) {
            return
        }
        $launchContent = Get-Content -Path $launchSettingsFile -Raw
        if ([string]::IsNullOrWhiteSpace($launchContent)) {
            return
        }
        $dockerComposePath = $this.ResolveDockerComposePath()
        if ($dockerComposePath) {
            $launchContent = $launchContent.Replace('__PATH_TO_GENERATED_DOCKER_COMPOSE__', $dockerComposePath.Replace('\', '/'))
        }
        $launchContent = $launchContent.Replace('__SERVICE_NAME__', $this.GetServiceLabel())
        Set-Content -Path $launchSettingsFile -Value $launchContent -Encoding UTF8
        Set-NormalizedLineEndings -Path $launchSettingsFile -LineEnding "CRLF"
    }

    hidden [void] RegisterProjectInSolution([hashtable]$paths, [string]$projectGuid) {
        $slnFile = $this.GetSolutionFile()
        if (-not $slnFile) {
            return
        }
        $slnLines = Get-Content -Path $slnFile.FullName -Encoding UTF8
        $slnLines = $this.InsertProjectBlock($slnLines, $projectGuid, $paths["ProjectRelPath"])
        $slnLines = $this.InsertProjectConfigurations($slnLines, $projectGuid)
        Set-Content -Path $slnFile.FullName -Value ($slnLines -join "`r`n") -Encoding UTF8
    }

    hidden [System.IO.FileInfo] GetSolutionFile() {
        if ([string]::IsNullOrWhiteSpace($this.Context.SolutionRoot)) {
            return $null
        }
        return Get-ChildItem -Path $this.Context.SolutionRoot -Filter "*.sln" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    hidden [string[]] InsertProjectBlock([string[]]$slnLines, [string]$projectGuid, [string]$projectRelPath) {
        $lines = if ($slnLines) { $slnLines } else { @() }
        $projectTypeGuid = "{E53339B2-1760-4266-BCC7-CA923CBCF16C}"
        $projGuidBraced = "{" + ($projectGuid.ToUpper()) + "}"
        $projectName = if ([string]::IsNullOrWhiteSpace($this.WorkloadName)) { "DockerProject" } else { $this.WorkloadName }
        $projectBlock = @(
            "Project(`"$projectTypeGuid`") = `"$projectName`", `"$projectRelPath`", `"$projGuidBraced`"",
            "EndProject"
        )
        $globalIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq 'Global') {
                $globalIndex = $i
                break
            }
        }
        if ($globalIndex -gt 0) {
            return $lines[0..($globalIndex-1)] + $projectBlock + $lines[$globalIndex..($lines.Count-1)]
        }
        return $projectBlock + $lines
    }

    hidden [string[]] InsertProjectConfigurations([string[]]$slnLines, [string]$projectGuid) {
        $projGuidBraced = "{" + ($projectGuid.ToUpper()) + "}"
        $cfgLines = $this.CreateConfigurationLines($projGuidBraced)
        $section = $this.GetConfigurationSectionBounds($slnLines)
        if ($section.Start -ne -1 -and $section.End -ne -1) {
            $before = $slnLines[0..($section.End-1)]
            $after = $slnLines[$section.End..($slnLines.Count-1)]
            return $before + $cfgLines + $after
        }
        return $this.AppendConfigurationSection($slnLines, $cfgLines)
    }

    hidden [hashtable] GetConfigurationSectionBounds([string[]]$lines) {
        $start = -1
        $end = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($start -eq -1 -and ($lines[$i] -match '^\s*GlobalSection\(ProjectConfigurationPlatforms\)')) {
                $start = $i
                continue
            }
            if ($start -ne -1 -and ($lines[$i] -match '^\s*EndGlobalSection')) {
                $end = $i
                break
            }
        }
        return @{ Start = $start; End = $end }
    }

    hidden [string[]] AppendConfigurationSection([string[]]$lines, [string[]]$cfgLines) {
        $globalEndIdx = -1
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -eq 'EndGlobal') {
                $globalEndIdx = $i
                break
            }
        }
        $newSection = @("`tGlobalSection(ProjectConfigurationPlatforms) = postSolution") + $cfgLines + @("`tEndGlobalSection")
        if ($globalEndIdx -gt 0) {
            return $lines[0..($globalEndIdx-1)] + $newSection + $lines[$globalEndIdx..($lines.Count-1)]
        }
        return $lines + @('Global') + $newSection + @('EndGlobal')
    }

    hidden [string[]] CreateConfigurationLines([string]$projGuidBraced) {
        return @(
            "`t`t$projGuidBraced.Debug|Any CPU.ActiveCfg = Debug|Any CPU",
            "`t`t$projGuidBraced.Debug|Any CPU.Build.0 = Debug|Any CPU",
            "`t`t$projGuidBraced.NoVariablesDefault|Any CPU.ActiveCfg = NoVariablesDefault",
            "`t`t$projGuidBraced.NoVariablesDefault|Any CPU.Build.0 = NoVariablesDefault",
            "`t`t$projGuidBraced.Release|Any CPU.ActiveCfg = Release|Any CPU",
            "`t`t$projGuidBraced.Release|Any CPU.Build.0 = Release|Any CPU"
        )
    }

    [void] UpdateComposeDebugFile([string] $templateName) {
        $composeServiceTemplate = Join-Path -Path $this.FrameworkTemplatesPath -ChildPath $templateName
        $composeDebugFile = Join-Path -Path $this.Paths["TargetDir"] -ChildPath "docker-compose.vs.debug.yml"

        $composeContent = Get-Content -Path $composeDebugFile -Raw
        
        if ([string]::IsNullOrWhiteSpace($composeContent)) {
            throw "composeContent is null or empty"
        }
        foreach ($container in $this.Context.Containers) {
            $composeServiceTemplateContent = Get-Content -Path $composeServiceTemplate -Raw
            $composeServiceTemplateContent = $composeServiceTemplateContent.Replace('{{WORKLOAD_NAME}}', $this.Context.WorkloadName)
            $composeServiceTemplateContent = $composeServiceTemplateContent.Replace('{{CONTAINER}}', $container)
            $composeServiceTemplateContent = $composeServiceTemplateContent.Replace('{{ABSOLUTE_PATH_TO_ENTRYPOINT_SH}}', $this.Context.targetDir)
            $composeContent = $composeContent + $composeServiceTemplateContent
            $composeContent = $composeContent.Replace('{{COMPOSE_PROJECT_NAME}}', $this.Context.WorkloadName)
        }
        Set-Content -Path $composeDebugFile -Value $composeContent -Encoding UTF8
        Set-NormalizedLineEndings -Path $composeDebugFile -LineEnding "CRLF"
    }
}