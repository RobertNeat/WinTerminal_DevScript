Import-Module ".\modules\PowerShell.OhMyPosh\Invoke-ConsoleSpinnerCommand.psm1" -ErrorAction Stop

# Installs or upgrades Oh My Posh using winget.
# [output-param] PSCustomObject: package id, winget action, and winget exit code
# [side-effect] Runs winget install or winget upgrade for the Oh My Posh package.
function Install-OhMyPosh {
    param(
        [string] $PackageId = 'JanDeDobbeleer.OhMyPosh'
    )

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'winget is required to install Oh My Posh.'
    }

    & winget list --id $PackageId --source winget --exact | Out-Null
    $isInstalled = ($LASTEXITCODE -eq 0)

    if ($isInstalled) {
        $result = Invoke-ConsoleSpinnerCommand `
            -FilePath $winget.Source `
            -ArgumentList @('upgrade', $PackageId, '--source', 'winget') `
            -Message 'Installing Oh My Posh'
        $action = 'upgrade'
    } else {
        $result = Invoke-ConsoleSpinnerCommand `
            -FilePath $winget.Source `
            -ArgumentList @('install', $PackageId, '--source', 'winget') `
            -Message 'Installing Oh My Posh'
        $action = 'install'
    }

    $exitCode = $result.ExitCode
    $originalExitCode = $result.ExitCode
    $status = 'completed'

    if ($action -eq 'upgrade' -and $result.ExitCode -ne 0) {
        $ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
        if ($ohMyPosh) {
            Write-Host 'Oh My Posh is already installed. winget did not install a newer version.'
            $exitCode = 0
            $status = 'already-current-or-installed'
        }
    }

    [PSCustomObject]@{
        PackageId        = $PackageId
        Action           = $action
        Status           = $status
        ExitCode         = $exitCode
        OriginalExitCode = $originalExitCode
    }
}

Export-ModuleMember -Function Install-OhMyPosh
