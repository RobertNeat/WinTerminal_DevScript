Import-Module ".\modules\terminal.configuration\Get-TerminalSettingsPath.psm1"
Import-Module ".\modules\_Tests\Test-ObjectEqualityDeep.psm1"

# Checks whether the Windows Terminal configuration survives JSON serialization without losing structure.
# [input-param] Configuration: configuration object or wrapper containing Settings and optionally SettingsPath
# [input-param] SettingsPath: optional path to the original settings.json
# [input-param] JsonDepth: depth used by ConvertTo-Json and recursive comparison
# [output-param] bool: true when the object after JSON round-trip is equal to the original settings.json
# [side-effect] Reads the original settings.json file from disk.
function Test-TerminalConfigurationSerialization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Configuration,

        [Parameter(Mandatory = $false)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 100)]
        [int] $JsonDepth = 100
    )

    if (-not $SettingsPath) {
        if ($Configuration -and $Configuration.PSObject.Properties.Name -contains 'SettingsPath') {
            $SettingsPath = [string]$Configuration.SettingsPath
        }
    }

    if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        throw "SettingsPath is required (either pass -SettingsPath or provide a Configuration with SettingsPath)."
    }

    $resolvedPath = Get-TerminalSettingsPath -SettingsPath $SettingsPath

    $originalJson = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    $originalObj = ConvertFrom-Json -InputObject $originalJson

    $settingsToSerialize = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings')) {
        $settingsToSerialize = $Configuration.Settings
    }

    $roundTripJson = $settingsToSerialize | ConvertTo-Json -Depth $JsonDepth -Compress
    $roundTripObj = ConvertFrom-Json -InputObject $roundTripJson

    return (Test-ObjectEqualityDeep -Left $originalObj -Right $roundTripObj -MaxDepth $JsonDepth)
}

Export-ModuleMember -Function Test-TerminalConfigurationSerialization
