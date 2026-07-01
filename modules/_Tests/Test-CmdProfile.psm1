Import-Module (Join-Path $PSScriptRoot '..\Utils\Get-ExecutableToken.psm1')  -ErrorAction Stop

# Checks whether a Windows Terminal profile represents Command Prompt.
# [input-param] Profile: profile object with name and/or commandline fields
# [output-param] bool: true when the name or commandline points to cmd.exe
function Test-CmdProfile {
    param([psobject] $Profile)
    if (-not $Profile) { return $false }

    $name = [string]$Profile.name
    $cmd = [string]$Profile.commandline
    if ($name -and ($name -match '(?i)\bCommand\s+Prompt\b')) { return $true }

    $exe = Get-ExecutableToken -CommandLine $cmd
    if ($exe) {
        $leaf = [System.IO.Path]::GetFileName($exe)
        if ($leaf -and ($leaf -ieq 'cmd.exe' -or $leaf -ieq 'cmd')) { return $true }
    }

    return ($cmd -match '(?i)(^|\\|\s)cmd(\.exe)?(\s|$)')
}

Export-ModuleMember -Function Test-CmdProfile
