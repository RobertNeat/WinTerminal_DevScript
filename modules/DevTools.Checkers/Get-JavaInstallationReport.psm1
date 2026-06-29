Import-Module ".\modules\DevTools.Search\Find-ExecutableFile.psm1" -ErrorAction Stop

# Checks the Java compiler and runtime installation.
# [output-param] PSCustomObject: report with Name, Installed, InPath, Version, JavaHome, JavaExecutable, and Errors fields
# [side-effect] Runs javac/java, reads JAVA_HOME and PATH, and searches common installation directories.
function Get-JavaInstallationReport {
    $result = [PSCustomObject]@{
        Name = "Java Compiler"
        Installed = $false
        InPath = $false
        Version = $null
        JavaHome = $null
        JavaExecutable = $null
        Errors = (New-Object System.Collections.Generic.List[string])
    }

    # - sprawdzenie wersji java za pomocą 'javac -version'
    try {
        $javacOutput = & javac -version 2>&1
        $javacString = $javacOutput | Select-Object -First 1 | Out-String

        if ($LASTEXITCODE -eq 0 -or $javacString -match 'javac') {
            $result.Installed = $true
            $result.InPath    = $true

            if ($javacString -match 'javac\s+(\S+)') {
                $result.Version = $Matches[1]
            } else {
                $result.Errors.Add("Nie udało się sparsować wersji javac. Surowy wynik: '$($javacString.Trim())'")
            }
        }
    } catch {
        $result.Errors.Add("Błąd przy wywołaniu javac: $($_.Exception.Message)")
    }


    # - sprawdzenie zmiennej środowiskowej JAVA_HOME
    try {
        $javaHomeEnv = [System.Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
        if (-not $javaHomeEnv) {
            $javaHomeEnv = [System.Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
        }
        if (-not $javaHomeEnv) {
            $javaHomeEnv = $env:JAVA_HOME
        }

        if ($javaHomeEnv) {
            if (Test-Path $javaHomeEnv) {
                $result.JavaHome = $javaHomeEnv
            } else {
                $result.Errors.Add("JAVA_HOME wskazuje na nieistniejącą ścieżkę: '$javaHomeEnv'")
            }
        }
    } catch {
        $result.Errors.Add("Błąd przy odczycie JAVA_HOME: $($_.Exception.Message)")
    }

    # - sprawdzenie dostępności java.exe w PATH
    try {
        $javaInPath = Get-Command 'java.exe' -ErrorAction SilentlyContinue
        if ($javaInPath) {
            $result.InPath = $true
        }
    } catch {
        $result.Errors.Add("Błąd przy przeszukiwaniu PATH dla java.exe: $($_.Exception.Message)")
    }

    # - Ustalenie ścieżki do java.exe do uruchomienia
    # Priorytet: PATH > JAVA_HOME\bin
    $javaExePath = $null

    if ($result.InPath) {
        try {
            $javaExePath = (Get-Command 'java.exe' -ErrorAction Stop).Source
        } catch {
            $result.Errors.Add("Błąd przy pobieraniu ścieżki java.exe z PATH: $($_.Exception.Message)")
        }
    }

    if (-not $javaExePath -and $result.JavaHome) {
        $candidate = Join-Path $result.JavaHome 'bin\java.exe'
        if (Test-Path $candidate) {
            $javaExePath = $candidate
        } else {
            $result.Errors.Add("Nie znaleziono java.exe w JAVA_HOME\bin: '$candidate'")
        }
    }

     # - Sprawdzenie instalacji i wersji
    if ($javaExePath) {
        $result.Installed = $true
        $result.JavaExecutable = $javaExePath

        try {
            # java -version pisze na stderr, dlatego przekierowujemy 2>&1
            $versionOutput = & $javaExePath -version 2>&1
            $versionString = $versionOutput | Select-Object -First 1 | Out-String

            # Format: java version "21.0.3" lub openjdk version "17.0.1"
            if ($versionString -match '"([^"]+)"') {
                $result.Version = $Matches[1]
            } else {
                $result.Version = $versionString.Trim()
                $result.Errors.Add("Nie udało się sparsować wersji Javy. Surowy wynik: '$versionString'")
            }
        } catch {
            $result.Errors.Add("Błąd przy pobieraniu wersji Javy: $($_.Exception.Message)")
        }
    }
    # - Jeśli nie znaleziono kompilatora — uruchom Find-ExecutableFile dla java ---
    if (-not $result.Installed) {
        try {
            $javaPossiblePaths = @(
                "C:\Program Files\Eclipse Adoptium",
                "C:\Program Files\Microsoft",
                "C:\Program Files\Java",
                "C:\Program Files (x86)\Java",
                "$env:LOCALAPPDATA\JetBrains",
                "C:\Program Files\JetBrains",
                "$env:USERPROFILE\scoop\apps",
                "C:\ProgramData\chocolatey\lib"
            )
            
            $found = Find-ExecutableFile `
                -CompilerNames     @('java', 'javac') `
                -CompilerExtension 'exe' `
                -SearchPaths       $javaPossiblePaths `
                -Depth             3


            if ($found.Count -gt 0) {
            # Preferujemy javac jeśli znaleziono (pełny JDK)
            $javac = $found | Where-Object { $_.CompilerName -eq 'javac' } | Select-Object -First 1
            $java  = $found | Where-Object { $_.CompilerName -eq 'java'  } | Select-Object -First 1
            $best  = if ($javac) { $javac } else { $java }

            $result.Installed = $true
            $result.JavaExecutable = $best.FullPath
            $result.Errors.Add("Znaleziono '$($best.CompilerName).exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie '$($best.Directory)' do zmiennych środowiskowych.")
            }

        } catch {
            $result.Errors.Add("Błąd podczas wywołania search_system_for_java: $($_.Exception.Message)")
        }
    }

    # Konwersja listy błędów na zwykłą tablicę string[]
    $result.Errors = $result.Errors.ToArray()

    return $result
}


Export-ModuleMember -Function Get-JavaInstallationReport
