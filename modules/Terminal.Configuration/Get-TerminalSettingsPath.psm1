# Finds the path to the Windows Terminal settings.json file.
# [input-param] SettingsPath: optional explicit path to settings.json, which will be validated
# [output-param] string: full path to an existing settings.json file
# [side-effect] Reads LOCALAPPDATA, the Appx package list, and Windows Terminal package directories.
function Get-TerminalSettingsPath {
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

    # Adds a unique candidate path to the search list.
    # [input-param] Path: settings.json path to add when it is not empty and has not been seen before
    # [side-effect] Modifies the parent function's local candidates and seen collections.
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


Export-ModuleMember -Function Get-TerminalSettingsPath
