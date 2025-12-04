using module './ProvisionerBase.psm1'
using module './Context.psm1'
using module './NetFrameworkExternalProvisioner.psm1'
using module './NetFrameworkInternalProvisioner.psm1'
using module './NetCoreExternalProvisioner.psm1'
using module './NetCoreInternalProvisioner.psm1'

class FrameworkProvisionerFactory {
    static [ProvisionerBase] Create([Context]$context) {
        if (-not $context) {
            return $null
        }
        $framework = $context.Framework
        $isChildProject = $context.IsChildProject
        if ([string]::Equals($framework, "net", [System.StringComparison]::OrdinalIgnoreCase)) {
            if ([string]::Equals($applicationType, "external", [System.StringComparison]::OrdinalIgnoreCase)) {
                return [NetFrameworkExternalProvisioner]::new($context)
            }
            return [NetFrameworkInternalProvisioner]::new($context)
        }
        if ([string]::Equals($applicationType, "external", [System.StringComparison]::OrdinalIgnoreCase)) {
            return [NetCoreExternalProvisioner]::new($context)
        }
        return [NetCoreInternalProvisioner]::new($context)
    }
}