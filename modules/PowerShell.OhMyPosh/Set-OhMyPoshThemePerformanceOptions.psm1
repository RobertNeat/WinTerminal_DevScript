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

    $theme = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

    $theme | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

Export-ModuleMember -Function Set-OhMyPoshThemePerformanceOptions
