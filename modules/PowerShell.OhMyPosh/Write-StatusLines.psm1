# Writes prepared status lines to the host.
# [input-param] Lines: status lines to write
# [output-param] None.
# [side-effect] Writes text to the current PowerShell host.
function Write-StatusLines {
    param(
        [string[]] $Lines
    )

    foreach ($line in $Lines) {
        Write-Host $line
    }
}

Export-ModuleMember -Function Write-StatusLines
