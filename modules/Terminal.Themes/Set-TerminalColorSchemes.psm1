Import-Module ".\modules\Utils\Initialize-NoteProperty.psm1"
Import-Module ".\modules\Terminal.Themes\Get-TerminalColorSchemes.psm1"

# - define additional color schemes for each profile (git bash, node, python)
# - add color schemes reference to each profile (git bash, node, python)
function Set-TerminalColorSchemes {
    [CmdletBinding()]
    param(
        [PSCustomObject] $Configuration
    )

    if (-not $Configuration) { throw 'Configuration is required (pass the object from Get-TerminalConfiguration).' }

    # # Load local color scheme provider if available
    # try {
    #     if ($PSScriptRoot) {
    #         $csPath = Join-Path $PSScriptRoot 'Get-TerminalColorSchemes.psm1'
    #         if (Test-Path -LiteralPath $csPath) { . $csPath }
    #     }
    # } catch {
    #     # continue; fall back to any installed module
    # }

    if (-not (Get-Command -Name Get-TerminalColorSchemes -ErrorAction SilentlyContinue)) {
        try { Import-Module -Name Get-TerminalColorSchemes -ErrorAction SilentlyContinue } catch {}
    }

    if (-not (Get-Command -Name Get-TerminalColorSchemes -ErrorAction SilentlyContinue)) {
        throw 'Get-TerminalColorSchemes function not found. Ensure Get-TerminalColorSchemes.psm1 is present.'
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



    Initialize-NoteProperty -Object $settingsRoot -Name 'schemes' -DefaultValue @()

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

Export-ModuleMember -Function Set-TerminalColorSchemes