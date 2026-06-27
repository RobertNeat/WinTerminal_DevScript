# Updates an existing terminal profile or adds a new one.
# [input-param] Profiles: mutable Windows Terminal profile list
# [input-param] Name: profile name to find or create
# [input-param] CommandLine: commandline value to set on the profile
# [side-effect] Modifies the Profiles list in memory: updates a profile or adds a new profile object.
function Update-Profile {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IList]$Profiles,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$CommandLine
    )

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $p = $Profiles[$i]
        if ($p -and ([string]$p.name) -and (([string]$p.name) -ieq $Name)) {
            $p.commandline = $CommandLine
            if ($p.PSObject.Properties.Name -contains 'hidden') { $p.hidden = $false }
            else { $p | Add-Member -MemberType NoteProperty -Name 'hidden' -Value $false -Force }
            return
        }
    }

    [void]$Profiles.Add([pscustomobject]@{ name = $Name; commandline = $CommandLine; hidden = $false })
}

Export-ModuleMember -Function Update-Profile
