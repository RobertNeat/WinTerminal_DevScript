Import-Module ".\modules\Utils\Initialize-NoteProperty.psm1"
Import-Module ".\modules\Terminal.Configuration\Resolve-FilePath.psm1"
Import-Module ".\modules\Terminal.Profiles\Update-Profile.psm1"
Import-Module ".\modules\Terminal.Configuration\Get-TerminalConfiguration.psm1"

Import-Module ".\modules\_Tests\Test-CmdProfile.psm1"
Import-Module ".\modules\_Tests\Test-WindowsPowerShellProfile.psm1"

# manipulate JSON entries:
# - delete the entries that are not CMD, PowerShell
# - add entries for git bash, node, python (if not already present)
# - customize icons, names, color schemes for the entries
function Set-TerminalProfiles {
    [CmdletBinding()]
    param(
        # input: list of executables to add (git bash, node, python)
        # expected keys: git, node, python
        [Parameter(Mandatory = $true)]
        [hashtable] $ExecutablesMap,

        # input: either
        # - the object returned by Get-TerminalConfiguration (has .Settings), OR
        # - the parsed settings.json object returned by ConvertFrom-Json.
        # If omitted, this function will load settings.json automatically.
        [Parameter(Mandatory = $false)]
        [object] $SettingsObject,

        [Parameter(Mandatory = $false)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 100)]
        [int] $JsonDepth = 100
    )

    # If not provided, load existing configuration so we still operate on an object in memory.
    if (-not $SettingsObject) {
        if (-not $SettingsPath) { $SettingsPath = Get-TerminalSettingsPath }
        $SettingsObject = Get-TerminalConfiguration -SettingsPath $SettingsPath -JsonDepth $JsonDepth
    }

    # Operate on Settings property when the wrapper is passed.
    $settingsJson = $SettingsObject
    if ($SettingsObject -and ($SettingsObject.PSObject.Properties.Name -contains 'Settings')) {
        $settingsJson = $SettingsObject.Settings
    }
    if (-not $settingsJson) { throw 'SettingsObject is null (cannot update profiles).' }

    # Some exports wrap the real WT schema in a nested .settings object; support both.
    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    Initialize-NoteProperty -Object $settingsRoot -Name 'profiles' -DefaultValue ([pscustomobject]@{})
    Initialize-NoteProperty -Object $settingsRoot.profiles -Name 'list' -DefaultValue @()

    $existing = @($settingsRoot.profiles.list)

    # Step 1: keep only CMD + Windows PowerShell profiles
    $kept = New-Object System.Collections.ArrayList
    foreach ($p in $existing) {
        if ((Test-CmdProfile -Profile $p) -or (Test-WindowsPowerShellProfile -Profile $p)) {
            [void]$kept.Add($p)
        }
    }

    # Ensure at least one CMD and one Windows PowerShell profile exist.
    $hasCmd = $false
    $hasWinPS = $false
    foreach ($p in @($kept)) {
        if (-not $hasCmd -and (Test-CmdProfile -Profile $p)) { $hasCmd = $true }
        if (-not $hasWinPS -and (Test-WindowsPowerShellProfile -Profile $p)) { $hasWinPS = $true }
    }
    if (-not $hasWinPS) { [void]$kept.Add([pscustomobject]@{ name = 'Windows PowerShell'; commandline = 'powershell.exe'; hidden = $false }) }
    if (-not $hasCmd) { [void]$kept.Add([pscustomobject]@{ name = 'Command Prompt'; commandline = 'cmd.exe'; hidden = $false }) }

    # Step 2: add Git Bash / Node / Python (only when the executable exists)

    $gitExe = Resolve-FilePath -Candidate ([string]$ExecutablesMap['git']) -FallbackRelativePaths @(
        'usr\bin\bash.exe',
        'bin\bash.exe',
        'mingw64\bin\bash.exe',
        'git-bash.exe'
    )
    if ($gitExe) {
        $leaf = Split-Path -Path $gitExe -Leaf
        $gitCmd = if ($leaf -and ($leaf -ieq 'bash.exe')) { '"{0}" --login -i' -f $gitExe } else { '"{0}"' -f $gitExe }
        Update-Profile -Profiles $kept -Name 'Git Bash' -CommandLine $gitCmd
    } else {
        Write-Verbose "Git Bash not added (path missing or not found)."
    }

    $nodeExe = Resolve-FilePath -Candidate ([string]$ExecutablesMap['node']) -FallbackRelativePaths @('node.exe')
    if ($nodeExe) {
        Update-Profile -Profiles $kept -Name 'Node' -CommandLine ('"{0}"' -f $nodeExe)
    } else {
        Write-Verbose "Node profile not added (path missing or not found)."
    }

    $pythonExe = Resolve-FilePath -Candidate ([string]$ExecutablesMap['python']) -FallbackRelativePaths @('python.exe', 'python3.exe')
    if ($pythonExe) {
        Update-Profile -Profiles $kept -Name 'Python' -CommandLine ('"{0}"' -f $pythonExe)
    } else {
        Write-Verbose "Python profile not added (path missing or not found)."
    }

    # In-place update (same object instance)
    $settingsRoot.profiles.list = @($kept)

    return $SettingsObject
}


Export-ModuleMember -Function Set-TerminalProfiles