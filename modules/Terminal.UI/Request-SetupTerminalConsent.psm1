# Requests explicit consent for a setup action that downloads or installs external resources.
# [input-param] Title: short action title shown to the user
# [input-param] Description: action summary shown to the user
# [input-param] Sources: external URLs, package ids, or repositories involved in the action
# [input-param] Consequence: local system change that will happen if the user approves
# [input-param] DefaultNo: when set, empty input is treated as denial
# [output-param] Boolean: true when the user explicitly approves the action with y or yes
# [side-effect] Writes a confirmation prompt to the current PowerShell host and reads keyboard input.
function Request-SetupTerminalConsent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [string] $Description,

        [string[]] $Sources = @(),

        [string] $Consequence = '',

        [switch] $DefaultNo
    )

    Write-Host ''
    Write-Host 'External resource approval required' -ForegroundColor Yellow
    Write-Host ('Action: {0}' -f $Title)
    Write-Host ('Details: {0}' -f $Description)

    if ($Sources.Count -gt 0) {
        Write-Host 'Sources:'
        foreach ($source in $Sources) {
            Write-Host (' - {0}' -f $source)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Consequence)) {
        Write-Host ('Local change: {0}' -f $Consequence)
    }

    $prompt = if ($DefaultNo) { 'Continue? [y/N]' } else { 'Continue? [y/N]' }
    $answer = Read-Host $prompt
    return ($answer -match '^(?i:y|yes)$')
}

Export-ModuleMember -Function Request-SetupTerminalConsent
