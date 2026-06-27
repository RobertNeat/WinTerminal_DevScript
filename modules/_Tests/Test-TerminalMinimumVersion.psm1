Import-Module ".\modules\Terminal.Configuration\Get-TerminalVersion.psm1" -ErrorAction Stop

# Checks whether the installed Windows Terminal meets the minimum version.
# [input-param] MinimumVersion: minimum required Windows Terminal version
# [output-param] version: detected Windows Terminal version when it is high enough
# [side-effect] Reads the Windows Terminal version and throws an exception when it is too old.
function Test-TerminalMinimumVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version] $MinimumVersion
    )

    $installed = Get-TerminalVersion
    if ($installed -lt $MinimumVersion) {
        throw "Windows Terminal version '$installed' is below the required minimum '$MinimumVersion'."
    }

    return $installed
}

Export-ModuleMember -Function Test-TerminalMinimumVersion
