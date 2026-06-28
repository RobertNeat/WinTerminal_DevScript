# Sets the starting directory for an existing Windows Terminal profile.
# [input-param] Profiles: mutable Windows Terminal profile list
# [input-param] Name: profile name whose starting directory should be updated
# [input-param] StartingDirectory: value written to the profile startingDirectory property
# [output-param] bool: true when the profile was found and updated; otherwise false
# [side-effect] Modifies the matching profile object in memory by adding or updating the startingDirectory property.
function Set-TerminalProfileStartingDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList] $Profiles,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $StartingDirectory
    )

    if ([string]::IsNullOrWhiteSpace($StartingDirectory)) {
        return $false
    }

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $profile = $Profiles[$i]
        if ($profile -and ([string]$profile.name) -and (([string]$profile.name) -ieq $Name)) {
            if ($profile.PSObject.Properties.Name -contains 'startingDirectory') {
                $profile.startingDirectory = $StartingDirectory
            } else {
                $profile | Add-Member -MemberType NoteProperty -Name 'startingDirectory' -Value $StartingDirectory -Force
            }

            return $true
        }
    }

    return $false
}

Export-ModuleMember -Function Set-TerminalProfileStartingDirectory
