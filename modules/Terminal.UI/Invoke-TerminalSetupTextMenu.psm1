Import-Module (Join-Path $PSScriptRoot 'Select-TerminalSetupOptionsFromText.psm1') -ErrorAction Stop

# Opens the non-interactive Windows Terminal setup menu and returns the user's text selection.
# [input-param] InitialInfoLines: optional system information lines displayed above the menu.
# [input-param] ProfileOptions: selectable developer profile options.
# [input-param] StepOptions: selectable setup step options.
# [output-param] PSCustomObject: Applied flag plus selected Profiles and Steps arrays when applied; Applied=false when cancelled.
# [side-effect] Writes menu text to the current host and reads profile/step choices with Read-Host.
function Invoke-TerminalSetupTextMenu {
    param(
        [string[]] $InitialInfoLines = @(),
        [object[]] $ProfileOptions,
        [object[]] $StepOptions
    )

    Clear-Host
    Write-Host "Windows Terminal setup"
    Write-Host "Interactive TUI is unavailable in this host. Using text input mode."
    Write-Host ""

    if ($InitialInfoLines.Count -gt 0) {
        foreach ($line in $InitialInfoLines) {
            Write-Host $line
        }
        Write-Host ""
    }

    Write-Host "Profiles to configure:"
    $profileChoiceMap = @{}
    for ($i = 0; $i -lt $ProfileOptions.Count; $i++) {
        $choice = [string]($i + 1)
        $profileChoiceMap[$choice] = $ProfileOptions[$i].Key
        Write-Host (" {0}) {1}" -f $choice, $ProfileOptions[$i].Label)
    }

    Write-Host ""
    Write-Host "Steps to run:"
    $stepChoiceMap = @{}
    for ($i = 0; $i -lt $StepOptions.Count; $i++) {
        $choice = [string][char]([int][char]'a' + $i)
        $stepChoiceMap[$choice] = $StepOptions[$i].Key
        Write-Host (" {0}) {1}" -f $choice, $StepOptions[$i].Label)
    }

    Write-Host ""
    Write-Host "Type combined choices without separators, for example:"
    Write-Host " profiles: 134 = git, node, java"
    Write-Host " steps: abc = first three setup steps"
    Write-Host ""

    $profilesApplied = Select-TerminalSetupOptionsFromText `
        -Options $ProfileOptions `
        -ChoiceMap $profileChoiceMap `
        -Prompt "Select profiles [1-4] (Enter = all, q = cancel)" `
        -AllChoicesText "1-4"

    if (-not $profilesApplied) {
        return [PSCustomObject]@{ Applied = $false }
    }

    $stepsApplied = Select-TerminalSetupOptionsFromText `
        -Options $StepOptions `
        -ChoiceMap $stepChoiceMap `
        -Prompt "Select steps [a-g] (Enter = all, q = cancel)" `
        -AllChoicesText "a-g"

    if (-not $stepsApplied) {
        return [PSCustomObject]@{ Applied = $false }
    }

    return [PSCustomObject]@{
        Applied  = $true
        Profiles = @($ProfileOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
        Steps    = @($StepOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
    }
}

Export-ModuleMember -Function Invoke-TerminalSetupTextMenu
