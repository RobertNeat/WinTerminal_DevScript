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

# deklaracja poszczególnych funkcji sprawdzających dostępność konpilatorów i ich wersji



function check_python_interpreter {
}

function check_node_runtime{
}





# deklaracja funkcji ustawiającej oh my posh dla powershella


# deklaracja funkcji ustawiającej konfigurację terminala windows dla poszczególnych powłok


# deklaracja funkcji ustawiającej motywy dla powłoki powershell (profil powershella)

#trzeba ustawić kodowanie dla utf-8
#chcp 65001 | Out-Null
#[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
#$OutputEncoding = [System.Text.Encoding]::UTF8
#$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# główne wywołanie poszcególnych funkcji (main execution flow)

try {
    print_initial_info
    check_java_compiler
    check_python_interpreter
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
    

    Write-Output "🐦‍🔥📎⚙️"
}