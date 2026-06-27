
# [add]: "tabWidthMode": "titleLength",
# [add]: "searchWebDefaultQueryUrl": "https://www.google.com/search?q=%22%s%22",
function Add-TerminalSettings {
    param(
        [PSCustomObject] $Configuration,
        [hashtable] $ParamsMap  # key-value map to add to global object settings
    )
    if (-not $Configuration) { throw 'Configuration is required.' }

    # Determine settings root (support wrapper objects with .Settings or nested .settings)
    $settingsJson = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings') -and $Configuration.Settings) {
        $settingsJson = $Configuration.Settings
    }
    if (-not $settingsJson) { throw 'Configuration.Settings is null (cannot add additional settings).' }

    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    if (-not $ParamsMap) { return $Configuration }

    foreach ($k in $ParamsMap.Keys) {
        $val = $ParamsMap[$k]

        # If property exists but is $null, set it. If it exists and not $null, override (per request).
        if ($settingsRoot.PSObject.Properties.Name -contains $k) {
            try {
                $settingsRoot.$k = $val
            } catch {
                # fallback to Add-Member -Force when direct assignment fails
                $settingsRoot | Add-Member -MemberType NoteProperty -Name $k -Value $val -Force
            }
        } else {
            $settingsRoot | Add-Member -MemberType NoteProperty -Name $k -Value $val -Force
        }
    }

    return $Configuration
}

Export-ModuleMember -Function Add-TerminalSettings