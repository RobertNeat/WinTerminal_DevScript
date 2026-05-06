
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

    # 1) Best: discover installed package family name(s) dynamically
    try {
        $pkgs = Get-AppxPackage -Name "Microsoft.WindowsTerminal*" -ErrorAction Stop
        foreach ($pkg in $pkgs) {
            if (-not $pkg.PackageFamilyName) { continue }
            $candidates.Add((Join-Path $env:LOCALAPPDATA ("Packages\{0}\LocalState\settings.json" -f $pkg.PackageFamilyName)))
        }
    } catch {
        # ignore (e.g., Get-AppxPackage unavailable)
    }

    # 2) Common stable family names (fallback)
    $knownFamilies = @(
        "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
        "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe"
    )
    foreach ($family in $knownFamilies) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA ("Packages\{0}\LocalState\settings.json" -f $family)))
    }

    # 3) Unpackaged/fallback location (sometimes used by non-Store installs)
    $candidates.Add((Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"))

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

# The path for your Windows Terminal settings.json file may be found in one of the following directories:
# Terminal (stable / general release): %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
# Terminal (preview release): %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json
# Terminal (unpackaged: Scoop, Chocolatey, etc): %LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json

# ^ Need to check if the function Resolve-WindowsTerminalSettingsPath takes under consideration that informations (if not then it needs to be refactored)


# search through the JSON configurations for existing profiles (name + executable)
function Get-ExistingTerminalProfiles {
    # input: windows terminal settings path
    # output: list of existing profiles

    # getting windows terminal version so we will have proper version of json to parse
    # aka. ensure that JSON is deterministic and has expected structure (e.g., "profiles->list" section)
    # Get-AppxPackage Microsoft.WindowsTerminal
}

# manipulate JSON entries:
# - delete the entries that are not CMD, PowerShell
# - add entries for git bash, node, python (if not already present)
# - customize icons, names, color schemes for the entries
function Update-TerminalProfiles {
    # input: windows terminal settings path
    # input: list of existing profiles (name + executable)
    # input: list of executables to add (git bash, node, python)
    # setts: json and saves it to file overriding the existing one
    # output: key-value pairs for profile_name -> executable_path

    # https://learn.microsoft.com/en-us/windows/terminal/dynamic-profiles#prevent-a-profile-from-being-generated
    # https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration#shell-integration-features

    # https://github.com/microsoft/terminal
}


Export-ModuleMember -Function Resolve-WindowsTerminalSettingsPath