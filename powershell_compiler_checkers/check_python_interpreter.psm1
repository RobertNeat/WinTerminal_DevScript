Import-Module ".\powershell_compiler_checkers\search_system_for_compiler"
function check_python_interpreter {
    $result = [PSCustomObject]@{
        Name        = "Python Interpreter"
        Installed   = $false
        InPath      = $false
        Version     = $null
        AllVersions = @()
        Manager     = $null
        PythonHome  = $null
        Errors      = (New-Object System.Collections.Generic.List[string])
    }

    # -------------------------------------------------------------------------
    # 1. Sprawdzenie dostępności python / python3 z poziomu PATH
    # -------------------------------------------------------------------------

    # Słownik: nazwa komendy -> zmienna przechowująca wynik Get-Command
    $pythonCommands = [ordered]@{
        'python'  = $null
        'python3' = $null
    }

    foreach ($cmdName in $pythonCommands.Keys) {
        try {
            $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
            if ($cmd) {
                $pythonCommands[$cmdName] = $cmd
            }
        } catch {
            $result.Errors.Add("Błąd przy Get-Command '$cmdName': $($_.Exception.Message)")
        }
    }

    # Próba wywołania --version dla każdej znalezionej komendy
    # Wybieramy pierwszą, która zwróci poprawną wersję
    foreach ($cmdName in $pythonCommands.Keys) {
        $cmd = $pythonCommands[$cmdName]
        if (-not $cmd) { continue }

        try {
            # Python 3.4+ pisze wersję na stdout; starsze wersje na stderr — dlatego 2>&1
            $versionOutput = & $cmdName --version 2>&1
            $versionString = $versionOutput | Select-Object -First 1 | Out-String

            if ($versionString -match '(\d+\.\d+\.\d+)') {
                $result.Installed   = $true
                $result.InPath      = $true
                $result.Version     = $Matches[1]
                $result.PythonHome  = Split-Path $cmd.Source -Parent

                # Sprawdzamy, czy komendy wskazują na shim pyenv-win
                # Shim pyenv-win znajduje się w .pyenv\pyenv-win\shims\
                if ($cmd.Source -match '[\\/]\.pyenv[\\/]|[\\/]pyenv-win[\\/]') {
                    $result.Manager = "pyenv-win"
                }

                break  # wystarczy pierwsza poprawna odpowiedź
            } else {
                $result.Errors.Add("Nie udało się sparsować wersji z '$cmdName --version'. Surowy wynik: '$($versionString.Trim())'")
            }
        } catch {
            $result.Errors.Add("Błąd przy wywołaniu '$cmdName --version': $($_.Exception.Message)")
        }
    }

    # -------------------------------------------------------------------------
    # 2. Sprawdzenie pyenv-win przez zmienne środowiskowe
    #    (niezależnie od tego, czy python.exe już znaleziono w PATH,
    #     bo chcemy zebrać AllVersions i potwierdzić Manager)
    # -------------------------------------------------------------------------

    # pyenv-win ustawia PYENV lub PYENV_ROOT (zależnie od wersji instalatora)
    $pyenvRoot = $null

    foreach ($varName in @('PYENV_ROOT', 'PYENV')) {
        $candidate = [System.Environment]::GetEnvironmentVariable($varName, 'Machine')
        if (-not $candidate) {
            $candidate = [System.Environment]::GetEnvironmentVariable($varName, 'User')
        }
        if (-not $candidate) {
            $candidate = [System.Environment]::GetEnvironmentVariable($varName)  # bieżący proces
        }

        if ($candidate -and (Test-Path $candidate)) {
            $pyenvRoot = $candidate
            break
        } elseif ($candidate) {
            $result.Errors.Add("Zmienna '$varName' wskazuje na nieistniejącą ścieżkę: '$candidate'")
        }
    }

    # Jeśli zmienna nie istnieje, sprawdzamy domyślną lokalizację pyenv-win
    if (-not $pyenvRoot) {
        $defaultPyenvRoot = Join-Path $env:USERPROFILE '.pyenv\pyenv-win'
        if (Test-Path $defaultPyenvRoot) {
            $pyenvRoot = $defaultPyenvRoot
        }
    }

    if ($pyenvRoot) {
        $result.Manager = "pyenv-win"

        # 2a. Aktywna wersja pyenv (plik .python-version lub `pyenv version`)
        if (-not $result.Installed) {
            $pythonVersionFile = Join-Path $pyenvRoot '..\version'  # pyenv-win trzyma tu globalną wersję
            if (-not (Test-Path $pythonVersionFile)) {
                # alternatywna lokalizacja — plik w katalogu domowym
                $pythonVersionFile = Join-Path $env:USERPROFILE '.python-version'
            }

            if (Test-Path $pythonVersionFile) {
                $activeVersion = (Get-Content $pythonVersionFile -Raw).Trim()
                if ($activeVersion -match '(\d+\.\d+\.\d+)') {
                    $activeVersion = $Matches[1]
                    $shimPythonPath = Join-Path $pyenvRoot 'shims\python.exe'

                    if (Test-Path $shimPythonPath) {
                        $result.Installed  = $true
                        $result.Version    = $activeVersion
                        $result.PythonHome = Join-Path $pyenvRoot "versions\$activeVersion"
                    } else {
                        $result.Errors.Add("pyenv-win: znaleziono aktywną wersję '$activeVersion', ale brak shim: '$shimPythonPath'")
                    }
                }
            }
        }

        # 2b. Lista wszystkich zainstalowanych wersji w katalogu versions\
        try {
            $versionsDir = Join-Path $pyenvRoot 'versions'
            if (Test-Path $versionsDir) {
                $installedVersions = Get-ChildItem -Path $versionsDir -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } |
                    Select-Object -ExpandProperty Name

                if ($installedVersions) {
                    $result.AllVersions = @($installedVersions)
                    $result.Installed   = $true
                }
            } else {
                $result.Errors.Add("pyenv-win: katalog versions\ nie istnieje: '$versionsDir'")
            }
        } catch {
            $result.Errors.Add("Błąd przy odczycie wersji pyenv-win: $($_.Exception.Message)")
        }

        # 2c. Jeśli Version nadal puste, a AllVersions ma wpisy — bierzemy najnowszą
        if (-not $result.Version -and $result.AllVersions.Count -gt 0) {
            $result.Version = $result.AllVersions |
                Sort-Object { [Version]($_ -replace '[^0-9.]', '') } -Descending |
                Select-Object -First 1
            $result.Errors.Add("pyenv-win: brak aktywnej wersji (.python-version), przyjęto najnowszą zainstalowaną: '$($result.Version)'")
        }
    }

    # -------------------------------------------------------------------------
    # 3. Przeszukanie systemu przez search_system_for_compiler
    #    (tylko jeśli nadal nie znaleziono instalacji)
    # -------------------------------------------------------------------------

    if (-not $result.Installed) {
        try {
            $pythonPossiblePaths = @(
                # Instalacje z python.org (katalog wersjonowany)
                "$env:LOCALAPPDATA\Programs\Python",
                "C:\Python312",
                "C:\Python311",
                "C:\Python310",
                "C:\Python39",
                "C:\Python38",
                # pyenv-win (shims + versions)
                "$env:USERPROFILE\.pyenv\pyenv-win\shims",
                "$env:USERPROFILE\.pyenv\pyenv-win\versions",
                # Menedżery pakietów
                "$env:USERPROFILE\scoop\apps\python",
                "$env:USERPROFILE\scoop\apps\pyenv",
                "C:\ProgramData\chocolatey\lib\python",
                # Dystrybucja Anaconda / Miniconda
                "$env:USERPROFILE\anaconda3",
                "$env:USERPROFILE\miniconda3",
                "$env:LOCALAPPDATA\anaconda3",
                "$env:LOCALAPPDATA\miniconda3",
                "C:\ProgramData\Anaconda3",
                "C:\ProgramData\Miniconda3"
            )

            $found = search_system_for_compiler `
                -CompilerNames     @('python', 'python3') `
                -CompilerExtension 'exe' `
                -SearchPaths       $pythonPossiblePaths `
                -Depth             4

            if ($found.Count -gt 0) {
                # Preferuj python3.exe jeśli dostępny, inaczej python.exe
                $best = $found | Where-Object { $_.CompilerName -eq 'python3' } | Select-Object -First 1
                if (-not $best) {
                    $best = $found | Where-Object { $_.CompilerName -eq 'python'  } | Select-Object -First 1
                }

                $result.Installed  = $true
                $result.PythonHome = $best.Directory

                # Spróbuj pobrać wersję wywołując znaleziony plik bezpośrednio
                try {
                    $versionOutput = & $best.FullPath --version 2>&1
                    $versionString = $versionOutput | Select-Object -First 1 | Out-String
                    if ($versionString -match '(\d+\.\d+\.\d+)') {
                        $result.Version = $Matches[1]
                    }
                } catch {
                    $result.Errors.Add("Błąd przy pobieraniu wersji z '$($best.FullPath)': $($_.Exception.Message)")
                }

                # Ustal manager na podstawie ścieżki
                if ($best.FullPath -match '[\\/]\.pyenv[\\/]|[\\/]pyenv-win[\\/]') {
                    $result.Manager = "pyenv-win"
                } elseif ($best.FullPath -match '[\\/]anaconda|[\\/]miniconda' ) {
                    $result.Manager = "conda"
                } elseif ($best.FullPath -match '[\\/]scoop[\\/]') {
                    $result.Manager = "scoop"
                } elseif ($best.FullPath -match '[\\/]chocolatey[\\/]') {
                    $result.Manager = "chocolatey"
                }

                $result.Errors.Add("Znaleziono '$($best.CompilerName).exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie '$($best.Directory)' do zmiennych środowiskowych.")
            }
        } catch {
            $result.Errors.Add("Błąd podczas wywołania search_system_for_compiler: $($_.Exception.Message)")
        }
    }

    # -------------------------------------------------------------------------
    # Zwróć wynik
    # -------------------------------------------------------------------------

    $result.Errors = $result.Errors.ToArray()
    return $result
}

Export-ModuleMember -Function check_python_interpreter