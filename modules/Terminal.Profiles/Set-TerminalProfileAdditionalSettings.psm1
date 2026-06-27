Import-Module ".\modules\Utils\Get-ExecutableToken.psm1"
Import-Module ".\modules\_Tests\Test-WindowsPowerShellProfile.psm1"

<#
  "profiles": {
    "list": [
      {
        "showMarksOnScrollbar": true,
        "autoMarkPrompts": true
      }
    ]}
#>
# Extends profiles with additional settings and matched color schemes.
# [input-param] Configuration: configuration object or wrapper containing Settings and TerminalVersion
# [input-param] ParamsMap: map of settings added to each profile; defaults to showMarksOnScrollbar and autoMarkPrompts
# [output-param] PSCustomObject|null: the same Configuration object for Windows Terminal >= 1.21; null for older versions
# [side-effect] Modifies profiles.list in memory, adding missing profile settings, colorScheme, and -NoLogo for Windows PowerShell.
function Set-TerminalProfileAdditionalSettings {
    param(
        [PSCustomObject] $Configuration,
        [hashtable] $ParamsMap  # key-value map to add to each profile
    )

    $windowsTerminalVersion = $null
    try { $windowsTerminalVersion = [version]$Configuration.TerminalVersion } catch { }

    if($windowsTerminalVersion -ge [version]'1.21') {
        # add the additional settings from ParamsMap to each profile in the profiles list
        # ensure that existing settings are not overwritten (only add if the setting does not already exist for the profile)

        if (-not $Configuration) { throw 'Configuration is required.' }

        # Extract the settings root object similar to other functions
        $settingsJson = $Configuration
        if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings') -and $Configuration.Settings) {
            $settingsJson = $Configuration.Settings
        }
        if (-not $settingsJson) { throw 'Configuration.Settings is null (cannot update profile additional settings).' }

        $settingsRoot = $settingsJson
        if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
            $settingsRoot = $settingsJson.settings
        }

        # Ensure profiles.list exists
        if (-not ($settingsRoot.PSObject.Properties.Name -contains 'profiles')) { $settingsRoot | Add-Member -MemberType NoteProperty -Name 'profiles' -Value ([pscustomobject]@{}) -Force }
        if (-not ($settingsRoot.profiles.PSObject.Properties.Name -contains 'list')) { $settingsRoot.profiles | Add-Member -MemberType NoteProperty -Name 'list' -Value @() -Force }

        $profiles = @($settingsRoot.profiles.list)

        # Build a set of available scheme names (normalized -> original)
        $schemeMap = @{}
        if ($settingsRoot.PSObject.Properties.Name -contains 'schemes' -and $settingsRoot.schemes) {
            foreach ($s in @($settingsRoot.schemes)) {
                if ($s -and ($s.name)) {
                    $norm = ([string]$s.name).ToLower().Replace(' ', '').Replace('-', '').Replace('_','')
                    if (-not $schemeMap.ContainsKey($norm)) { $schemeMap[$norm] = $s.name }
                }
            }
        }

        # default params if not supplied
        if (-not $ParamsMap) { $ParamsMap = @{} }
        if (-not $ParamsMap.ContainsKey('showMarksOnScrollbar')) { $ParamsMap['showMarksOnScrollbar'] = $true }
        if (-not $ParamsMap.ContainsKey('autoMarkPrompts')) { $ParamsMap['autoMarkPrompts'] = $true }

        foreach ($p in $profiles) {
            if (-not $p) { continue }

            # Add boolean settings from ParamsMap if provided and not already present
            foreach ($k in $ParamsMap.Keys) {
                $val = $ParamsMap[$k]
                if (-not ($p.PSObject.Properties.Name -contains $k) -or $null -eq $p.$k) {
                    $p | Add-Member -MemberType NoteProperty -Name $k -Value $val -Force
                }
            }

            # Attach a color scheme to the profile if not already set
            if (-not ($p.PSObject.Properties.Name -contains 'colorScheme') -or [string]::IsNullOrWhiteSpace([string]$p.colorScheme)) {
                $profileName = if ($p.PSObject.Properties.Name -contains 'name') { [string]$p.name } else { $null }
                $cmd = if ($p.PSObject.Properties.Name -contains 'commandline') { [string]$p.commandline } else { $null }

                $candidates = @()
                if ($profileName) { $candidates += $profileName }
                if ($cmd) { $exe = (Get-ExecutableToken -CommandLine $cmd) ; if ($exe) { $candidates += $exe } }

                $foundScheme = $null
                foreach ($cand in $candidates) {
                    if (-not $cand) { continue }
                    $norm = ([string]$cand).ToLower().Replace(' ', '').Replace('-', '').Replace('_','')
                    if ($schemeMap.ContainsKey($norm)) { $foundScheme = $schemeMap[$norm]; break }

                    # fuzzy: try substring/token match against scheme names
                    foreach ($k in $schemeMap.Keys) {
                        if (-not $k) { continue }
                        $schemeKey = $k
                        # direct substring
                        if ($schemeKey -like "*$norm*") { $foundScheme = $schemeMap[$k]; break }

                        # token-based: split candidate into tokens and check if any token appears in scheme key
                        $tokens = ([regex]::Split($cand.ToLower(), '[^a-z0-9]+')) | Where-Object { $_ -ne '' }
                        foreach ($t in $tokens) {
                            if ($t -and ($schemeKey -like "*${t}*")) { $foundScheme = $schemeMap[$k]; break }
                        }
                        if ($foundScheme) { break }
                    }
                    if ($foundScheme) { break }
                }

                if ($foundScheme) {
                    $p | Add-Member -MemberType NoteProperty -Name 'colorScheme' -Value $foundScheme -Force
                }
            }
            # Ensure PowerShell commandline contains -NoLogo
            try {
                $isPowerShell = Test-WindowsPowerShellProfile -Profile $p
                if ($isPowerShell) {
                    $existingCmd = if ($p.PSObject.Properties.Name -contains 'commandline') { [string]$p.commandline } else { $null }
                    if (-not [string]::IsNullOrWhiteSpace($existingCmd)) {
                        if ($existingCmd -notmatch '(?i)\-NoLogo') {
                            # append -NoLogo preserving quoting
                            if ($existingCmd.Trim().EndsWith('"')) {
                                $p.commandline = $existingCmd + ' -NoLogo'
                            } else {
                                $p.commandline = $existingCmd + ' -NoLogo'
                            }
                        }
                    } else {
                        $p | Add-Member -MemberType NoteProperty -Name 'commandline' -Value 'powershell.exe -NoLogo' -Force
                    }
                }
            } catch {
                # ignore detection errors
            }
        }

        # write back the modified list in-place
        $settingsRoot.profiles.list = @($profiles)
        return $Configuration
    }
}

Export-ModuleMember -Function Set-TerminalProfileAdditionalSettings
