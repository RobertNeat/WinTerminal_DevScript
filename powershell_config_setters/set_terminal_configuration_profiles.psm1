
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
# [output-param] RawJson: the original file content (string) — mainly for diagnostics
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
        RawJson         = $rawJson
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

# getter for default terminal profiles (Windows Powershell, Command Prompt, Windows.Terminal.Azure)
function Extract-TerminalProfiles-asObject{

}

# manipulate JSON entries:
# - delete the entries that are not CMD, PowerShell
# - add entries for git bash, node, python (if not already present)
# - customize icons, names, color schemes for the entries
function Update-TerminalProfiles {
    param(
        [hashtable] $ExecutablesMap,            # input: list of executables to add (git bash, node, python) aka. ExecutablesMap
        [PSCustomObject]@{}] $settingsObject   # input: settingsObject (parsed JSON as PS object)
        # output: modified settingsObject with updated profiles list (added/modified entries for git bash, node, python; removed entries that are not CMD, PowerShell)
    )

    # to get list of profiles invoke:
    # $settingsObject.settings.profiles.list

    <#
                {
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "experimental.repositionCursorWithMouse": true,
                "font": 
                {
                    "face": "Cascadia Code"
                },
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": false,
                "name": "Windows PowerShell"
            },
            {
                "commandline": "%SystemRoot%\\System32\\cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "hidden": false,
                "name": "Command Prompt"
            },
            {
                "guid": "{b453ae62-4e3d-5e58-b989-0a998ec441b8}",
                "hidden": false,
                "name": "Azure Cloud Shell",
                "source": "Windows.Terminal.Azure"
            }


            {
    "name": "Git Bash",
    "commandline": "C:\\Program Files\\Git\\bin\\bash.exe -li",
    "icon": "C:\\Program Files\\Git\\mingw64\\share\\git\\git-for-windows.ico",
    "startingDirectory": "%USERPROFILE%"
}


    #>


    # temporary inspect if the settingsObject is correctly passed and can be manipulated
    return $ExecutablesMap
}


# additional functions:
# - disable automatic profile generation (to prevent regenerating deleted profiles):
# "disabledProfileSources": ["Windows.Terminal.Azure", "Windows.Terminal.SSH"]
function Disable-AutomaticProfileGeneration {
    param(
        [string[]] $ProfileSourcesToDisable,    # input: list of profile sources to disable (e.g., Windows.Terminal.Azure, Windows.Terminal.SSH)
        [PSCustomObject]@{}] $settingsObject   # input: settingsObject (parsed JSON as PS object)
        # output: modified settingsObject with updated "disabledProfileSources" entry
    )

    # to get list of disabled profile sources invoke:
    # $settingsObject.settings.disabledProfileSources

    # if the entry does not exist, create it with the provided list; if it exists, append the provided sources to the existing list (avoid duplicates)
}


# - define additional color schemes for each profile (git bash, node, python)
# - add color schemes reference to each profile (git bash, node, python)
function Update-TerminalColorSchemes {
    param(
        [PSCustomObject] $Configuration
    )
}

# [add to each profile in the list if windows_terminal version is above v1.21]:         
# "showMarksOnScrollbar": true, 
# "autoMarkPrompts": true
<#
  "profiles": {
    "list": [
      {
        "showMarksOnScrollbar": true,
        "autoMarkPrompts": true
      }
    ]}
#>
function Update-TerminalProfileAddtionalSettings {
    param(
        [PSCustomObject] $Configuration,
        [hashtable] $ParamsMap,  # key-value map to add to each profile
    )

    $windowsTerminalVersion = Configuration.TerminalVersion

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
        [hashtable] $ParamsMap,  # key-value map to add to global object settings
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

Export-ModuleMember -Function Resolve-WindowsTerminalSettingsPath, Get-ExistingTerminalConfiguration, Test-TerminalConfigurationRoundTrip, Update-TerminalProfiles