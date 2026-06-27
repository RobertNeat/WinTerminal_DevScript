Import-Module ".\modules\Terminal.Configuration\Get-TerminalVersion.psm1"

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