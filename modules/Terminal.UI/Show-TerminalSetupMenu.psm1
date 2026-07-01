Import-Module (Join-Path $PSScriptRoot 'Write-TerminalSetupMenuLine.psm1') -ErrorAction Stop

# Renders the Windows Terminal setup selection menu.
# [input-param] ProfileOptions: selectable developer profile options
# [input-param] StepOptions: selectable setup step options
# [input-param] Items: flattened options list used to resolve the active cursor position
# [input-param] Cursor: zero-based index of the active option row in Items
# [input-param] ActionCursor: zero-based index of the active action button; 0 is Apply, 1 is Cancel
# [input-param] IsActionRow: when true, highlights the action button row instead of an option row
# [input-param] InitialInfoLines: optional system information lines displayed above the menu
# [output-param] None.
# [side-effect] Clears and redraws the host console.
function Show-TerminalSetupMenu {
    param(
        [string[]] $InitialInfoLines = @(),
        [object[]] $ProfileOptions,
        [object[]] $StepOptions,
        [object[]] $Items,
        [int] $Cursor,
        [int] $ActionCursor,
        [bool] $IsActionRow
    )

    Clear-Host
    Write-Host "Windows Terminal setup"
    Write-Host "Use Up/Down arrows to move, Space/Enter to toggle, Enter on Apply/Cancel to finish, Esc to cancel."
    Write-Host ""

    if ($InitialInfoLines.Count -gt 0) {
        foreach ($line in $InitialInfoLines) {
            Write-Host $line
        }
        Write-Host ""
    }

    Write-Host "Profiles to configure:"

    for ($i = 0; $i -lt $ProfileOptions.Count; $i++) {
        $option = $ProfileOptions[$i]
        $index = [array]::IndexOf($Items, $option)
        $mark = if ($option.Selected) { 'X' } else { ' ' }
        Write-TerminalSetupMenuLine -Text ("[{0}] {1}" -f $mark, $option.Label) -Active ((-not $IsActionRow) -and $Cursor -eq $index)
    }

    Write-Host ""
    Write-Host "Steps to run:"

    for ($i = 0; $i -lt $StepOptions.Count; $i++) {
        $option = $StepOptions[$i]
        $index = [array]::IndexOf($Items, $option)
        $mark = if ($option.Selected) { 'X' } else { ' ' }
        Write-TerminalSetupMenuLine -Text ("[{0}] {1}" -f $mark, $option.Label) -Active ((-not $IsActionRow) -and $Cursor -eq $index)
    }

    Write-Host ""
    $applyText = if ($IsActionRow -and $ActionCursor -eq 0) { '> [Apply]' } else { '  [Apply]' }
    $cancelText = if ($IsActionRow -and $ActionCursor -eq 1) { '> [Cancel]' } else { '  [Cancel]' }

    if ($IsActionRow -and $ActionCursor -eq 0) {
        Write-Host $applyText -NoNewline -ForegroundColor Black -BackgroundColor Gray
    } else {
        Write-Host $applyText -NoNewline
    }

    Write-Host " " -NoNewline

    if ($IsActionRow -and $ActionCursor -eq 1) {
        Write-Host $cancelText -ForegroundColor Black -BackgroundColor Gray
    } else {
        Write-Host $cancelText
    }
}

Export-ModuleMember -Function Show-TerminalSetupMenu
