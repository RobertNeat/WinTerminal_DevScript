Import-Module ".\modules\terminal.configuration\Get-TerminalSettingsPath.psm1"
Import-Module ".\modules\_Tests\Test-ObjectEqualityDeep.psm1"

# Test the serialization and deserialization of the configuration object to ensure that it can be round-tripped through JSON without losing information or structure. 
# This is important because the configuration is loaded from JSON, manipulated as a PowerShell object, and then serialized back to JSON when saving.
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