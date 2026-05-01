# Poziomy zasięgu zmiennych środowiskowych

Windows dzieli zmienne na trzy poziomy zasięgu. Jeśli zmienna istinieje na kilku poziomach to nadpisywana jest `system < użytkownik < proces` (tj. zmienne systemowe są nadpisywane przez zmienne użytkownika, a zmienne procesu nadpisują zmienne użytkownika).

1. Zmienne **systemowe** (Machine) - ustawiane przez Windows i instalatory z uprawnieniami admina. Dotyczą całego komputera i wszystkich użytkowników.
1. Zmienne **użytkownika** (User) - przechowywane w rejestrze. Dotyczą tylko zalogowanego użytkownika.
1. Zmienne **procesu** (Process) - tymczasowe, istnieją jedynie w bieżącej sesji terminala.

---

### Najważniejsze zmienne systemowe systemu Windows

```
# === LOKALIZACJE UŻYTKOWNIKA ===
$env:USERPROFILE      # C:\Users\Robert                     → katalog domowy
$env:APPDATA          # C:\Users\Robert\AppData\Roaming     → konfiguracje aplikacji
$env:LOCALAPPDATA     # C:\Users\Robert\AppData\Local       → lokalne dane aplikacji
$env:TEMP             # C:\Users\Robert\AppData\Local\Temp  → pliki tymczasowe

# === SYSTEM ===
$env:SystemRoot       # C:\Windows
$env:ProgramFiles     # C:\Program Files             → aplikacje 64-bit
$env:ProgramFiles(x86) # C:\Program Files (x86)      → aplikacje 32-bit
$env:ProgramData      # C:\ProgramData               → dane aplikacji

# === TOŻSAMOŚĆ ===
$env:USERNAME         # Robert
$env:COMPUTERNAME     # nazwa maszyny
$env:USERDOMAIN       # domena (ważne w firmach/AD)

# === KLUCZOWE DLA DEWELOPERA ===
$env:PATH             # gdzie system szuka .exe
$env:PATHEXT          # jakie rozszerzenia są wykonywalne (.exe .cmd .ps1...), czyli jakie pliki bez rozszerzenia można dodac do ścieżki bez pełnego rozszerzenia


# === CZĘSTO PRZYDATNE ===
$env:HOMEDRIVE        # C:
$env:HOMEPATH         # \Users\Robert
$env:OS               # Windows_NT
$env:PROCESSOR_ARCHITECTURE  # AMD64 / x86 — ważne przy kompilacji,
(Get-CimInstance Win32_OperatingSystem).Caption     # Microsoft Windows 11 Pro - wersja systemu operacyjnego
```

Zmienne %ZMIENNA% są używane w cmd (command line), windows explorer, plikach bat (np. %USERPROFILE% w explorer przeniesie do C:\Users\Robert)
Zmienne $env:ZMIENNA są używane w PowerShell (np. Set-Location "$env:USERPROFILE")

Pełne listy zmiennych można pobrać za pomocą:

- zmienne bieżącego procesu (albo krócej `Get-ChildItem env:`):
  `[System.Environment]::GetEnvironmentVariables("Process")`

- zmienne użytkownika:
  `[System.Environment]::GetEnvironmentVariables("User")`

- zmienne systemowe:
  `[System.Environment]::GetEnvironmentVariables("Machine")`

---

### Zmienne w Powershell 5

W powershell oprócz zmiennych systemowych/użytkownika/procesu występują także zdefiniowane stałe:

| zmienna        | wartość zmiennej                                                                           |
| -------------- | ------------------------------------------------------------------------------------------ |
| **$null**      | wartość pusta/brak wartości                                                                |
| **$true**      | wartość logiczna True                                                                      |
| **$false**     | wartość logiczna False                                                                     |
| **$HOME**      | ścieżka bezwzględna do katalogu domowego, nie można używać jako $env:HOME tylko jako $HOME |
| **$HOST**      | obiekt hosta                                                                               |
| **$Profile**   | ścieżka do profilu użytkownika                                                             |
| **$PID**       | ID procesu bieżącej sesji PS                                                               |
| **$PWD**       | bieżący katalog roboczy                                                                    |
| **$PSHome**    | katalog instalacji PowerShell                                                              |
| **$PSCulture** | ustawienia regionalne bieżącej sesji                                                       |
