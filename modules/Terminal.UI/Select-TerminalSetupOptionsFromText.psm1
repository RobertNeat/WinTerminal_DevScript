# Reads and applies a compact text selection for setup options.
# [input-param] Options: selectable setup option objects with Key and Selected fields.
# [input-param] ChoiceMap: maps user-facing single-character choices to setup option keys.
# [input-param] Prompt: text displayed by Read-Host while asking for choices.
# [input-param] AllChoicesText: short description of valid choices shown in validation errors.
# [output-param] Boolean: true when choices were applied; false when the user cancelled with q.
# [side-effect] Reads text input from the host and mutates the Selected field on Options.
function Select-TerminalSetupOptionsFromText {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Options,

        [Parameter(Mandatory = $true)]
        [hashtable] $ChoiceMap,

        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [Parameter(Mandatory = $true)]
        [string] $AllChoicesText
    )

    while ($true) {
        $answer = Read-Host $Prompt
        $normalizedAnswer = if ($null -eq $answer) { '' } else { $answer.Trim().ToLowerInvariant() }

        if ($normalizedAnswer -eq 'q') {
            return $false
        }

        foreach ($option in $Options) {
            $option.Selected = [string]::IsNullOrWhiteSpace($normalizedAnswer)
        }

        if ([string]::IsNullOrWhiteSpace($normalizedAnswer)) {
            return $true
        }

        $invalidChoices = New-Object System.Collections.Generic.List[string]
        foreach ($choice in $normalizedAnswer.ToCharArray()) {
            $choiceText = [string]$choice
            if (-not $ChoiceMap.ContainsKey($choiceText)) {
                [void]$invalidChoices.Add($choiceText)
                continue
            }

            $selectedKey = $ChoiceMap[$choiceText]
            foreach ($option in $Options) {
                if ($option.Key -eq $selectedKey) {
                    $option.Selected = $true
                    break
                }
            }
        }

        if ($invalidChoices.Count -eq 0) {
            return $true
        }

        Write-Host ("Invalid choice(s): {0}. Use {1}, press Enter for all, or q to cancel." -f (($invalidChoices | Select-Object -Unique) -join ', '), $AllChoicesText) -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Select-TerminalSetupOptionsFromText
