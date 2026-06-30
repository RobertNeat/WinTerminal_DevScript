# Tests whether the NerdFonts module can be imported and exposes the expected installer command.
# [output-param] Boolean: true when NerdFonts\Install-NerdFont is available
# [side-effect] Imports or removes the NerdFonts module in the current session.
function Test-NerdFontsModuleReady {
    try {
        Import-Module -Name NerdFonts -Force -ErrorAction Stop
        return [bool](Get-Command -Name 'NerdFonts\Install-NerdFont' -ErrorAction Stop)
    } catch {
        Remove-Module -Name NerdFonts -Force -ErrorAction SilentlyContinue
        return $false
    }
}

Export-ModuleMember -Function Test-NerdFontsModuleReady
