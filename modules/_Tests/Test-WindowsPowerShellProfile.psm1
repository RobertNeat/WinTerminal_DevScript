Import-Module ".\modules\Utils\Get-ExecutableToken.psm1"  -ErrorAction Stop

# Checks whether a Windows Terminal profile represents Windows PowerShell.
# [input-param] Profile: profile object with name and/or commandline fields
# [output-param] bool: true when the name or commandline points to powershell.exe
function Test-WindowsPowerShellProfile {
    param([psobject]$Profile)
    if (-not $Profile) { return $false }

    $name = [string]$Profile.name
    $cmd = [string]$Profile.commandline
    if ($name -and ($name -match '(?i)\bWindows\s+PowerShell\b')) { return $true }

    $exe = Get-ExecutableToken -CommandLine $cmd
    if ($exe) {
        $leaf = [System.IO.Path]::GetFileName($exe)
        if ($leaf -and ($leaf -ieq 'powershell.exe' -or $leaf -ieq 'powershell')) { return $true }
    }

    return ($cmd -match '(?i)(^|\\|\s)powershell(\.exe)?(\s|$)')
}

Export-ModuleMember -Function Test-WindowsPowerShellProfile
