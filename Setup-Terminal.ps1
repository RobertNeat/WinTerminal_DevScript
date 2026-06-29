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
Import-Module ".\modules\Terminal.Themes\Set-TerminalColorSchemes.psm1" -ErrorAction Stop

# Developer tool checkers
Import-Module ".\modules\DevTools.Checkers\Get-JavaInstallationReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-PythonInterpreterReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-NodeRuntimeReport.psm1"
Import-Module ".\modules\DevTools.Checkers\Get-GitInstallationReport.psm1"

# PowerShell profile / prompt configuration
Import-Module ".\powershell_config_setters\set_oh_my_posh_for_powershell.psm1"

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
    Write-Output "💻 Informacje o systemie operacyjnym: $full_Windows_Version"
    Write-Output "Informacje o systemie (CPU, RAM, Disk):"
    Write-Output " - CPU: $cpu"
    Write-Output " - RAM: $ram_Summary"
    Write-Output " - Disk: $disk_summary"
    Write-Output "Wersja PowerShell: $powershellVersion"
    Write-Output "Ścieżka do katalogu domowego: $homePath"
    Write-Output "Ścieżka do aktualnego katalogu: $currentPath"
    Write-Output ""
}

try {
    print_initial_info

    # 1. Check available compilers/interpreters/environments
    $java = Get-JavaInstallationReport
    $python = Get-PythonInterpreterReport
    $node = Get-NodeRuntimeReport
    $git = Get-GitInstallationReport

    Write-Output "JavaHome: $($java.JavaHome)"
    Write-Output "PythonHome: $($python.PythonHome)"
    Write-Output "NodeHome: $($node.NodeHome)"
    Write-Output "GitHome: $($git.GitHome)"
    Write-Output "BashHome: $($git.BashHome)"
    Write-Output ""

    
    $executables_map = [ordered]@{
        git    = $git.BashHome
        python = $python.PythonHome
        node   = $node.NodeHome
    }

    # 2. Get current Windows Terminal configuration
    $terminal_settings_path = Get-TerminalSettingsPath
    #[debug] $config = Get-TerminalConfiguration -SettingsPath $terminal_settings_path -JsonDepth 10
    #[debug] Write-Output $config | Format-List

    # 3. Update Windows Terminal profiles (+ profile icons)
    $configTerminalProfiles = Set-TerminalProfiles -ExecutablesMap $executables_map -SettingsPath $terminal_settings_path
    #[debug] Write-Output $configTerminalProfiles | Format-List
    #[debug] Write-Output $configTerminalProfiles.settings | Format-List

    # 4. Disable delected dynamic profile sources (Azure, SSH)
    $configNoDynamicProfiles = Disable-TerminalDynamicProfiles -ProfileSourceToDisable @(
        "Windows.Terminal.Azure",
        "Windows.Terminal.SSH"
    ) -SettingsObject $configTerminalProfiles
    #[debug] Write-Output $configNoDynamicProfiles.settings | Format-List

    # 5. Apply profiles color schemes
    $configColorSchema = Set-TerminalColorSchemes -Configuration $configNoDynamicProfiles
    #[debug] Write-Output $configColorSchema.settings.schemes | Format-List
    #[debug] Write-Output $configColorSchema.settings.profiles.list | Format-List

    # 5. Apply additional profile settings (showMarksOnScrollbar, autoMarkPrompts, PowerShell -NoLogo)...
    $params = @{
        showMarksOnScrollbar = $true
        autoMarkPrompts      = $true
    }
    $configAdditionalSettings = Set-TerminalProfileAdditionalSettings -Configuration $configColorSchema -ParamsMap $params
    #[debug] Write-Output $configAdditionalSettings.settings.profiles.list | Format-List
    #[debug] Write-Output $configAdditionalSettings.settings | Format-List

    # 6. Apply additional terminal settings (tabWidthMode, searchWebDefaultQueryUrl)...
    $terminalParams = Add-TerminalSettings -Configuration $configAdditionalSettings -ParamsMap @{
        tabWidthMode             = "titleLength"
        searchWebDefaultQueryUrl = "https://www.google.com/search?q=%22%s%22"
    }
    #[debug] Write-Output $terminalParams.settings | Format-List

    # 7. Save the updated configuration back to settings.json
    $savedConfig = Save-TerminalConfiguration -Configuration $terminalParams -SettingsPath $terminal_settings_path
    Write-Output "✅ Windows Terminal configuration saved to: $($savedConfig.SettingsPath)"
}
catch {
    Write-Output $_
}
