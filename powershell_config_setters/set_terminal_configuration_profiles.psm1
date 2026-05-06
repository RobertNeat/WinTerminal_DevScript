
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
    param(
        # Preferred: key -> executable path map, e.g. @{ git = '...\bash.exe'; node = '...\node.exe'; python = '...\python.exe' }
        [hashtable] $ExecutablesMap
    )

    
    # input: windows terminal settings path
    # input: list of existing profiles (name + executable)
    # input: list of executables to add (git bash, node, python)
    # setts: json and saves it to file overriding the existing one
    # output: key-value pairs for profile_name -> executable_path

    # https://learn.microsoft.com/en-us/windows/terminal/dynamic-profiles#prevent-a-profile-from-being-generated
    # https://learn.microsoft.com/en-us/windows/terminal/tutorials/shell-integration#shell-integration-features

    # https://github.com/microsoft/terminal

    # NOTE: profile editing is not implemented yet; return normalized inputs for now.
    return $ExecutablesMap
}

Export-ModuleMember -Function Resolve-WindowsTerminalSettingsPath, Update-TerminalProfiles