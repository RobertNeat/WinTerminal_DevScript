# Sets performance-oriented options in an Oh My Posh theme file.
# [input-param] Path: full path to an Oh My Posh theme JSON file
# [output-param] None.
# [side-effect] Updates the theme JSON file in place.
function Set-OhMyPoshThemePerformanceOptions {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    # Windows PowerShell 5.1 otherwise treats UTF-8 files without a BOM as the
    # active ANSI code page and corrupts Nerd Font glyphs on the next setup run.
    $theme = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($block in $theme.blocks) {
        foreach ($segment in $block.segments) {
            if ($segment.type -eq 'git') {
                if (-not $segment.options) {
                    $segment | Add-Member -MemberType NoteProperty -Name options -Value ([pscustomobject]@{})
                }

                if ($segment.options.PSObject.Properties.Name -contains 'fetch_upstream_icon') {
                    $segment.options.fetch_upstream_icon = $false
                } else {
                    $segment.options | Add-Member -MemberType NoteProperty -Name fetch_upstream_icon -Value $false
                }
            }
        }
    }

    # Windows PowerShell 5.1 writes a BOM when Set-Content -Encoding UTF8 is used.
    # Oh My Posh 30.6.5 rejects that BOM before parsing the JSON configuration.
    $themeJson = $theme | ConvertTo-Json -Depth 100
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $themeJson + [Environment]::NewLine, $utf8WithoutBom)
}

Export-ModuleMember -Function Set-OhMyPoshThemePerformanceOptions
