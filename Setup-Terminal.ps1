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

function New-TerminalSetupOption {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Key,

        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Profile', 'Step')]
        [string] $Group,

        [bool] $Selected = $true
    )

    [PSCustomObject]@{
        Key      = $Key
        Label    = $Label
        Group    = $Group
        Selected = $Selected
    }
}

function Invoke-TerminalSetupMenu {
    $profileOptions = @(
        New-TerminalSetupOption -Key 'git' -Label 'git' -Group 'Profile'
        New-TerminalSetupOption -Key 'python' -Label 'python' -Group 'Profile'
        New-TerminalSetupOption -Key 'node' -Label 'node' -Group 'Profile'
        New-TerminalSetupOption -Key 'java' -Label 'java' -Group 'Profile'
    )

    $stepOptions = @(
        New-TerminalSetupOption -Key 'profiles' -Label 'Update Windows Terminal profiles (+ profile icons)' -Group 'Step'
        New-TerminalSetupOption -Key 'dynamicProfiles' -Label 'Disable selected dynamic profile sources (Azure, SSH)' -Group 'Step'
        New-TerminalSetupOption -Key 'colorSchemes' -Label 'Apply profiles color schemes' -Group 'Step'
        New-TerminalSetupOption -Key 'profileSettings' -Label 'Apply additional profile settings (showMarksOnScrollbar, autoMarkPrompts, PowerShell -NoLogo)' -Group 'Step'
        New-TerminalSetupOption -Key 'terminalSettings' -Label 'Apply additional terminal settings (tabWidthMode, searchWebDefaultQueryUrl)' -Group 'Step'
    )

    $items = @($profileOptions + $stepOptions)
    $cursor = 0
    $actionCursor = 0
    $isActionRow = $false

    function Write-MenuLine {
        param(
            [string] $Text,
            [bool] $Active = $false
        )

        if ($Active) {
            Write-Host $Text -ForegroundColor Black -BackgroundColor Gray
        } else {
            Write-Host $Text
        }
    }

    function Render-Menu {
        Clear-Host
        Write-Host "Windows Terminal setup"
        Write-Host "Use Up/Down arrows to move, Space/Enter to toggle, Enter on Apply/Cancel to finish, Esc to cancel."
        Write-Host ""
        Write-Host "Profiles to configure:"

        for ($i = 0; $i -lt $profileOptions.Count; $i++) {
            $option = $profileOptions[$i]
            $index = [array]::IndexOf($items, $option)
            $mark = if ($option.Selected) { 'X' } else { ' ' }
            Write-MenuLine -Text ("[{0}] {1}" -f $mark, $option.Label) -Active ((-not $isActionRow) -and $cursor -eq $index)
        }

        Write-Host ""
        Write-Host "Steps to run:"

        for ($i = 0; $i -lt $stepOptions.Count; $i++) {
            $option = $stepOptions[$i]
            $index = [array]::IndexOf($items, $option)
            $mark = if ($option.Selected) { 'X' } else { ' ' }
            Write-MenuLine -Text ("[{0}] {1}" -f $mark, $option.Label) -Active ((-not $isActionRow) -and $cursor -eq $index)
        }

        Write-Host ""
        $applyText = if ($isActionRow -and $actionCursor -eq 0) { '> [Apply]' } else { '  [Apply]' }
        $cancelText = if ($isActionRow -and $actionCursor -eq 1) { '> [Cancel]' } else { '  [Cancel]' }

        if ($isActionRow -and $actionCursor -eq 0) {
            Write-Host $applyText -NoNewline -ForegroundColor Black -BackgroundColor Gray
        } else {
            Write-Host $applyText -NoNewline
        }

        Write-Host " " -NoNewline

        if ($isActionRow -and $actionCursor -eq 1) {
            Write-Host $cancelText -ForegroundColor Black -BackgroundColor Gray
        } else {
            Write-Host $cancelText
        }
    }

    while ($true) {
        Render-Menu
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                if ($isActionRow) {
                    $isActionRow = $false
                    $cursor = $items.Count - 1
                } elseif ($cursor -gt 0) {
                    $cursor--
                }
            }
            'DownArrow' {
                if ($isActionRow) {
                    continue
                } elseif ($cursor -lt ($items.Count - 1)) {
                    $cursor++
                } else {
                    $isActionRow = $true
                }
            }
            'LeftArrow' {
                if ($isActionRow) { $actionCursor = 0 }
            }
            'RightArrow' {
                if ($isActionRow) { $actionCursor = 1 }
            }
            'Spacebar' {
                if (-not $isActionRow) {
                    $items[$cursor].Selected = -not $items[$cursor].Selected
                }
            }
            'Enter' {
                if ($isActionRow) {
                    Clear-Host
                    if ($actionCursor -eq 1) {
                        return [PSCustomObject]@{ Applied = $false }
                    }

                    return [PSCustomObject]@{
                        Applied  = $true
                        Profiles = @($profileOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
                        Steps    = @($stepOptions | Where-Object { $_.Selected } | ForEach-Object { $_.Key })
                    }
                }

                $items[$cursor].Selected = -not $items[$cursor].Selected
            }
            'Escape' {
                Clear-Host
                return [PSCustomObject]@{ Applied = $false }
            }
        }
    }
}

try {
    print_initial_info

    $setupSelection = Invoke-TerminalSetupMenu
    if (-not $setupSelection.Applied) {
        Write-Output "Setup cancelled. No changes were written."
        return
    }

    $selectedProfiles = @($setupSelection.Profiles)
    $selectedSteps = @($setupSelection.Steps)

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
        $configTerminalProfiles = Set-TerminalProfiles -ExecutablesMap $executables_map -SettingsObject $config -SettingsPath $terminal_settings_path
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

    # 8. Save the updated configuration back to settings.json
    $savedConfig = Save-TerminalConfiguration -Configuration $terminalParams -SettingsPath $terminal_settings_path
    Write-Output "✅ Windows Terminal configuration saved to: $($savedConfig.SettingsPath)"
}
catch {
    Write-Output $_
}
