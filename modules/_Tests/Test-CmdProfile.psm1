Import-Module ".\modules\Utils\Get-ExecutableToken.psm1"

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