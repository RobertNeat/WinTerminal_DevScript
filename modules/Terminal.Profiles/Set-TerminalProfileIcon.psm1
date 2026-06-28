# Sets the icon path for an existing Windows Terminal profile.
# [input-param] Profiles: mutable Windows Terminal profile list
# [input-param] Name: profile name whose icon should be updated
# [input-param] IconPath: path written to the profile icon property
# [output-param] bool: true when the profile was found and updated; otherwise false
# [side-effect] Modifies the matching profile object in memory by adding or updating the icon property.
function Set-TerminalProfileIcon {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList] $Profiles,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $IconPath
    )

    if ([string]::IsNullOrWhiteSpace($IconPath)) {
        return $false
    }

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $profile = $Profiles[$i]
        if ($profile -and ([string]$profile.name) -and (([string]$profile.name) -ieq $Name)) {
            if ($profile.PSObject.Properties.Name -contains 'icon') {
                $profile.icon = $IconPath
            } else {
                $profile | Add-Member -MemberType NoteProperty -Name 'icon' -Value $IconPath -Force
            }

            return $true
        }
    }

    return $false
}

Export-ModuleMember -Function Set-TerminalProfileIcon
