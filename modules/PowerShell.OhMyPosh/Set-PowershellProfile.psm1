# Writes the current user's PowerShell profiles so each new PowerShell window starts Oh My Posh and daily status output.
# [input-param] ThemePath: full Oh My Posh theme path to use in the profile
# [output-param] PSCustomObject[]: profile paths that were created or updated
# [side-effect] Creates or updates current-user Windows PowerShell and PowerShell profile files.
function Set-PowershellProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ThemePath
    )

    if (-not (Test-Path -LiteralPath $ThemePath -PathType Leaf)) {
        throw "ThemePath does not point to an existing file: $ThemePath"
    }

    function ConvertTo-SingleQuotedPowerShellLiteral {
        param([string] $Value)
        return "'" + ($Value -replace "'", "''") + "'"
    }

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $profilePaths = @(
        (Join-Path $documentsPath 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $documentsPath 'PowerShell\Microsoft.PowerShell_profile.ps1')
    )

    $beginMarker = '# BEGIN Setup-Terminal Oh My Posh'
    $endMarker = '# END Setup-Terminal Oh My Posh'
    $themeLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $ThemePath
    $dailyStatusModuleLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value (Join-Path $PSScriptRoot 'Get-DailySystemStatus.psm1')
    $interactiveProfileModuleLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value (Join-Path $PSScriptRoot 'Test-SetupTerminalInteractiveProfile.psm1')

    $profileBlock = @"
$beginMarker
`$setupTerminalOhMyPoshTheme = $themeLiteral
Import-Module $dailyStatusModuleLiteral -Force -ErrorAction Stop
Import-Module $interactiveProfileModuleLiteral -Force -ErrorAction Stop

if (Test-SetupTerminalInteractiveProfile) {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config `$setupTerminalOhMyPoshTheme | Invoke-Expression
    }

    Get-DailySystemStatus
}
$endMarker
"@

    function Remove-SetupTerminalProfileBlocks {
        param(
            [string] $Content,
            [string] $BeginMarker,
            [string] $EndMarker
        )

        if ([string]::IsNullOrWhiteSpace($Content)) {
            return ''
        }

        $lines = $Content -split "\r?\n"
        $keptLines = New-Object System.Collections.Generic.List[string]
        $insideManagedBlock = $false

        foreach ($line in $lines) {
            if ($line -like "*$BeginMarker*") {
                $insideManagedBlock = $true
                continue
            }

            if ($insideManagedBlock) {
                if ($line -like "*$EndMarker*") {
                    $insideManagedBlock = $false
                }
                continue
            }

            $keptLines.Add($line)
        }

        return (($keptLines.ToArray() -join "`r`n").TrimEnd())
    }

    function Test-PowerShellContent {
        param([string] $Content)

        if ([string]::IsNullOrWhiteSpace($Content)) {
            return $true
        }

        $tokens = $null
        $errors = $null
        [void] [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref] $tokens, [ref] $errors)

        return (-not $errors -or $errors.Count -eq 0)
    }

    $updatedProfiles = @()

    foreach ($profilePath in $profilePaths) {
        $profileDirectory = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
        }

        $existingContent = ''
        if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
            $existingContent = Get-Content -LiteralPath $profilePath -Raw
        }

        $unmanagedContent = Remove-SetupTerminalProfileBlocks `
            -Content $existingContent `
            -BeginMarker $beginMarker `
            -EndMarker $endMarker

        if (-not (Test-PowerShellContent -Content $unmanagedContent)) {
            $backupPath = '{0}.broken-{1}.bak' -f $profilePath, (Get-Date -Format 'yyyyMMddHHmmss')
            Copy-Item -LiteralPath $profilePath -Destination $backupPath -Force
            $unmanagedContent = ''
        }

        $separator = if ([string]::IsNullOrWhiteSpace($unmanagedContent)) { '' } else { "`r`n`r`n" }
        $newContent = $unmanagedContent + $separator + $profileBlock + "`r`n"

        Set-Content -LiteralPath $profilePath -Value $newContent -Encoding UTF8
        $updatedProfiles += [PSCustomObject]@{ ProfilePath = $profilePath }
    }

    return $updatedProfiles
}

Export-ModuleMember -Function Set-PowershellProfile
