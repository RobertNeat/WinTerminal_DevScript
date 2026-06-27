Import-Module ".\powershell_compiler_checkers\search_system_for_compiler"

# Checks the Python interpreter installation and pyenv-win configuration.
# [output-param] PSCustomObject: report with Name, Installed, InPath, Version, AllVersions, Manager, PythonHome, and Errors fields
# [side-effect] Runs python/pyenv shims, reads environment variables, and searches common installation directories.
function check_python_interpreter {
	$result = [PSCustomObject]@{
		Name        = "Python Interpreter"
		Installed   = $false
		InPath      = $false
		Version     = $null
		AllVersions = @()
		Manager     = $null
		PythonHome  = $null  # pełna ścieżka do wykonywalnego python.exe (sys.executable)
		Errors      = (New-Object System.Collections.Generic.List[string])
	}

	# Gets an environment variable value from Machine, User, or the current process.
	# [input-param] Name: environment variable name
	# [output-param] string|null: first found variable value
	# [side-effect] Reads system and user environment variables.
	function Get-EnvVarValue {
		param([Parameter(Mandatory = $true)][string]$Name)
		$value = [System.Environment]::GetEnvironmentVariable($Name, 'Machine')
		if (-not $value) { $value = [System.Environment]::GetEnvironmentVariable($Name, 'User') }
		if (-not $value) { $value = [System.Environment]::GetEnvironmentVariable($Name) }
		return $value
	}

	# Normalizes a PATH entry for directory comparisons.
	# [input-param] Path: single path entry, optionally quoted
	# [output-param] string|null: normalized path without a trailing separator, or null
	function Normalize-PathEntry {
		param([string]$Path)
		if (-not $Path) { return $null }
		$p = $Path.Trim()
		if ($p.StartsWith('"') -and $p.EndsWith('"')) {
			$p = $p.Trim('"')
		}
		return $p.Trim().TrimEnd('\\')
	}

	# Checks whether a PATH variable contains the specified directory.
	# [input-param] PathVariableValue: semicolon-separated PATH variable value
	# [input-param] Directory: directory expected in PATH
	# [output-param] bool: true when Directory appears in PathVariableValue
	function Test-PathContainsDirectory {
		param(
			[string]$PathVariableValue,
			[string]$Directory
		)

		if (-not $PathVariableValue -or -not $Directory) { return $false }
		$dirNorm = Normalize-PathEntry $Directory
		if (-not $dirNorm) { return $false }

		foreach ($entry in ($PathVariableValue -split ';')) {
			$entryNorm = Normalize-PathEntry $entry
			if ($entryNorm -and ($entryNorm -ieq $dirNorm)) { return $true }
		}

		return $false
	}

	# Parses the Python version from output text.
	# [input-param] Line: text line containing the version number
	# [output-param] string|null: version in major.minor.patch format, or null
	function Try-ParsePythonVersion {
		param([string]$Line)
		if (-not $Line) { return $null }
		if ($Line -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
		return $null
	}

	# Gets the real sys.executable path for the specified Python interpreter.
	# [input-param] PythonPath: path to python.exe, python3.exe, or a pyenv shim
	# [output-param] string|null: path from sys.executable, or null
	# [side-effect] Runs Python with a short command that imports sys.
	function Try-GetPythonSysExecutable {
		param([Parameter(Mandatory = $true)][string]$PythonPath)
		try {
			$out = & $PythonPath @('-c', 'import sys; print(sys.executable)') 2>&1
			$line = ($out | Select-Object -First 1 | Out-String).Trim()
			if ($line -and (Test-Path $line)) { return $line }
		} catch {
			return $null
		}
		return $null
	}

	# Gets and parses the Python version for the specified interpreter.
	# [input-param] PythonPath: path to python.exe, python3.exe, or a pyenv shim
	# [output-param] string|null: parsed Python version, or null
	# [side-effect] Runs python --version.
	function Try-GetPythonVersion {
		param([Parameter(Mandatory = $true)][string]$PythonPath)
		try {
			$out = & $PythonPath @('--version') 2>&1
			$line = ($out | Select-Object -First 1 | Out-String).Trim()
			return (Try-ParsePythonVersion $line)
		} catch {
			return $null
		}
	}

	# Finds the pyenv-win root directory.
	# [output-param] string|null: PYENV_ROOT/PYENV path or the default pyenv-win path
	# [side-effect] Reads environment variables and appends errors to the parent function's report.
	function Resolve-PyenvRoot {
		$pyenvRoot = $null
		foreach ($varName in @('PYENV_ROOT', 'PYENV')) {
			$candidate = Get-EnvVarValue -Name $varName
			if ($candidate -and (Test-Path $candidate)) {
				$pyenvRoot = $candidate
				break
			} elseif ($candidate) {
				$result.Errors.Add("Zmienna '$varName' wskazuje na nieistniejącą ścieżkę: '$candidate'")
			}
		}

		if (-not $pyenvRoot) {
			$defaultPyenvRoot = Join-Path $env:USERPROFILE '.pyenv\\pyenv-win'
			if (Test-Path $defaultPyenvRoot) { $pyenvRoot = $defaultPyenvRoot }
		}

		return $pyenvRoot
	}

	# Finds a Python shim in the pyenv-win directory.
	# [input-param] PyenvRoot: pyenv-win root directory
	# [output-param] string|null: path to the first found python/python3 shim
	# [side-effect] Checks file existence in the shims directory.
	function Resolve-PyenvShimPython {
		param([Parameter(Mandatory = $true)][string]$PyenvRoot)
		$shimsDir = Join-Path $PyenvRoot 'shims'
		$candidates = @(
			(Join-Path $shimsDir 'python.bat'),
			(Join-Path $shimsDir 'python3.bat'),
			(Join-Path $shimsDir 'python.cmd'),
			(Join-Path $shimsDir 'python3.cmd'),
			(Join-Path $shimsDir 'python.exe'),
			(Join-Path $shimsDir 'python3.exe')
		)
		foreach ($p in $candidates) {
			if (Test-Path $p) { return $p }
		}
		return $null
	}

	$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
	$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
	$processPath = $env:Path

	# -------------------------------------------------------------------------
	# 1) pyenv-win FIRST
	# -------------------------------------------------------------------------

	$pyenvRoot = Resolve-PyenvRoot
	if ($pyenvRoot) {
		$result.Manager = 'pyenv-win'

		# AllVersions
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
				$result.Errors.Add("pyenv-win: katalog versions\\ nie istnieje: '$versionsDir'")
			}
		} catch {
			$result.Errors.Add("Błąd przy odczycie wersji pyenv-win: $($_.Exception.Message)")
		}

		$shimsDir = Join-Path $pyenvRoot 'shims'
		$shimsInPath = (
			(Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $shimsDir) -or
			(Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $shimsDir) -or
			(Test-PathContainsDirectory -PathVariableValue $processPath -Directory $shimsDir)
		)
		if ($shimsInPath) { $result.InPath = $true }

		$shim = Resolve-PyenvShimPython -PyenvRoot $pyenvRoot
		if ($shim) {
			$realExe = Try-GetPythonSysExecutable -PythonPath $shim
			if ($realExe) {
				$result.Installed  = $true
				$result.PythonHome = $realExe
				$ver = Try-GetPythonVersion -PythonPath $shim
				if ($ver) { $result.Version = $ver }
			} else {
				$result.Errors.Add("pyenv-win: nie udało się uzyskać sys.executable z shima: '$shim'.")
			}
		} else {
			$result.Errors.Add("pyenv-win: nie znaleziono shima python (python.bat/python3.bat/python.exe) w '$shimsDir'.")
		}

		if (-not $result.Version -and $result.PythonHome) {
			$ver = Try-GetPythonVersion -PythonPath $result.PythonHome
			if ($ver) { $result.Version = $ver }
		}
	}

	# -------------------------------------------------------------------------
	# 2) Klasyczny Python (dopiero jeśli nie mamy realnego python.exe powyżej)
	# -------------------------------------------------------------------------

	if (-not $result.PythonHome) {
		foreach ($cmdName in @('python', 'python3')) {
			$cmds = @()
			try {
				$cmds = @(Get-Command $cmdName -All -ErrorAction SilentlyContinue)
			} catch {
				$result.Errors.Add("Błąd przy Get-Command '$cmdName': $($_.Exception.Message)")
				continue
			}
			if (-not $cmds -or $cmds.Count -eq 0) { continue }

			$ordered = $cmds |
				Where-Object { $_ -and $_.Source } |
				Sort-Object -Property @(
					@{ Expression = { if ($_.Source -match '\\Microsoft\\WindowsApps\\python(3)?\\.exe$') { 2 } else { 0 } } },
					@{ Expression = { $_.Source.Length } }
				)

			foreach ($c in $ordered) {
				$src = $c.Source
				if ($src -match '\\Microsoft\\WindowsApps\\python(3)?\\.exe$') {
					$result.Errors.Add("Wykryto alias WindowsApps dla '$cmdName': '$src'. To może nie być realny Python (App Execution Alias).")
					continue
				}

				$realExe = Try-GetPythonSysExecutable -PythonPath $src
				if (-not $realExe) {
					$result.Errors.Add("Nie udało się uzyskać sys.executable z '$src'.")
					continue
				}

				$result.Installed  = $true
				$result.InPath     = $true
				$result.PythonHome = $realExe
				$ver = Try-GetPythonVersion -PythonPath $src
				if ($ver) { $result.Version = $ver }
				if ($src -match '[\\/]\.pyenv[\\/]|[\\/]pyenv-win[\\/]') { $result.Manager = 'pyenv-win' }
				break
			}

			if ($result.PythonHome) { break }
		}
	}

	# -------------------------------------------------------------------------
	# 3) Walidacja zmiennych środowiskowych / misconfig
	# -------------------------------------------------------------------------

	try {
		$pythonHomeEnv = Get-EnvVarValue -Name 'PYTHONHOME'
		if ($pythonHomeEnv -and -not (Test-Path $pythonHomeEnv)) {
			$result.Errors.Add("PYTHONHOME wskazuje na nieistniejącą ścieżkę: '$pythonHomeEnv'")
		}
	} catch {
		$result.Errors.Add("Błąd przy odczycie PYTHONHOME: $($_.Exception.Message)")
	}

	if ($result.Manager -eq 'pyenv-win' -and $pyenvRoot) {
		$shimsDir = Join-Path $pyenvRoot 'shims'
		$shimsInPath = (
			(Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $shimsDir) -or
			(Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $shimsDir) -or
			(Test-PathContainsDirectory -PathVariableValue $processPath -Directory $shimsDir)
		)
		if (-not $shimsInPath) {
			$result.Errors.Add("pyenv-win: katalog shims nie występuje w PATH (Machine/User/Process): '$shimsDir'")
		} else {
			$result.InPath = $true
		}
	}

	# -------------------------------------------------------------------------
	# 4) Fallback: search_system_for_compiler
	# -------------------------------------------------------------------------

	if (-not $result.PythonHome) {
		try {
			$pythonPossiblePaths = @(
				"$env:LOCALAPPDATA\\Programs\\Python",
				"C:\\Python312",
				"C:\\Python311",
				"C:\\Python310",
				"C:\\Python39",
				"C:\\Python38",
				"$env:USERPROFILE\\.pyenv\\pyenv-win\\shims",
				"$env:USERPROFILE\\.pyenv\\pyenv-win\\versions",
				"$env:USERPROFILE\\scoop\\apps\\python",
				"$env:USERPROFILE\\scoop\\apps\\pyenv",
				"C:\\ProgramData\\chocolatey\\lib\\python",
				"$env:USERPROFILE\\anaconda3",
				"$env:USERPROFILE\\miniconda3",
				"$env:LOCALAPPDATA\\anaconda3",
				"$env:LOCALAPPDATA\\miniconda3",
				"C:\\ProgramData\\Anaconda3",
				"C:\\ProgramData\\Miniconda3"
			)

			$found = search_system_for_compiler `
				-CompilerNames     @('python', 'python3') `
				-CompilerExtension 'exe' `
				-SearchPaths       $pythonPossiblePaths `
				-Depth             4

			if ($found.Count -gt 0) {
				$best = $found | Where-Object { $_.CompilerName -eq 'python3' } | Select-Object -First 1
				if (-not $best) { $best = $found | Where-Object { $_.CompilerName -eq 'python' } | Select-Object -First 1 }

				$result.Installed  = $true
				$result.InPath     = $false
				$result.PythonHome = $best.FullPath
				$ver = Try-GetPythonVersion -PythonPath $best.FullPath
				if ($ver) { $result.Version = $ver }

				if ($best.FullPath -match '[\\/]\.pyenv[\\/]|[\\/]pyenv-win[\\/]') {
					$result.Manager = 'pyenv-win'
				} elseif ($best.FullPath -match '[\\/]anaconda|[\\/]miniconda') {
					$result.Manager = 'conda'
				} elseif ($best.FullPath -match '[\\/]scoop[\\/]') {
					$result.Manager = 'scoop'
				} elseif ($best.FullPath -match '[\\/]chocolatey[\\/]') {
					$result.Manager = 'chocolatey'
				}

				$result.Errors.Add("Znaleziono '$($best.CompilerName).exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie katalogu do PATH.")
			}
		} catch {
			$result.Errors.Add("Błąd podczas wywołania search_system_for_compiler: $($_.Exception.Message)")
		}
	}

	$result.Errors = $result.Errors.ToArray()
	return $result
}

Export-ModuleMember -Function check_python_interpreter
