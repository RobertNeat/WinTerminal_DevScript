
# Saves the modified Windows Terminal configuration to settings.json.
# [input-param] Configuration: configuration object or wrapper containing the Settings property
# [input-param] SettingsPath: optional target settings.json path; when empty, it is detected automatically
# [output-param] PSCustomObject: the same Configuration object that was passed to the function
# [side-effect] Overwrites settings.json and creates and removes a temporary JSON file.
function Save-TerminalConfiguration {
    param(
        [PSCustomObject] $Configuration,
        [string] $SettingsPath
    )
    if (-not $Configuration) { throw 'Configuration is required.' }

    # Resolve settings path if not provided
    if ([string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath = Get-TerminalSettingsPath }
    if (-not $SettingsPath) { throw 'SettingsPath could not be resolved.' }

    # Prepare object for serialization. Some functions pass a wrapper with .Settings
    $toSerialize = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings') -and $Configuration.Settings) {
        $toSerialize = $Configuration.Settings
    }

    # If there is an inner .settings property (some exports wrap twice), keep that shape
    if ($toSerialize -and ($toSerialize.PSObject.Properties.Name -contains 'settings') -and $toSerialize.settings) {
        # keep as-is (already nested)
    }

    # Choose a safe depth for ConvertTo-Json (PowerShell 5 has limits). Prefer 100 when available.
    $depth = 100
    try { $json = $toSerialize | ConvertTo-Json -Depth $depth -ErrorAction Stop } catch {
        # fallback: try larger depth if ConvertTo-Json failed due to depth
        $depth = 100
        $json = $toSerialize | ConvertTo-Json -Depth $depth
    }

    # Write JSON back to file with UTF8 encoding (no BOM to match typical WT file). Use -Force to overwrite.
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $json | Out-File -LiteralPath $tmp -Encoding utf8 -Force
        # Replace original atomically when possible
        Copy-Item -LiteralPath $tmp -Destination $SettingsPath -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    return $Configuration
}


Export-ModuleMember -Function Save-TerminalConfiguration
