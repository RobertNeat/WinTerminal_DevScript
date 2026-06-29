# Writes a single terminal menu row, optionally highlighted as the active row.
# [input-param] Text: line text to write to the console
# [input-param] Active: when true, writes the line using inverse-like console colors
# [output-param] None.
# [side-effect] Writes to the host console.
function Write-TerminalSetupMenuLine {
    param(
        [string] $Text,
        [bool] $Active = $false
    )

    if ($Active) {
        Write-Host $Text -ForegroundColor Black -BackgroundColor Gray
    } else {
        Write-Host $Text
    }
}

Export-ModuleMember -Function Write-TerminalSetupMenuLine
