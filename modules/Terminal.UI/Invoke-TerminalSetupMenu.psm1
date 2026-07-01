Import-Module ".\modules\Terminal.UI\New-TerminalSetupOption.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.UI\Show-TerminalSetupMenu.psm1" -ErrorAction Stop

# Opens the interactive Windows Terminal setup menu and returns the user's selection.
# [output-param] PSCustomObject: Applied flag plus selected Profiles and Steps arrays when applied; Applied=false when cancelled
# [side-effect] Reads keyboard input from the console and redraws the host console until Apply, Cancel, or Escape is selected.
function Invoke-TerminalSetupMenu {
    param(
        [string[]] $InitialInfoLines = @()
    )

    $profileOptions = @(
        New-TerminalSetupOption -Key 'git' -Label 'git' -Group 'Profile'
        New-TerminalSetupOption -Key 'python' -Label 'python' -Group 'Profile'
        New-TerminalSetupOption -Key 'node' -Label 'node' -Group 'Profile'
        New-TerminalSetupOption -Key 'java' -Label 'java' -Group 'Profile'
    )

    $stepOptions = @(
        New-TerminalSetupOption -Key 'profiles' -Label 'Update Windows Terminal profiles (+ profile icons)' -Group 'Step'
        New-TerminalSetupOption -Key 'removeOtherProfiles' -Label 'Remove profiles outside Windows PowerShell and Command Prompt' -Group 'Step'
        New-TerminalSetupOption -Key 'dynamicProfiles' -Label 'Disable selected dynamic profile sources (Azure, SSH)' -Group 'Step'
        New-TerminalSetupOption -Key 'colorSchemes' -Label 'Apply profiles color schemes' -Group 'Step'
        New-TerminalSetupOption -Key 'profileSettings' -Label 'Apply additional profile settings (showMarksOnScrollbar, autoMarkPrompts, PowerShell -NoLogo)' -Group 'Step'
        New-TerminalSetupOption -Key 'terminalSettings' -Label 'Apply additional terminal settings (tabWidthMode, searchWebDefaultQueryUrl)' -Group 'Step'
        New-TerminalSetupOption -Key 'ohMyPosh' -Label 'Install/configure Oh My Posh (requires approved internet downloads)' -Group 'Step'
    )

    $items = @($profileOptions + $stepOptions)
    $cursor = 0
    $actionCursor = 0
    $isActionRow = $false

    while ($true) {
        Show-TerminalSetupMenu `
            -InitialInfoLines $InitialInfoLines `
            -ProfileOptions $profileOptions `
            -StepOptions $stepOptions `
            -Items $items `
            -Cursor $cursor `
            -ActionCursor $actionCursor `
            -IsActionRow $isActionRow

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                if ($isActionRow) {
                    $isActionRow = $false
                    $cursor = $items.Count - 1
                } elseif ($cursor -gt 0) {
                    $cursor--
                }
            }
            'DownArrow' {
                if ($isActionRow) {
                    continue
                } elseif ($cursor -lt ($items.Count - 1)) {
                    $cursor++
                } else {
                    $isActionRow = $true
                }
            }
            'LeftArrow' {
                if ($isActionRow) { $actionCursor = 0 }
            }
            'RightArrow' {
                if ($isActionRow) { $actionCursor = 1 }
            }
            'Spacebar' {
                if (-not $isActionRow) {
                    $items[$cursor].Selected = -not $items[$cursor].Selected
                }
            }
            'Enter' {
                if ($isActionRow) {
                    Clear-Host
                    if ($actionCursor -eq 1) {
                        return [PSCustomObject]@{ Applied = $false }
                    }

                    return [PSCustomObject]@{
                        Applied  = $true
                        Profiles = @($profileOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
                        Steps    = @($stepOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
                    }
                }

                $items[$cursor].Selected = -not $items[$cursor].Selected
            }
            'Escape' {
                Clear-Host
                return [PSCustomObject]@{ Applied = $false }
            }
        }
    }
}

Export-ModuleMember -Function Invoke-TerminalSetupMenu
