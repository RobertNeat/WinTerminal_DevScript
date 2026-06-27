Import-Module ".\modules\Terminal.Configuration\Get-TerminalSettingsPath.psm1"

Import-Module ".\modules\_Tests\Test-TerminalMinimumVersion.psm1"
Import-Module ".\modules\_Tests\Test-TerminalConfigurationSerialization.psm1"


# Get Windows Terminal configuration from settings.json
# [input-param] SettingsPath: resolved path to settings.json
# [output-param] TerminalVersion: detected WT version string
# [output-param] JsonDepth: the depth used for ConvertTo-Json (PowerShell 5’s max is 100)
# [output-param] Settings: the actual parsed JSON as a nested PSCustomObject tree — this is what you should edit
function Get-TerminalConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 100)]
        [int] $JsonDepth = 100,

        [Parameter(Mandatory = $false)]
        [switch] $SkipRoundTripValidation
    )

    $resolvedPath = Get-TerminalSettingsPath -SettingsPath $SettingsPath

    $terminalVersion = Test-TerminalMinimumVersion -MinimumVersion ([version]'1.24')

    try {
        $rawJson = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        throw "Failed to read Windows Terminal settings.json at '$resolvedPath'. $($_.Exception.Message)"
    }

    try {
        $settingsObject = ConvertFrom-Json -InputObject $rawJson -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$resolvedPath'. $($_.Exception.Message)"
    }

    $configuration = [pscustomobject]@{
        PSTypeName      = 'WindowsTerminal.Configuration'
        SettingsPath    = $resolvedPath
        TerminalVersion = $terminalVersion.ToString()
        JsonDepth       = $JsonDepth
        Settings        = $settingsObject
    }

    if (-not $SkipRoundTripValidation) {
        $ok = Test-TerminalConfigurationSerialization -Configuration $configuration -SettingsPath $resolvedPath -JsonDepth $JsonDepth
        if (-not $ok) {
            throw "Round-trip JSON validation failed for '$resolvedPath'. The parsed object cannot be serialized back to an equivalent settings.json structure."
        }
    }

    return $configuration
}

Export-ModuleMember -Function Get-TerminalConfiguration