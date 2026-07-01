Import-Module ".\modules\Utils\Initialize-NoteProperty.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Configuration\Resolve-FilePath.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Update-Profile.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Copy-TerminalProfileIcons.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Set-TerminalProfileIcon.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Set-TerminalProfileStartingDirectory.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Configuration\Get-TerminalConfiguration.psm1" -ErrorAction Stop
Import-Module ".\modules\_Tests\Test-CmdProfile.psm1" -ErrorAction Stop
Import-Module ".\modules\_Tests\Test-WindowsPowerShellProfile.psm1" -ErrorAction Stop

# Normalizes the Windows Terminal profile list and adds developer tool profiles.
# [input-param] ExecutablesMap: map of executable paths; supported keys are git, node, python, and java
# [input-param] SettingsObject: object from Get-TerminalConfiguration or parsed settings.json; when empty, the configuration is loaded automatically
# [input-param] SettingsPath: optional settings.json path used when loading the configuration automatically
# [input-param] JsonDepth: serialization depth passed to Get-TerminalConfiguration
# [output-param] object: the same SettingsObject after modification
# [input-param] RemoveOtherProfiles: when true, removes profiles other than CMD/Windows PowerShell before adding selected developer profiles
# [side-effect] Modifies profiles.list in the passed object, optionally removes profiles other than CMD/Windows PowerShell, adds Git Bash, Node, Python, and Java/jshell when executables are detected, copies profile icon resources next to settings.json, assigns profile icon paths, and sets Git Bash to start in %USERPROFILE%.
function Set-TerminalProfiles {
    [CmdletBinding()]
    param(
        # input: list of executables to add (git bash, node, python, java)
        # expected keys: git, node, python, java
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
        [int] $JsonDepth = 100,

        [Parameter(Mandatory = $false)]
        [bool] $RemoveOtherProfiles = $true
    )

    # If not provided, load existing configuration so we still operate on an object in memory.
    if (-not $SettingsObject) {
        if (-not $SettingsPath) { $SettingsPath = Get-TerminalSettingsPath }
        $SettingsObject = Get-TerminalConfiguration -SettingsPath $SettingsPath -JsonDepth $JsonDepth
    }

    if ((-not $SettingsPath) -and $SettingsObject -and ($SettingsObject.PSObject.Properties.Name -contains 'SettingsPath')) {
        $SettingsPath = [string]$SettingsObject.SettingsPath
    }

    $profileIcons = @{}
    if ($SettingsPath) {
        $profileIcons = Copy-TerminalProfileIcons -SettingsPath $SettingsPath
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

    # Step 1: optionally keep only CMD + Windows PowerShell profiles
    $kept = New-Object System.Collections.ArrayList
    foreach ($p in $existing) {
        if ((-not $RemoveOtherProfiles) -or (Test-CmdProfile -Profile $p) -or (Test-WindowsPowerShellProfile -Profile $p)) {
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

    # Step 2: add Git Bash / Node / Python / Java (only when the executable exists)

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
        [void](Set-TerminalProfileStartingDirectory -Profiles $kept -Name 'Git Bash' -StartingDirectory '%USERPROFILE%')
        if ($profileIcons.ContainsKey('git')) {
            [void](Set-TerminalProfileIcon -Profiles $kept -Name 'Git Bash' -IconPath $profileIcons['git'])
        }
    } else {
        Write-Verbose "Git Bash not added (path missing or not found)."
    }

    $nodeExe = Resolve-FilePath -Candidate ([string]$ExecutablesMap['node']) -FallbackRelativePaths @('node.exe')
    if ($nodeExe) {
        Update-Profile -Profiles $kept -Name 'Node' -CommandLine ('"{0}"' -f $nodeExe)
        if ($profileIcons.ContainsKey('node')) {
            [void](Set-TerminalProfileIcon -Profiles $kept -Name 'Node' -IconPath $profileIcons['node'])
        }
    } else {
        Write-Verbose "Node profile not added (path missing or not found)."
    }

    $pythonExe = Resolve-FilePath -Candidate ([string]$ExecutablesMap['python']) -FallbackRelativePaths @('python.exe', 'python3.exe')
    if ($pythonExe) {
        Update-Profile -Profiles $kept -Name 'Python' -CommandLine ('"{0}"' -f $pythonExe)
        if ($profileIcons.ContainsKey('python')) {
            [void](Set-TerminalProfileIcon -Profiles $kept -Name 'Python' -IconPath $profileIcons['python'])
        }
    } else {
        Write-Verbose "Python profile not added (path missing or not found)."
    }

    $javaCandidate = if ($ExecutablesMap.ContainsKey('java')) { [string]$ExecutablesMap['java'] } else { $null }
    $jshellExe = $null

    if (-not [string]::IsNullOrWhiteSpace($javaCandidate)) {
        $javaCandidate = $javaCandidate.Trim().Trim('"')

        if (Test-Path -LiteralPath $javaCandidate) {
            $javaItem = Get-Item -LiteralPath $javaCandidate -ErrorAction SilentlyContinue

            if ($javaItem -and $javaItem.PSIsContainer) {
                foreach ($relativePath in @('bin\jshell.exe', 'jshell.exe')) {
                    $jshellCandidate = Join-Path -Path $javaItem.FullName -ChildPath $relativePath
                    if (Test-Path -LiteralPath $jshellCandidate) {
                        $jshellExe = (Resolve-Path -LiteralPath $jshellCandidate).Path
                        break
                    }
                }
            } elseif ($javaItem -and ($javaItem.Name -ieq 'jshell.exe')) {
                $jshellExe = $javaItem.FullName
            } elseif ($javaItem -and (($javaItem.Name -ieq 'java.exe') -or ($javaItem.Name -ieq 'javac.exe'))) {
                $javaExeDirectory = Split-Path -Path $javaItem.FullName -Parent
                $jshellCandidate = Join-Path -Path $javaExeDirectory -ChildPath 'jshell.exe'
                if (Test-Path -LiteralPath $jshellCandidate) {
                    $jshellExe = (Resolve-Path -LiteralPath $jshellCandidate).Path
                }
            }
        }
    }

    if ($jshellExe) {
        Update-Profile -Profiles $kept -Name 'Java' -CommandLine ('"{0}"' -f $jshellExe)
        if ($profileIcons.ContainsKey('java')) {
            [void](Set-TerminalProfileIcon -Profiles $kept -Name 'Java' -IconPath $profileIcons['java'])
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($javaCandidate)) {
        Write-Warning "Java profile not added: jshell.exe was not found, so no interactive Java session can be configured."
    } else {
        Write-Verbose "Java profile not added (path missing or not found)."
    }

    # In-place update (same object instance)
    $settingsRoot.profiles.list = @($kept)

    return $SettingsObject
}


Export-ModuleMember -Function Set-TerminalProfiles
