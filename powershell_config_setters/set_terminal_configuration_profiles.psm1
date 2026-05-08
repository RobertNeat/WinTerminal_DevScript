Import-Module ".\powershell_config_setters\color_schemes.psm1"

# get windows terminal JSON configuration file path
function Resolve-WindowsTerminalSettingsPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $SettingsPath
    )

    if ($SettingsPath) {
        if (Test-Path -LiteralPath $SettingsPath) { return (Resolve-Path -LiteralPath $SettingsPath).Path }
        throw "SettingsPath not found: $SettingsPath"
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    function Add-CandidatePath {
        param([Parameter(Mandatory = $true)][string] $Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if ($seen.Add($Path)) { [void]$candidates.Add($Path) }
    }

    # Prefer the documented locations first (stable -> preview).
    Add-CandidatePath (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
    Add-CandidatePath (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json")

    # Also discover installed package family name(s) dynamically (covers Canary/other variants).
    try {
        $pkgs = Get-AppxPackage -Name "Microsoft.WindowsTerminal*" -ErrorAction Stop

        $orderedPkgs = @()
        $orderedPkgs += $pkgs | Where-Object { $_.PackageFamilyName -eq "Microsoft.WindowsTerminal_8wekyb3d8bbwe" }
        $orderedPkgs += $pkgs | Where-Object { $_.PackageFamilyName -eq "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe" }
        $orderedPkgs += $pkgs | Where-Object {
            $_.PackageFamilyName -and
            $_.PackageFamilyName -ne "Microsoft.WindowsTerminal_8wekyb3d8bbwe" -and
            $_.PackageFamilyName -ne "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe"
        } | Sort-Object -Property PackageFamilyName

        foreach ($pkg in $orderedPkgs) {
            if (-not $pkg.PackageFamilyName) { continue }
            Add-CandidatePath (Join-Path $env:LOCALAPPDATA ("Packages\{0}\LocalState\settings.json" -f $pkg.PackageFamilyName))
        }
    } catch {
        # ignore (e.g., Get-AppxPackage unavailable)
    }

    # Unpackaged/fallback location (sometimes used by non-Store installs: Scoop, Chocolatey, etc.).
    Add-CandidatePath (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")

    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }

    # 4) Last resort: wildcard search only at the package-folder level (not a full recurse)
    $packagesRoot = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path -LiteralPath $packagesRoot) {
        $dirs = Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*WindowsTerminal*_*" }

        foreach ($d in $dirs) {
            $p = Join-Path $d.FullName "LocalState\settings.json"
            if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
        }
    }

    throw "Could not locate Windows Terminal settings.json under LOCALAPPDATA. Provide -SettingsPath explicitly."
}

# [input-param] SettingsPath: resolved path to settings.json
# [output-param] TerminalVersion: detected WT version string
# [output-param] JsonDepth: the depth used for ConvertTo-Json (PowerShell 5’s max is 100)
# [output-param] Settings: the actual parsed JSON as a nested PSCustomObject tree — this is what you should edit
function Get-ExistingTerminalConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 100)]
        [int] $JsonDepth = 100,

        [Parameter(Mandatory = $false)]
        [switch] $SkipRoundTripValidation
    )

    $resolvedPath = Resolve-WindowsTerminalSettingsPath -SettingsPath $SettingsPath

    $terminalVersion = Assert-WindowsTerminalMinVersion -MinimumVersion ([version]'1.24')

    try {
        $rawJson = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        throw "Failed to read Windows Terminal settings.json at '$resolvedPath'. $($_.Exception.Message)"
    }

    try {
        $settingsObject = ConvertFrom-Json -InputObject $rawJson -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$resolvedPath'. $($_.Exception.Message)"
    }

    $configuration = [pscustomobject]@{
        PSTypeName      = 'WindowsTerminal.Configuration'
        SettingsPath    = $resolvedPath
        TerminalVersion = $terminalVersion.ToString()
        JsonDepth       = $JsonDepth
        Settings        = $settingsObject
    }

    if (-not $SkipRoundTripValidation) {
        $ok = Test-TerminalConfigurationRoundTrip -Configuration $configuration -SettingsPath $resolvedPath -JsonDepth $JsonDepth
        if (-not $ok) {
            throw "Round-trip JSON validation failed for '$resolvedPath'. The parsed object cannot be serialized back to an equivalent settings.json structure."
        }
    }

    return $configuration
}

function Test-TerminalConfigurationRoundTrip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Configuration,

        [Parameter(Mandatory = $false)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(2, 100)]
        [int] $JsonDepth = 100
    )

    if (-not $SettingsPath) {
        if ($Configuration -and $Configuration.PSObject.Properties.Name -contains 'SettingsPath') {
            $SettingsPath = [string]$Configuration.SettingsPath
        }
    }

    if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        throw "SettingsPath is required (either pass -SettingsPath or provide a Configuration with SettingsPath)."
    }

    $resolvedPath = Resolve-WindowsTerminalSettingsPath -SettingsPath $SettingsPath

    $originalJson = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    $originalObj = ConvertFrom-Json -InputObject $originalJson

    $settingsToSerialize = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings')) {
        $settingsToSerialize = $Configuration.Settings
    }

    $roundTripJson = $settingsToSerialize | ConvertTo-Json -Depth $JsonDepth -Compress
    $roundTripObj = ConvertFrom-Json -InputObject $roundTripJson

    return (Test-DeepObjectEqual -Left $originalObj -Right $roundTripObj -MaxDepth $JsonDepth)
}

function Get-WindowsTerminalInstalledVersion {
    [CmdletBinding()]
    param()

    $versions = New-Object System.Collections.Generic.List[version]

    # Primary: Store/Appx packages (stable/preview/canary)
    try {
        $pkgs = Get-AppxPackage -Name "Microsoft.WindowsTerminal*" -ErrorAction Stop
        foreach ($pkg in $pkgs) {
            if (-not $pkg.Version) { continue }
            try { [void]$versions.Add([version]$pkg.Version) } catch { }
        }
    } catch {
        # ignore
    }

    # Fallback: wt.exe file version (covers unpackaged installs)
    try {
        $wt = Get-Command wt.exe -ErrorAction Stop
        if ($wt -and $wt.Source -and (Test-Path -LiteralPath $wt.Source)) {
            $pv = (Get-Item -LiteralPath $wt.Source).VersionInfo.ProductVersion
            if ($pv) {
                try { [void]$versions.Add([version]$pv) } catch { }
            }
        }
    } catch {
        # ignore
    }

    if ($versions.Count -eq 0) {
        throw "Could not determine Windows Terminal version. Ensure Windows Terminal is installed and that either Get-AppxPackage is available or wt.exe is on PATH."
    }

    return ($versions | Sort-Object -Descending | Select-Object -First 1)
}

function Assert-WindowsTerminalMinVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version] $MinimumVersion
    )

    $installed = Get-WindowsTerminalInstalledVersion
    if ($installed -lt $MinimumVersion) {
        throw "Windows Terminal version '$installed' is below the required minimum '$MinimumVersion'."
    }

    return $installed
}

function Test-DeepObjectEqual {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Left,

        [Parameter(Mandatory = $true)]
        $Right,

        [Parameter(Mandatory = $false)]
        [int] $MaxDepth = 200,

        [Parameter(Mandatory = $false)]
        [int] $Depth = 0
    )

    if ($Depth -gt $MaxDepth) {
        return $true
    }

    if ($null -eq $Left -and $null -eq $Right) { return $true }
    if ($null -eq $Left -or $null -eq $Right) { return $false }

    # Treat numeric types as numeric, regardless of exact CLR type
    $leftIsNumber = $Left -is [byte] -or $Left -is [sbyte] -or $Left -is [int16] -or $Left -is [uint16] -or $Left -is [int32] -or $Left -is [uint32] -or $Left -is [int64] -or $Left -is [uint64] -or $Left -is [single] -or $Left -is [double] -or $Left -is [decimal]
    $rightIsNumber = $Right -is [byte] -or $Right -is [sbyte] -or $Right -is [int16] -or $Right -is [uint16] -or $Right -is [int32] -or $Right -is [uint32] -or $Right -is [int64] -or $Right -is [uint64] -or $Right -is [single] -or $Right -is [double] -or $Right -is [decimal]
    if ($leftIsNumber -and $rightIsNumber) {
        try { return ([decimal]$Left -eq [decimal]$Right) } catch { return ([double]$Left -eq [double]$Right) }
    }

    # Strings / bools / simple scalars
    if ($Left -is [string] -or $Right -is [string]) { return ([string]$Left -ceq [string]$Right) }
    if ($Left -is [bool] -or $Right -is [bool]) { return ([bool]$Left -eq [bool]$Right) }
    if ($Left -is [datetime] -or $Right -is [datetime]) { return ([datetime]$Left -eq [datetime]$Right) }

    # Arrays / lists (order matters)
    $leftIsEnumerable = ($Left -is [System.Collections.IEnumerable]) -and -not ($Left -is [string]) -and -not ($Left -is [System.Collections.IDictionary])
    $rightIsEnumerable = ($Right -is [System.Collections.IEnumerable]) -and -not ($Right -is [string]) -and -not ($Right -is [System.Collections.IDictionary])
    if ($leftIsEnumerable -or $rightIsEnumerable) {
        if (-not ($leftIsEnumerable -and $rightIsEnumerable)) { return $false }

        $l = @($Left)
        $r = @($Right)
        if ($l.Count -ne $r.Count) { return $false }

        for ($i = 0; $i -lt $l.Count; $i++) {
            if (-not (Test-DeepObjectEqual -Left $l[$i] -Right $r[$i] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # Dictionaries / hashtables (order does not matter)
    if ($Left -is [System.Collections.IDictionary] -or $Right -is [System.Collections.IDictionary]) {
        if (-not ($Left -is [System.Collections.IDictionary] -and $Right -is [System.Collections.IDictionary])) { return $false }

        if ($Left.Keys.Count -ne $Right.Keys.Count) { return $false }
        foreach ($k in $Left.Keys) {
            if (-not $Right.Contains($k)) { return $false }
            if (-not (Test-DeepObjectEqual -Left $Left[$k] -Right $Right[$k] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # PSCustomObject / other objects: compare note properties by name (order does not matter)
    $leftProps = @($Left.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
    $rightProps = @($Right.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })

    # JSON empty objects become empty PSCustomObject instances; treat them as equal.
    if (
        $leftProps.Count -eq 0 -and
        $rightProps.Count -eq 0 -and
        $Left.GetType().FullName -eq 'System.Management.Automation.PSCustomObject' -and
        $Right.GetType().FullName -eq 'System.Management.Automation.PSCustomObject'
    ) {
        return $true
    }

    if ($leftProps.Count -gt 0 -or $rightProps.Count -gt 0) {
        if ($leftProps.Count -ne $rightProps.Count) { return $false }

        $rightMap = @{}
        foreach ($p in $rightProps) { $rightMap[$p.Name] = $p.Value }

        foreach ($p in $leftProps) {
            if (-not $rightMap.ContainsKey($p.Name)) { return $false }
            if (-not (Test-DeepObjectEqual -Left $p.Value -Right $rightMap[$p.Name] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # Fallback: direct comparison
    return ($Left -eq $Right)
}

# manipulate JSON entries:
# - delete the entries that are not CMD, PowerShell
# - add entries for git bash, node, python (if not already present)
# - customize icons, names, color schemes for the entries
function Update-TerminalProfiles {
    [CmdletBinding()]
    param(
        # input: list of executables to add (git bash, node, python)
        # expected keys: git, node, python
        [Parameter(Mandatory = $true)]
        [hashtable] $ExecutablesMap,

        # input: either
        # - the object returned by Get-ExistingTerminalConfiguration (has .Settings), OR
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

    function Ensure-NoteProperty {
        param(
            [Parameter(Mandatory = $true)][psobject]$Object,
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)]$DefaultValue
        )

        if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
            $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultValue -Force
        } elseif ($null -eq $Object.$Name) {
            $Object.$Name = $DefaultValue
        }
    }

    function Get-ExecutableToken {
        param([string]$CommandLine)

        if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $null }
        $s = $CommandLine.Trim()
        if ($s.StartsWith('"')) {
            $m = [regex]::Match($s, '^[\"]([^\"]+)[\"]')
            if ($m.Success) { return $m.Groups[1].Value }
        }
        $m2 = [regex]::Match($s, '^(\S+)')
        if ($m2.Success) { return $m2.Groups[1].Value }
        return $null
    }

    function Test-IsCmdProfile {
        param([psobject]$Profile)
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

    function Test-IsWindowsPowerShellProfile {
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

    function Resolve-ExecutablePath {
        param(
            [string]$Candidate,
            [string[]]$FallbackRelativePaths
        )

        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
        $c = $Candidate.Trim().Trim('"')

        try {
            if (Test-Path -LiteralPath $c) {
                $item = Get-Item -LiteralPath $c -ErrorAction SilentlyContinue
                if ($item -and -not $item.PSIsContainer) {
                    return $item.FullName
                }
                if ($item -and $item.PSIsContainer) {
                    foreach ($rel in $FallbackRelativePaths) {
                        $p = Join-Path $item.FullName $rel
                        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
                    }
                }
            }
        } catch {
            return $null
        }

        return $null
    }

    function Upsert-ProfileByName {
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

    # If not provided, load existing configuration so we still operate on an object in memory.
    if (-not $SettingsObject) {
        if (-not $SettingsPath) { $SettingsPath = Resolve-WindowsTerminalSettingsPath }
        $SettingsObject = Get-ExistingTerminalConfiguration -SettingsPath $SettingsPath -JsonDepth $JsonDepth
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

    Ensure-NoteProperty -Object $settingsRoot -Name 'profiles' -DefaultValue ([pscustomobject]@{})
    Ensure-NoteProperty -Object $settingsRoot.profiles -Name 'list' -DefaultValue @()

    $existing = @($settingsRoot.profiles.list)

    # Step 1: keep only CMD + Windows PowerShell profiles
    $kept = New-Object System.Collections.ArrayList
    foreach ($p in $existing) {
        if ((Test-IsCmdProfile -Profile $p) -or (Test-IsWindowsPowerShellProfile -Profile $p)) {
            [void]$kept.Add($p)
        }
    }

    # Ensure at least one CMD and one Windows PowerShell profile exist.
    $hasCmd = $false
    $hasWinPS = $false
    foreach ($p in @($kept)) {
        if (-not $hasCmd -and (Test-IsCmdProfile -Profile $p)) { $hasCmd = $true }
        if (-not $hasWinPS -and (Test-IsWindowsPowerShellProfile -Profile $p)) { $hasWinPS = $true }
    }
    if (-not $hasWinPS) { [void]$kept.Add([pscustomobject]@{ name = 'Windows PowerShell'; commandline = 'powershell.exe'; hidden = $false }) }
    if (-not $hasCmd) { [void]$kept.Add([pscustomobject]@{ name = 'Command Prompt'; commandline = 'cmd.exe'; hidden = $false }) }

    # Step 2: add Git Bash / Node / Python (only when the executable exists)

    $gitExe = Resolve-ExecutablePath -Candidate ([string]$ExecutablesMap['git']) -FallbackRelativePaths @(
        'usr\bin\bash.exe',
        'bin\bash.exe',
        'mingw64\bin\bash.exe',
        'git-bash.exe'
    )
    if ($gitExe) {
        $leaf = Split-Path -Path $gitExe -Leaf
        $gitCmd = if ($leaf -and ($leaf -ieq 'bash.exe')) { '"{0}" --login -i' -f $gitExe } else { '"{0}"' -f $gitExe }
        Upsert-ProfileByName -Profiles $kept -Name 'Git Bash' -CommandLine $gitCmd
    } else {
        Write-Verbose "Git Bash not added (path missing or not found)."
    }

    $nodeExe = Resolve-ExecutablePath -Candidate ([string]$ExecutablesMap['node']) -FallbackRelativePaths @('node.exe')
    if ($nodeExe) {
        Upsert-ProfileByName -Profiles $kept -Name 'Node' -CommandLine ('"{0}"' -f $nodeExe)
    } else {
        Write-Verbose "Node profile not added (path missing or not found)."
    }

    $pythonExe = Resolve-ExecutablePath -Candidate ([string]$ExecutablesMap['python']) -FallbackRelativePaths @('python.exe', 'python3.exe')
    if ($pythonExe) {
        Upsert-ProfileByName -Profiles $kept -Name 'Python' -CommandLine ('"{0}"' -f $pythonExe)
    } else {
        Write-Verbose "Python profile not added (path missing or not found)."
    }

    # In-place update (same object instance)
    $settingsRoot.profiles.list = @($kept)

    return $SettingsObject
}


# additional functions:
# - disable automatic profile generation (to prevent regenerating deleted profiles):
# "disabledProfileSources": ["Windows.Terminal.Azure", "Windows.Terminal.SSH"]
function Disable-AutomaticProfileGeneration {
    [CmdletBinding()]
    param(
        # input: list of profile sources to disable (e.g., Windows.Terminal.Azure, Windows.Terminal.SSH)
        [Parameter(Mandatory = $true)]
        [Alias('ProfileSourceToDisable')]
        [string[]] $ProfileSourcesToDisable,

        # input: configuration object returned by Get-ExistingTerminalConfiguration (has .Settings), OR
        # the parsed settings.json object returned by ConvertFrom-Json.
        [Parameter(Mandatory = $true)]
        [object] $SettingsObject
        # output: modified SettingsObject (same object instance) with updated "disabledProfileSources" entry
    )

    function Ensure-NoteProperty {
        param(
            [Parameter(Mandatory = $true)][psobject]$Object,
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)]$DefaultValue
        )

        if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
            $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultValue -Force
        } elseif ($null -eq $Object.$Name) {
            $Object.$Name = $DefaultValue
        }
    }

    if (-not $SettingsObject) { throw 'SettingsObject is null (cannot disable automatic profile generation).' }

    # Operate on Settings property when the wrapper is passed.
    $settingsJson = $SettingsObject
    if ($SettingsObject -and ($SettingsObject.PSObject.Properties.Name -contains 'Settings') -and $SettingsObject.Settings) {
        $settingsJson = $SettingsObject.Settings
    }
    if (-not $settingsJson) { throw 'SettingsObject.Settings is null (cannot disable automatic profile generation).' }

    # Some exports wrap the real WT schema in a nested .settings object; support both.
    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    Ensure-NoteProperty -Object $settingsRoot -Name 'disabledProfileSources' -DefaultValue @()

    $existingList = @($settingsRoot.disabledProfileSources)

    # Build a de-duplicated list (case-insensitive) and append requested sources.
    $merged = New-Object System.Collections.ArrayList
    foreach ($src in $existingList) {
        $s = if ($null -eq $src) { $null } else { ([string]$src).Trim() }
        if ([string]::IsNullOrWhiteSpace($s)) { continue }

        $already = $false
        foreach ($e in $merged) {
            if ([string]$e -ieq $s) { $already = $true; break }
        }
        if (-not $already) { [void]$merged.Add($s) }
    }

    foreach ($src in $ProfileSourcesToDisable) {
        $s = if ($null -eq $src) { $null } else { ([string]$src).Trim() }
        if ([string]::IsNullOrWhiteSpace($s)) { continue }

        $already = $false
        foreach ($e in $merged) {
            if ([string]$e -ieq $s) { $already = $true; break }
        }
        if (-not $already) { [void]$merged.Add($s) }
    }

    $settingsRoot.disabledProfileSources = @($merged)
    return $SettingsObject
}


# - define additional color schemes for each profile (git bash, node, python)
# - add color schemes reference to each profile (git bash, node, python)
function Update-TerminalColorSchemes {
    [CmdletBinding()]
    param(
        [PSCustomObject] $Configuration
    )

    if (-not $Configuration) { throw 'Configuration is required (pass the object from Get-ExistingTerminalConfiguration).' }

    # # Load local color scheme provider if available
    # try {
    #     if ($PSScriptRoot) {
    #         $csPath = Join-Path $PSScriptRoot 'color_schemes.psm1'
    #         if (Test-Path -LiteralPath $csPath) { . $csPath }
    #     }
    # } catch {
    #     # continue; fall back to any installed module
    # }

    if (-not (Get-Command -Name Get-TerminalColorSchemes -ErrorAction SilentlyContinue)) {
        try { Import-Module -Name color_schemes -ErrorAction SilentlyContinue } catch {}
    }

    if (-not (Get-Command -Name Get-TerminalColorSchemes -ErrorAction SilentlyContinue)) {
        throw 'Get-TerminalColorSchemes function not found. Ensure color_schemes.psm1 is present.'
    }

    $newSchemes = Get-TerminalColorSchemes

    # Operate on Settings property when the wrapper is passed.
    $settingsJson = $Configuration
    if ($Configuration -and ($Configuration.PSObject.Properties.Name -contains 'Settings') -and $Configuration.Settings) {
        $settingsJson = $Configuration.Settings
    }
    if (-not $settingsJson) { throw 'Configuration.Settings is null (cannot update color schemes).' }

    # Some exports wrap the real WT schema in a nested .settings object; support both.
    $settingsRoot = $settingsJson
    if (($settingsJson.PSObject.Properties.Name -contains 'settings') -and $settingsJson.settings) {
        $settingsRoot = $settingsJson.settings
    }

    function Ensure-NotePropertyLocal {
        param(
            [Parameter(Mandatory = $true)][psobject]$Object,
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)]$DefaultValue
        )

        if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
            $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultValue -Force
        } elseif ($null -eq $Object.$Name) {
            $Object.$Name = $DefaultValue
        }
    }

    Ensure-NotePropertyLocal -Object $settingsRoot -Name 'schemes' -DefaultValue @()

    $existing = @($settingsRoot.schemes)
    $merged = New-Object System.Collections.ArrayList

    foreach ($s in $existing) { [void]$merged.Add($s) }

    foreach ($ns in $newSchemes) {
        $found = $false
        for ($i = 0; $i -lt $merged.Count; $i++) {
            if (([string]$merged[$i].name) -ieq ([string]$ns.name)) {
                $merged[$i] = $ns
                $found = $true
                break
            }
        }
        if (-not $found) { [void]$merged.Add($ns) }
    }

    $settingsRoot.schemes = @($merged)

    return $Configuration
}

# [add to each profile in the list if windows_terminal version is above v1.21]:         
# "showMarksOnScrollbar": true, 
# "autoMarkPrompts": true
# [add to powershell commandline property] "commandline": "... -NoLogo"
<#
  "profiles": {
    "list": [
      {
        "showMarksOnScrollbar": true,
        "autoMarkPrompts": true
      }
    ]}
#>
# [add to each terminal profile the color scheme]
function Update-TerminalProfileAddtionalSettings {
    param(
        [PSCustomObject] $Configuration,
        [hashtable] $ParamsMap  # key-value map to add to each profile
    )

    $windowsTerminalVersion = $null
    try { $windowsTerminalVersion = [version]$Configuration.TerminalVersion } catch { }

    if($windowsTerminalVersion -ge [version]'1.21') {
        # add the additional settings from ParamsMap to each profile in the profiles list
        # ensure that existing settings are not overwritten (only add if the setting does not already exist for the profile)
    }
}


# [add]: "tabWidthMode": "titleLength",
# [add]: "searchWebDefaultQueryUrl": "https://www.google.com/search?q=%22%s%22",
function Add-TerminalAdditionalSettings {
    param(
        [PSCustomObject] $Configuration,
        [hashtable] $ParamsMap  # key-value map to add to global object settings
    )
}


# function that overrides the settings.json with the modified configuration (after manipulation by Update-TerminalProfiles)
function Apply-TerminalConfiguration {
    param(
        [PSCustomObject] $Configuration
    )
}


# https://learn.microsoft.com/en-us/windows/terminal/dynamic-profiles#prevent-a-profile-from-being-generated
# https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration#shell-integration-features

# https://github.com/microsoft/terminal

Export-ModuleMember -Function Resolve-WindowsTerminalSettingsPath, 
Get-ExistingTerminalConfiguration,
Test-TerminalConfigurationRoundTrip,
Update-TerminalProfiles,
Disable-AutomaticProfileGeneration,
Update-TerminalColorSchemes