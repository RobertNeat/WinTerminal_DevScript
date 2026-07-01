Import-Module (Join-Path $PSScriptRoot 'Invoke-ConsoleSpinnerCommand.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\Terminal.UI\Request-SetupTerminalConsent.psm1') -ErrorAction Stop

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

    $isInstalled = [bool](Get-Command oh-my-posh -ErrorAction SilentlyContinue)

    if ($isInstalled) {
        $approved = Request-SetupTerminalConsent `
            -Title 'Upgrade Oh My Posh with winget' `
            -Description "winget will contact the winget source and may download an installer for package '$PackageId'." `
            -Sources @('winget source: winget', "package id: $PackageId") `
            -Consequence 'Oh My Posh may be upgraded on this computer.' `
            -DefaultNo
        if (-not $approved) {
            return [PSCustomObject]@{
                PackageId        = $PackageId
                Action           = 'upgrade'
                Status           = 'skipped-by-user'
                ExitCode         = 0
                OriginalExitCode = 0
            }
        }

        $result = Invoke-ConsoleSpinnerCommand `
            -FilePath $winget.Source `
            -ArgumentList @('upgrade', $PackageId, '--source', 'winget') `
            -Message 'Installing Oh My Posh'
        $action = 'upgrade'
    } else {
        $approved = Request-SetupTerminalConsent `
            -Title 'Install Oh My Posh with winget' `
            -Description "winget will contact the winget source and download/install package '$PackageId'." `
            -Sources @('winget source: winget', "package id: $PackageId") `
            -Consequence 'Oh My Posh will be installed on this computer.' `
            -DefaultNo
        if (-not $approved) {
            return [PSCustomObject]@{
                PackageId        = $PackageId
                Action           = 'install'
                Status           = 'skipped-by-user'
                ExitCode         = 0
                OriginalExitCode = 0
            }
        }

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
