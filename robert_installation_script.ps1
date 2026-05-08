<#
    Skrypt instalacyjny windows:
    1) sprawdza wersję systemu operacyjnego i wersję powershella
    2) sprawdza zainstalowane kompilatory (dostępność z posiomu path), ich wersje
        - java (instalacja zwykła java lub adoption java)
        - python (instalacja zwykła python lub python version manager)
        - node (instalacja zwykła node lub nvm)
        - git
    3) pobiera ścieżki do katalogów domowych i aktualnego katalogu
    4) ustawia powłoki dla użytkownika:
        - oh my posh (dla powershell)
    5) ustawia konfigurację dla terminala windows (kolejno):
        - powershell
        - git bash
        - terminal python
        - terminal node
        - cmd
    6) ustawia motywy dla powłoki powershell (profil powershella)
#>
#`Ctrl+Shift+P --> `Change file encoding` --> `UTF-8 with BOM`
# Zmienia kodowanie na UTF-8 z BOM, żeby wyświetlać polskie znaki w powershell 
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 0. Import funkcji do sprawdzania kompilatorów
Import-Module ".\powershell_compiler_checkers\check_java_compiler.psm1"
Import-Module ".\powershell_compiler_checkers\check_python_interpreter.psm1"
Import-Module ".\powershell_compiler_checkers\check_node_runtime.psm1"
Import-Module ".\powershell_compiler_checkers\check_git.psm1"

# 1. Pobranie informacji o systemie operacyjnym, wersji powershella, ścieżkach do katalogów domowych i aktualnego katalogu

# Windows
$os = (Get-CimInstance Win32_OperatingSystem).Caption
$windows_Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
$windows_Build        = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
$full_Windows_Version = "$os ($windows_Architecture, $windows_Build)"

# System (cpu,ram,disk)
$cpu = (Get-CimInstance Win32_Processor).Name.Trim()

$ram = Get-CimInstance Win32_OperatingSystem
$ram_TotalGB = [math]::Round($ram.TotalVisibleMemorySize / 1024 / 1024, 2);
$ram_FreeGB = [math]::Round($ram.FreePhysicalMemory / 1024 / 1024, 2)
$ram_UsedGB = [math]::Round($ram_TotalGB - $ram_FreeGB, 2); 
$ram_Summary = "used:$ram_UsedGB/total:$ram_TotalGB GB RAM"

$disk = Get-PSDrive C
$disk_UsedGB = [math]::Round($disk.Used / 1GB, 0)
$disk_TotalGB =  [math]::Round(($disk.Used + $disk.Free) / 1GB, 0)
$disk_summary = "used:$disk_UsedGB/total:$disk_TotalGB GB disk"

# Path Variables
$powershellVersion = $PSVersionTable.PSVersion.ToString()
$homePath = $HOME
$currentPath = (Get-Location).Path

# funkcja informacyjna wypisująca informacje początkowe
function print_initial_info {
    Write-Output "💻 Informacje o systemie operacyjnym: $full_Windows_Version"
    Write-Output "Informacje o systemie (CPU, RAM, Disk):"
    Write-Output " - CPU: $cpu"
    Write-Output " - RAM: $ram_Summary"
    Write-Output " - Disk: $disk_summary"
    Write-Output "Wersja PowerShell: $powershellVersion"
    Write-Output "Ścieżka do katalogu domowego: $homePath"
    Write-Output "Ścieżka do aktualnego katalogu: $currentPath"
}

# deklaracja funkcji ustawiającej konfigurację terminala windows dla poszczególnych powłok
Import-Module ".\powershell_config_setters\set_terminal_configuration_profiles.psm1"

# deklaracja funkcji ustawiającej oh my posh dla powershella
Import-Module ".\powershell_config_setters\set_oh_my_posh_for_powershell.psm1"

# deklaracja funkcji ustawiającej motywy dla powłoki powershell (profil powershella)

# główne wywołanie poszcególnych funkcji (main execution flow)
try {
    # print_initial_info

    $java = check_java_compiler
    $python = check_python_interpreter
    $node = check_node_runtime
    $git = check_git
    # Write-Output $java
    # Write-Output $python
    # Write-Output $node
    # Write-Output $git

    $executables_map = [ordered]@{
        git    = $git.BashHome
        python = $python.PythonHome
        node   = $node.NodeHome
    }

    #$check = Update-TerminalProfiles -ExecutablesMap $executables_map
    #Write-Output $check

    $terminal_settings_path = Resolve-WindowsTerminalSettingsPath
    $conf = Get-ExistingTerminalConfiguration -settingsPath $terminal_settings_path -JsonDepth 10
    Write-Output $conf.settings.profiles.list

    #Write-Output $conf.settings.profiles.list
    #set_oh_my_posh_for_powershell

    Write-Output "---------------------------------------"

    $updatedConf = Update-TerminalProfiles -ExecutablesMap $executables_map -SettingsPath $terminal_settings_path
    Write-Output $updatedConf.settings.profiles.list
}
catch {
    #Write-Output "Error: $($_.Exception.Message)"
    Write-Output $_
    #Write-Output $_.InvocationInfo <-- additional information about the exception
}# https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions?view=powershell-5.1