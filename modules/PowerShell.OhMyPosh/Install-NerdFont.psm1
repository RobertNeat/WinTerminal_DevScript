Import-Module "$PSScriptRoot\Test-NerdFontInstalled.psm1" -ErrorAction Stop

# Installs a Nerd Font through NerdFonts or the official Nerd Fonts archive fallback.
# [input-param] FontName: NerdFonts module/archive font name to install
# [input-param] FontFace: expected Windows font face name used by Windows Terminal
# [input-param] Scope: install scope; AllUsers requires elevation
# [output-param] PSCustomObject: font name, font face, scope, installation status, and exit code
# [side-effect] Installs PowerShell helper modules when missing and installs the requested Nerd Font.
function Install-NerdFont {
    param(
        [string] $FontName = 'FiraCode',

        [string] $FontFace = 'FiraCode Nerd Font',

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'AllUsers'
    )

    function Test-CurrentProcessAdministrator {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function ConvertTo-SingleQuotedPowerShellLiteral {
        param([string] $Value)
        return "'" + ($Value -replace "'", "''") + "'"
    }

    function New-NerdFontInstallScript {
        param(
            [string] $Name,
            [string] $ExpectedFontFace,
            [string] $InstallScope,
            [string] $ModuleDirectory
        )

        $nameLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $Name
        $fontFaceLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $ExpectedFontFace
        $scopeLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $InstallScope
        $moduleDirectoryLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $ModuleDirectory

        return @"
`$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

`$moduleDirectory = $moduleDirectoryLiteral
Import-Module (Join-Path `$moduleDirectory 'Test-NerdFontInstalled.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path `$moduleDirectory 'Test-NerdFontsModuleReady.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path `$moduleDirectory 'Remove-BrokenNerdFontsModule.psm1') -Force -ErrorAction Stop
Import-Module (Join-Path `$moduleDirectory 'Install-NerdFontFromArchive.psm1') -Force -ErrorAction Stop

if (-not (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        throw 'Install-PSResource or Install-Module is required to install the NerdFonts module.'
    }

    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -AllowClobber
    Import-Module Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
}

`$canUseNerdFontsModule = Test-NerdFontsModuleReady
if (-not `$canUseNerdFontsModule) {
    try {
        Remove-BrokenNerdFontsModule
        Install-PSResource -Name NerdFonts -Scope CurrentUser -TrustRepository -Reinstall -ErrorAction Stop
        `$canUseNerdFontsModule = Test-NerdFontsModuleReady
    } catch {
        `$canUseNerdFontsModule = `$false
    }
}

if (-not (Test-NerdFontInstalled -Name $nameLiteral -ExpectedFontFace $fontFaceLiteral)) {
    if (`$canUseNerdFontsModule) {
        NerdFonts\Install-NerdFont -Name $nameLiteral -Scope $scopeLiteral -Force
    } else {
        Install-NerdFontFromArchive -Name $nameLiteral -Scope $scopeLiteral
    }
}

if (-not (Test-NerdFontInstalled -Name $nameLiteral -ExpectedFontFace $fontFaceLiteral)) {
    throw "Nerd Font installation completed, but Windows does not report font face $fontFaceLiteral."
}
"@
    }

    if (Test-NerdFontInstalled -Name $FontName -ExpectedFontFace $FontFace) {
        [PSCustomObject]@{
            FontName = $FontName
            FontFace = $FontFace
            Scope    = 'Existing'
            Status   = 'installed'
            ExitCode = 0
        }
        return
    }

    $isAdministrator = Test-CurrentProcessAdministrator
    $needsElevation = ($Scope -eq 'AllUsers' -and -not $isAdministrator)

    if ($needsElevation) {
        $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ('Install-NerdFont-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
        $script = New-NerdFontInstallScript `
            -Name $FontName `
            -ExpectedFontFace $FontFace `
            -InstallScope $Scope `
            -ModuleDirectory $PSScriptRoot
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
            $scriptBlock = [scriptblock]::Create((New-NerdFontInstallScript `
                -Name $FontName `
                -ExpectedFontFace $FontFace `
                -InstallScope 'CurrentUser' `
                -ModuleDirectory $PSScriptRoot))
            & $scriptBlock
            $Scope = 'CurrentUser'
            $exitCode = 0
        }
    } else {
        Write-Host "Installing Nerd Font $FontName with scope $Scope"
        $scriptBlock = [scriptblock]::Create((New-NerdFontInstallScript `
            -Name $FontName `
            -ExpectedFontFace $FontFace `
            -InstallScope $Scope `
            -ModuleDirectory $PSScriptRoot))
        & $scriptBlock
        $exitCode = 0
    }

    $status = if ($exitCode -eq 0) { 'installed' } else { 'failed' }

    [PSCustomObject]@{
        FontName = $FontName
        FontFace = $FontFace
        Scope    = $Scope
        Status   = $status
        ExitCode = $exitCode
    }
}

Export-ModuleMember -Function Install-NerdFont
