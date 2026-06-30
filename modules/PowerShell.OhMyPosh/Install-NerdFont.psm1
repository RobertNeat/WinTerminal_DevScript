# Installs a Nerd Font through the NerdFonts PowerShell module.
# [input-param] FontName: NerdFonts module font name to install
# [input-param] Scope: install scope passed to NerdFonts; AllUsers requires elevation
# [output-param] PSCustomObject: font name, scope, and installation status
# [side-effect] Installs the NerdFonts PowerShell resource when missing and installs the requested Nerd Font.
function Install-NerdFont {
    param(
        [string] $FontName = 'FiraCode',

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'AllUsers'
    )

    function Test-CurrentProcessAdministrator {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function New-NerdFontInstallScript {
        param(
            [string] $Name,
            [string] $InstallScope
        )

        $escapedName = $Name -replace "'", "''"
        $escapedScope = $InstallScope -replace "'", "''"

        return @"
`$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        throw 'Install-PSResource or Install-Module is required to install the NerdFonts module.'
    }

    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -AllowClobber
    Import-Module Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
}

if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
    Install-PSResource -Name NerdFonts -Scope CurrentUser -TrustRepository -Reinstall
}

Import-Module -Name NerdFonts -ErrorAction Stop
NerdFonts\Install-NerdFont -Name '$escapedName' -Scope '$escapedScope'
"@
    }

    $isAdministrator = Test-CurrentProcessAdministrator
    $needsElevation = ($Scope -eq 'AllUsers' -and -not $isAdministrator)

    if ($needsElevation) {
        $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ('Install-NerdFont-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
        $script = New-NerdFontInstallScript -Name $FontName -InstallScope $Scope
        Set-Content -LiteralPath $scriptPath -Value $script -Encoding UTF8

        $uacAccepted = $true
        $fallbackToCurrentUser = $false

        try {
            Write-Host "Installing Nerd Font $FontName for all users. Approve the elevation prompt to continue."
            $process = Start-Process `
                -FilePath powershell.exe `
                -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) `
                -Verb RunAs `
                -PassThru

            $frames = @('\', '|', '/', '-')
            $frameIndex = 0
            while (-not $process.HasExited) {
                Write-Host ("`rInstalling Nerd Font {0} {1}" -f $FontName, $frames[$frameIndex]) -NoNewline
                $frameIndex = ($frameIndex + 1) % $frames.Count
                Start-Sleep -Milliseconds 120
            }

            $process.WaitForExit()
            Write-Host ("`rInstalling Nerd Font {0} done" -f $FontName)
            $exitCode = $process.ExitCode
            if ($exitCode -ne 0) {
                Write-Host "AllUsers Nerd Font installation failed. Installing for the current user instead."
                $fallbackToCurrentUser = $true
            }
        } catch {
            $uacAccepted = $false
            Write-Host "Elevation was cancelled or failed. Installing Nerd Font $FontName for the current user instead."
        } finally {
            if (Test-Path -LiteralPath $scriptPath) {
                Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
            }
        }

        if ((-not $uacAccepted) -or $fallbackToCurrentUser) {
            Write-Host "Installing Nerd Font $FontName with scope CurrentUser"
            $scriptBlock = [scriptblock]::Create((New-NerdFontInstallScript -Name $FontName -InstallScope 'CurrentUser'))
            & $scriptBlock
            $Scope = 'CurrentUser'
            $exitCode = 0
        }
    } else {
        Write-Host "Installing Nerd Font $FontName with scope $Scope"
        $scriptBlock = [scriptblock]::Create((New-NerdFontInstallScript -Name $FontName -InstallScope $Scope))
        & $scriptBlock
        $exitCode = 0
    }

    $status = if ($exitCode -eq 0) { 'installed' } else { 'failed' }

    [PSCustomObject]@{
        FontName = $FontName
        Scope    = $Scope
        Status   = $status
        ExitCode = $exitCode
    }
}

Export-ModuleMember -Function Install-NerdFont
