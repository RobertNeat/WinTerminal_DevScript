Import-Module ".\modules\Utils\Initialize-NoteProperty.psm1"

# Disables the specified Windows Terminal dynamic profile sources.
# [input-param] ProfileSourcesToDisable: list of profile source identifiers to write into disabledProfileSources
# [input-param] SettingsObject: object from Get-TerminalConfiguration or parsed settings.json
# [output-param] object: the same SettingsObject after modification
# [side-effect] Modifies the disabledProfileSources property in memory, merging values without duplicates.
function Disable-TerminalDynamicProfiles {
    [CmdletBinding()]
    param(
        # input: list of profile sources to disable (e.g., Windows.Terminal.Azure, Windows.Terminal.SSH)
        [Parameter(Mandatory = $true)]
        [Alias('ProfileSourceToDisable')]
        [string[]] $ProfileSourcesToDisable,

        # input: configuration object returned by Get-TerminalConfiguration (has .Settings), OR
        # the parsed settings.json object returned by ConvertFrom-Json.
        [Parameter(Mandatory = $true)]
        [object] $SettingsObject
        # output: modified SettingsObject (same object instance) with updated "disabledProfileSources" entry
    )

    if (-not $SettingsObject) { throw 'SettingsObject is null (cannot disable automatic profile generation).' }

    # Operate on Settings property when the wrapper is passed.
    $settingsJson = $SettingsObject
    if ($SettingsObject -and ($SettingsObject.PSObject.Properties.Name -contains 'Settings') -and $SettingsObject.Settings) {
        $settingsJson = $SettingsObject.Settings
    }
    if (-not $settingsJson) { throw 'SettingsObject.Settings is null (cannot disable automatic profile generation).' }

    # Some exports wrap the real WT schema in a nested .settings object; support both.
    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    Initialize-NoteProperty -Object $settingsRoot -Name 'disabledProfileSources' -DefaultValue @()

    $existingList = @($settingsRoot.disabledProfileSources)

    # Build a de-duplicated list (case-insensitive) and append requested sources.
    $merged = New-Object System.Collections.ArrayList
    foreach ($src in $existingList) {
        $s = if ($null -eq $src) { $null } else { ([string]$src).Trim() }
        if ([string]::IsNullOrWhiteSpace($s)) { continue }

        $already = $false
        foreach ($e in $merged) {
            if ([string]$e -ieq $s) { $already = $true; break }
        }
        if (-not $already) { [void]$merged.Add($s) }
    }

    foreach ($src in $ProfileSourcesToDisable) {
        $s = if ($null -eq $src) { $null } else { ([string]$src).Trim() }
        if ([string]::IsNullOrWhiteSpace($s)) { continue }

        $already = $false
        foreach ($e in $merged) {
            if ([string]$e -ieq $s) { $already = $true; break }
        }
        if (-not $already) { [void]$merged.Add($s) }
    }

    $settingsRoot.disabledProfileSources = @($merged)
    return $SettingsObject
}

Export-ModuleMember -Function Disable-TerminalDynamicProfiles
