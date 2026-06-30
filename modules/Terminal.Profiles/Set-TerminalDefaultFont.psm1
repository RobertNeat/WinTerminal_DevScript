Import-Module ".\modules\Utils\Initialize-NoteProperty.psm1" -ErrorAction Stop

# Sets the default font face for Windows Terminal profiles.
# [input-param] Configuration: configuration object or wrapper containing Settings and TerminalVersion
# [input-param] FontFace: Windows Terminal font face name to write under profiles.defaults.font.face
# [output-param] PSCustomObject: the same Configuration object after modification
# [side-effect] Modifies profiles.defaults.font.face in memory.
function Set-TerminalDefaultFont {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Configuration,

        [string] $FontFace = 'FiraCode Nerd Font'
    )

    if (-not $Configuration) { throw 'Configuration is required.' }

    $settingsJson = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings') -and $Configuration.Settings) {
        $settingsJson = $Configuration.Settings
    }
    if (-not $settingsJson) { throw 'Configuration.Settings is null (cannot set terminal default font).' }

    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    Initialize-NoteProperty -Object $settingsRoot -Name 'profiles' -DefaultValue ([pscustomobject]@{})
    Initialize-NoteProperty -Object $settingsRoot.profiles -Name 'defaults' -DefaultValue ([pscustomobject]@{})
    Initialize-NoteProperty -Object $settingsRoot.profiles.defaults -Name 'font' -DefaultValue ([pscustomobject]@{})

    if ($settingsRoot.profiles.defaults.font.PSObject.Properties.Name -contains 'face') {
        $settingsRoot.profiles.defaults.font.face = $FontFace
    } else {
        $settingsRoot.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name 'face' -Value $FontFace -Force
    }

    return $Configuration
}

Export-ModuleMember -Function Set-TerminalDefaultFont
