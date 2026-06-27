# Get Windows Terminal version by checking installed Appx packages and wt.exe file version as a fallback.
function Get-TerminalVersion {
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

Export-ModuleMember -Function Get-TerminalVersion