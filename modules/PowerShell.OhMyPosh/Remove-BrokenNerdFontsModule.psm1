# Removes installed NerdFonts module version directories when the module cannot be imported.
# [output-param] None.
# [side-effect] Deletes only discovered NerdFonts version directories from PowerShell module paths.
function Remove-BrokenNerdFontsModule {
    $installedModules = @(Get-Module -ListAvailable -Name NerdFonts)
    foreach ($installedModule in $installedModules) {
        if (-not $installedModule.Path) { continue }

        $versionDirectory = Split-Path -Parent $installedModule.Path
        $moduleDirectory = Split-Path -Parent $versionDirectory

        if ((Split-Path -Leaf $moduleDirectory) -ne 'NerdFonts') { continue }
        if (-not (Test-Path -LiteralPath $versionDirectory)) { continue }

        Remove-Item -LiteralPath $versionDirectory -Recurse -Force -ErrorAction Stop
    }

    Remove-Module -Name NerdFonts -Force -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Remove-BrokenNerdFontsModule
