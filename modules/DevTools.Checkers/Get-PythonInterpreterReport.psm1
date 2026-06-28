Import-Module ".\modules\DevTools.Search\Find-ExecutableFile.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\Get-EnvironmentVariableValue.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\ConvertTo-NormalizedPathEntry.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\Test-PathContainsDirectory.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Python\Get-PythonSysExecutable.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Python\Get-PythonVersion.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Python\Get-PyenvRoot.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Python\Resolve-PyenvPythonShim.psm1" -ErrorAction Stop


# Checks the Python interpreter installation and pyenv-win configuration.
# [output-param] PSCustomObject: report with Name, Installed, InPath, Version, AllVersions, Manager, PythonHome, and Errors fields
# [side-effect] Runs python/pyenv shims, reads environment variables, and searches common installation directories.
function Get-PythonInterpreterReport {
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



	$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
	$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
	$processPath = $env:Path

	# -------------------------------------------------------------------------
	# 1) pyenv-win FIRST
	# -------------------------------------------------------------------------

	$pyenvRoot = Get-PyenvRoot
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

		$shim = Resolve-PyenvPythonShim -PyenvRoot $pyenvRoot
		if ($shim) {
			$realExe = Get-PythonSysExecutable -PythonPath $shim
			if ($realExe) {
				$result.Installed  = $true
				$result.PythonHome = $realExe
				$ver = Get-PythonVersion -PythonPath $shim
				if ($ver) { $result.Version = $ver }
			} else {
				$result.Errors.Add("pyenv-win: nie udało się uzyskać sys.executable z shima: '$shim'.")
			}
		} else {
			$result.Errors.Add("pyenv-win: nie znaleziono shima python (python.bat/python3.bat/python.exe) w '$shimsDir'.")
		}

		if (-not $result.Version -and $result.PythonHome) {
			$ver = Get-PythonVersion -PythonPath $result.PythonHome
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

				$realExe = Get-PythonSysExecutable -PythonPath $src
				if (-not $realExe) {
					$result.Errors.Add("Nie udało się uzyskać sys.executable z '$src'.")
					continue
				}

				$result.Installed  = $true
				$result.InPath     = $true
				$result.PythonHome = $realExe
				$ver = Get-PythonVersion -PythonPath $src
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
		$pythonHomeEnv = Get-EnvironmentVariableValue -Name 'PYTHONHOME'
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
	# 4) Fallback: Find-ExecutableFile
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

			$found = Find-ExecutableFile `
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
				$ver = Get-PythonVersion -PythonPath $best.FullPath
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
			$result.Errors.Add("Błąd podczas wywołania Find-ExecutableFile: $($_.Exception.Message)")
		}
	}

	$result.Errors = $result.Errors.ToArray()
	return $result
}

Export-ModuleMember -Function Get-PythonInterpreterReport
