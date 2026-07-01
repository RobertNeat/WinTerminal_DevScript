<#
    Windows Terminal setup script:
    1) configures console encoding,
    2) checks OS, PowerShell, and basic machine information,
    3) checks Java, Python, Node.js, and Git availability,
    4) builds Windows Terminal profiles for detected developer shells,
    5) disables selected dynamic profile sources,
    6) applies color schemes and additional profile settings,
    7) writes the updated configuration back to settings.json.
#>

# Ctrl+Shift+P -> Change file encoding -> UTF-8 with BOM
# Keep UTF-8 output so Polish characters are displayed correctly in PowerShell.
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Windows Terminal configuration modules
Import-Module ".\modules\Terminal.Configuration\Get-TerminalSettingsPath.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Configuration\Get-TerminalConfiguration.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Configuration\Save-TerminalConfiguration.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.IO\Add-TerminalSettings.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Set-TerminalProfiles.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Disable-TerminalDynamicProfiles.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Set-TerminalProfileAdditionalSettings.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Profiles\Set-TerminalDefaultFont.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.Themes\Set-TerminalColorSchemes.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.UI\Invoke-TerminalSetupMenu.psm1" -ErrorAction Stop

# Developer tool checkers
Import-Module ".\modules\DevTools.Checkers\Get-JavaInstallationReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-PythonInterpreterReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-NodeRuntimeReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-GitInstallationReport.psm1"

# PowerShell profile / prompt configuration
Import-Module ".\modules\PowerShell.OhMyPosh\Install-OhMyPosh.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Install-NerdFont.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Get-OhMyPoshThemePath.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Set-OhMyPoshTheme.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Set-PowershellProfile.psm1" -ErrorAction Stop

# System information shown at the beginning of the setup.
$os = (Get-CimInstance Win32_OperatingSystem).Caption
$windows_Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
$windows_Build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
$full_Windows_Version = "$os ($windows_Architecture, $windows_Build)"

$cpu = (Get-CimInstance Win32_Processor).Name.Trim()

$ram = Get-CimInstance Win32_OperatingSystem
$ram_TotalGB = [math]::Round($ram.TotalVisibleMemorySize / 1024 / 1024, 2)
$ram_FreeGB = [math]::Round($ram.FreePhysicalMemory / 1024 / 1024, 2)
$ram_UsedGB = [math]::Round($ram_TotalGB - $ram_FreeGB, 2)
$ram_Summary = "used:$ram_UsedGB/total:$ram_TotalGB GB RAM"

$disk = Get-PSDrive C
$disk_UsedGB = [math]::Round($disk.Used / 1GB, 0)
$disk_TotalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 0)
$disk_summary = "used:$disk_UsedGB/total:$disk_TotalGB GB disk"

$powershellVersion = $PSVersionTable.PSVersion.ToString()
$homePath = $HOME
$currentPath = (Get-Location).Path

function print_initial_info {
    Write-Output "💻 Operating system information: $full_Windows_Version"
    Write-Output "System information (CPU, RAM, Disk):"
    Write-Output " - CPU: $cpu"
    Write-Output " - RAM: $ram_Summary"
    Write-Output " - Disk: $disk_summary"
    Write-Output "PowerShell version: $powershellVersion"
    Write-Output "Path to home directory: $homePath"
    Write-Output "Path to current directory: $currentPath"
    Write-Output ""
}

try {
    $initialInfo = @(print_initial_info)

    $setupSelection = Invoke-TerminalSetupMenu -InitialInfoLines $initialInfo
    if (-not $setupSelection.Applied) {
        Write-Output "Setup cancelled. No changes were written."
        return
    }

    $selectedProfiles = @($setupSelection.Profiles)
    $selectedSteps = @($setupSelection.Steps)
    $changedLocations = New-Object System.Collections.Generic.List[string]

    $executables_map = [ordered]@{}

    if ($selectedSteps -contains 'profiles') {
        # 1. Check selected compilers/interpreters/environments
        if ($selectedProfiles -contains 'java') {
            $java = Get-JavaInstallationReport
            Write-Output "JavaHome: $($java.JavaHome)"
            Write-Output "JavaExecutable: $($java.JavaExecutable)"
            $executables_map['java'] = if ($java.JavaExecutable) { $java.JavaExecutable } else { $java.JavaHome }
        }

        if ($selectedProfiles -contains 'python') {
            $python = Get-PythonInterpreterReport
            Write-Output "PythonHome: $($python.PythonHome)"
            $executables_map['python'] = $python.PythonHome
        }

        if ($selectedProfiles -contains 'node') {
            $node = Get-NodeRuntimeReport
            Write-Output "NodeHome: $($node.NodeHome)"
            $executables_map['node'] = $node.NodeHome
        }

        if ($selectedProfiles -contains 'git') {
            $git = Get-GitInstallationReport
            Write-Output "GitHome: $($git.GitHome)"
            Write-Output "BashHome: $($git.BashHome)"
            $executables_map['git'] = $git.BashHome
        }

        Write-Output ""
    }

    # 2. Get current Windows Terminal configuration
    $terminal_settings_path = Get-TerminalSettingsPath
    $config = Get-TerminalConfiguration -SettingsPath $terminal_settings_path -JsonDepth 100
    #[debug] Write-Output $config | Format-List

    # 3. Update Windows Terminal profiles (+ profile icons)
    $configTerminalProfiles = $config
    if ($selectedSteps -contains 'profiles') {
        $removeOtherProfiles = $selectedSteps -contains 'removeOtherProfiles'
        $configTerminalProfiles = Set-TerminalProfiles -ExecutablesMap $executables_map -SettingsObject $config -SettingsPath $terminal_settings_path -RemoveOtherProfiles $removeOtherProfiles
        $terminalSettingsDirectory = Split-Path -Path $terminal_settings_path -Parent
        [void]$changedLocations.Add("✅ Windows Terminal profile icons copied/updated in: $(Join-Path -Path $terminalSettingsDirectory -ChildPath 'icons')")
        if ($removeOtherProfiles) {
            [void]$changedLocations.Add("✅ Windows Terminal profiles outside Windows PowerShell and Command Prompt removed before selected profiles were added.")
        }
    }
    #[debug] Write-Output $configTerminalProfiles | Format-List
    #[debug] Write-Output $configTerminalProfiles.settings | Format-List

    # 4. Disable delected dynamic profile sources (Azure, SSH)
    $configNoDynamicProfiles = $configTerminalProfiles
    if ($selectedSteps -contains 'dynamicProfiles') {
        $configNoDynamicProfiles = Disable-TerminalDynamicProfiles -ProfileSourceToDisable @(
            "Windows.Terminal.Azure",
            "Windows.Terminal.SSH"
        ) -SettingsObject $configTerminalProfiles
    }
    #[debug] Write-Output $configNoDynamicProfiles.settings | Format-List

    # 5. Apply profiles color schemes
    $configColorSchema = $configNoDynamicProfiles
    if ($selectedSteps -contains 'colorSchemes') {
        $configColorSchema = Set-TerminalColorSchemes -Configuration $configNoDynamicProfiles
    }
    #[debug] Write-Output $configColorSchema.settings.schemes | Format-List
    #[debug] Write-Output $configColorSchema.settings.profiles.list | Format-List

    # 6. Apply additional profile settings (showMarksOnScrollbar, autoMarkPrompts, PowerShell -NoLogo)...
    $configAdditionalSettings = $configColorSchema
    if ($selectedSteps -contains 'profileSettings') {
        $params = @{
            showMarksOnScrollbar = $true
            autoMarkPrompts      = $true
        }
        $configAdditionalSettings = Set-TerminalProfileAdditionalSettings -Configuration $configColorSchema -ParamsMap $params
    }
    #[debug] Write-Output $configAdditionalSettings.settings.profiles.list | Format-List
    #[debug] Write-Output $configAdditionalSettings.settings | Format-List

    # 7. Apply additional terminal settings (tabWidthMode, searchWebDefaultQueryUrl)...
    $terminalParams = $configAdditionalSettings
    if ($selectedSteps -contains 'terminalSettings') {
        $terminalParams = Add-TerminalSettings -Configuration $configAdditionalSettings -ParamsMap @{
            tabWidthMode             = "titleLength"
            searchWebDefaultQueryUrl = "https://www.google.com/search?q=%22%s%22"
        }
    }
    #[debug] Write-Output $terminalParams.settings | Format-List

    # 8. Install and configure Oh My Posh for PowerShell
    if ($selectedSteps -contains 'ohMyPosh') {
        $ohMyPoshInstallation = Install-OhMyPosh

        if (-not ($ohMyPoshInstallation.Status -eq 'skipped-by-user' -and -not (Get-Command oh-my-posh -ErrorAction SilentlyContinue))) {
            $fontInstallation = Install-NerdFont -FontName 'FiraCode' -Scope AllUsers

            if (-not ($fontInstallation.Status -eq 'skipped-by-user' -or $fontInstallation.Status -eq 'failed')) {
                $themeDirectory = Split-Path -Path $terminal_settings_path -Parent
                $themePath = [string](Set-OhMyPoshTheme -ThemeName 'marcduiker.omp.json' -ThemeDirectory $themeDirectory | Select-Object -Last 1)
                [void]$changedLocations.Add("✅ Oh My Posh theme copied/updated at: $themePath")
                $updatedProfiles = Set-PowershellProfile -ThemePath $themePath
                foreach ($updatedProfile in $updatedProfiles) {
                    [void]$changedLocations.Add("✅ PowerShell profile updated: $($updatedProfile.ProfilePath)")
                }

                $terminalParams = Set-TerminalDefaultFont -Configuration $terminalParams -FontFace $fontInstallation.FontFace
            }
        }
    }

    # 9. Save the updated configuration back to settings.json
    $savedConfig = Save-TerminalConfiguration -Configuration $terminalParams -SettingsPath $terminal_settings_path
    [void]$changedLocations.Add("✅ Windows Terminal configuration saved to: $($savedConfig.SettingsPath)")

    Write-Output ""
    foreach ($changedLocation in $changedLocations) {
        Write-Output $changedLocation
    }
}
catch {
    Write-Output $_
}
