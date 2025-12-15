using module './ProvisionerBase.psm1'
using module './Context.psm1'
using module './NetFrameworkExternalProvisioner.psm1'
using module './NetFrameworkInternalProvisioner.psm1'
using module './NetCoreExternalProvisioner.psm1'
using module './NetCoreInternalProvisioner.psm1'

class FrameworkProvisionerFactory {
    static [ProvisionerBase] Create([Context]$context) {
        $framework = $context.Framework
        $isExternal = $context.IsExternal
        if ([string]::Equals($framework, "netframework", [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($isExternal) {
                return [NetFrameworkExternalProvisioner]::new($context)
            }
            return [NetFrameworkInternalProvisioner]::new($context)
        }
        if ([string]::Equals($framework, "netcore", [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($isExternal) {
                return [NetCoreExternalProvisioner]::new($context)
            }
            return [NetCoreInternalProvisioner]::new($context)
        }
        return $null
    }
}