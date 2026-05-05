Import-Module ".\powershell_compiler_checkers\search_system_for_compiler"

function check_node_runtime {
	$result = [PSCustomObject]@{
		Name        = "Node.js Runtime"
		Installed   = $false
		InPath      = $false
		Version     = $null
		AllVersions = @()
		Manager     = $null
		NodeHome    = $null  # pełna ścieżka do wykonywalnego node.exe (real path dla nvm-windows)
		NvmHome     = $null
		NvmSymlink  = $null
		Errors      = (New-Object System.Collections.Generic.List[string])
	}

	function Get-EnvVarValue {
		param(
			[Parameter(Mandatory = $true)][string]$Name
		)

		$value = [System.Environment]::GetEnvironmentVariable($Name, 'Machine')
		if (-not $value) {
			$value = [System.Environment]::GetEnvironmentVariable($Name, 'User')
		}
		if (-not $value) {
			$value = [System.Environment]::GetEnvironmentVariable($Name)  # bieżący proces
		}
		return $value
	}

	function Normalize-Dir {
		param([string]$Path)
		if (-not $Path) { return $null }
		return ($Path.Trim().TrimEnd('\\'))
	}

	function Test-PathContainsDirectory {
		param(
			[string]$PathVariableValue,
			[string]$Directory
		)

		if (-not $PathVariableValue -or -not $Directory) { return $false }
		$dirNorm = Normalize-Dir $Directory
		if (-not $dirNorm) { return $false }

		foreach ($entry in ($PathVariableValue -split ';')) {
			$entryNorm = Normalize-Dir $entry
			if ($entryNorm -and ($entryNorm -ieq $dirNorm)) {
				return $true
			}
		}

		return $false
	}

	function Try-ParseNodeVersion {
		param([string]$VersionString)
		if (-not $VersionString) { return $null }
		# node --version zwraca np. "v20.11.1"
		if ($VersionString -match 'v?(\d+\.\d+\.\d+)') {
			return $Matches[1]
		}
		return $null
	}

	function Try-GetNodeRealExecutablePath {
		param([Parameter(Mandatory = $true)][string]$NodePath)
		try {
			# W nvm-windows node bywa uruchamiany przez symlink/junction (np. C:\nvm\nodejs\node.exe).
			# process.execPath może wskazywać ścieżkę logiczną; fs.realpathSync daje ścieżkę docelową.
			$out = & $NodePath @('-p', "require('fs').realpathSync(process.execPath)") 2>&1
			$line = ($out | Select-Object -First 1 | Out-String).Trim()
			if ($line -and (Test-Path $line)) { return $line }
		} catch {
			return $null
		}
		return $null
	}

	function Try-GetNodeVersion {
		param([Parameter(Mandatory = $true)][string]$NodePath)
		try {
			$out = & $NodePath @('--version') 2>&1
			$line = ($out | Select-Object -First 1 | Out-String).Trim()
			return (Try-ParseNodeVersion $line)
		} catch {
			return $null
		}
	}

	# -------------------------------------------------------------------------
	# 1. Sprawdzenie Node Version Manager (nvm-windows) FIRST
	# -------------------------------------------------------------------------

	$nvmCmd = $null
	foreach ($candidate in @('nvm.exe', 'nvm')) {
		try {
			$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
			if ($cmd) {
				$nvmCmd = $cmd
				break
			}
		} catch {
			$result.Errors.Add("Błąd przy Get-Command '$candidate': $($_.Exception.Message)")
		}
	}

	if ($nvmCmd) {
		$result.Manager = 'nvm-windows'

		# aktywna wersja wg nvm (opcjonalnie, bo nvm current czasem nie działa)
		try {
			$currentOut = & $nvmCmd.Source current 2>&1
			$currentStr = $currentOut | Select-Object -First 1 | Out-String
			$parsedCurrent = Try-ParseNodeVersion $currentStr
			if ($parsedCurrent) {
				$result.Version = $parsedCurrent
			}
		} catch {
			# ignorujemy
		}

		# Spróbuj pobrać listę wersji (nie przerywa, nawet gdy node jest już wykryty)
		try {
			$listOut = & $nvmCmd.Source list 2>&1
			$versions = New-Object System.Collections.Generic.List[string]
			foreach ($line in $listOut) {
				$s = ($line | Out-String).Trim()
				if ($s -match 'v?(\d+\.\d+\.\d+)') {
					$versions.Add($Matches[1])
				}
			}
			if ($versions.Count -gt 0) {
				$result.AllVersions = @($versions.ToArray() | Select-Object -Unique)
			}
		} catch {
			$result.Errors.Add("Błąd przy wywołaniu 'nvm list': $($_.Exception.Message)")
		}

		# Jeżeli node jest w PATH, pobierz realny node.exe (omijamy symlink NVM_SYMLINK)
		$nodeCmd = $null
		foreach ($candidate in @('node.exe', 'node')) {
			try {
				$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
				if ($cmd) { $nodeCmd = $cmd; break }
			} catch {
				$result.Errors.Add("Błąd przy Get-Command '$candidate': $($_.Exception.Message)")
			}
		}

		if ($nodeCmd) {
			$ver = Try-GetNodeVersion -NodePath $nodeCmd.Source
			if ($ver) { $result.Version = $ver }

			$realNodeExe = Try-GetNodeRealExecutablePath -NodePath $nodeCmd.Source
			if ($realNodeExe) {
				$result.Installed = $true
				$result.InPath    = $true
				$result.NodeHome  = $realNodeExe
			} else {
				# Fallback: spróbuj złożyć ścieżkę na podstawie NVM_HOME + wersji
				try {
					$nvmHomeCandidate = Get-EnvVarValue -Name 'NVM_HOME'
					if ($nvmHomeCandidate -and (Test-Path $nvmHomeCandidate) -and $result.Version) {
						foreach ($folderName in @("v$($result.Version)", "$($result.Version)")) {
							$candidateExe = Join-Path (Join-Path $nvmHomeCandidate $folderName) 'node.exe'
							if (Test-Path $candidateExe) {
								$result.Installed = $true
								$result.InPath    = $true
								$result.NodeHome  = $candidateExe
								break
							}
						}
					}
				} catch {
					# ignorujemy
				}

				if (-not $result.NodeHome) {
					$result.Errors.Add("nvm-windows: wykryto node w PATH jako '$($nodeCmd.Source)', ale nie udało się rozwiązać realnej ścieżki do node.exe (fs.realpathSync(process.execPath)).")
				}
			}
		} else {
			# nvm jest, ale node nie jest w PATH
			$result.Errors.Add("nvm-windows: wykryto nvm, ale nie wykryto 'node' w PATH.")
		}
	}

	# -------------------------------------------------------------------------
	# 2. Sprawdzenie klasycznej instalacji node (dopiero jeśli nie mamy realnego node.exe powyżej)
	# -------------------------------------------------------------------------

	if (-not $result.NodeHome) {
		$nodeCmd = $null
		foreach ($candidate in @('node.exe', 'node')) {
			try {
				$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
				if ($cmd) { $nodeCmd = $cmd; break }
			} catch {
				$result.Errors.Add("Błąd przy Get-Command '$candidate': $($_.Exception.Message)")
			}
		}

		if ($nodeCmd) {
			$ver = Try-GetNodeVersion -NodePath $nodeCmd.Source
			if ($ver) {
				$result.Installed = $true
				$result.InPath    = $true
				$result.Version   = $ver
				$result.NodeHome  = $nodeCmd.Source
			} else {
				$result.Errors.Add("Nie udało się sparsować wersji Node.js z 'node --version' dla '$($nodeCmd.Source)'.")
			}
		}
	}

	# -------------------------------------------------------------------------
	# 3. Sprawdzenie zmiennych środowiskowych (PATH, NVM_HOME, NVM_SYMLINK)
	# -------------------------------------------------------------------------

	try {
		$nvmHome = Get-EnvVarValue -Name 'NVM_HOME'
		if ($nvmHome) {
			if (Test-Path $nvmHome) {
				$result.NvmHome = $nvmHome
			} else {
				$result.Errors.Add("NVM_HOME wskazuje na nieistniejącą ścieżkę: '$nvmHome'")
			}
		}

		$nvmSymlink = Get-EnvVarValue -Name 'NVM_SYMLINK'
		if ($nvmSymlink) {
			if (Test-Path $nvmSymlink) {
				$result.NvmSymlink = $nvmSymlink
			} else {
				$result.Errors.Add("NVM_SYMLINK wskazuje na nieistniejącą ścieżkę: '$nvmSymlink'")
			}
		}
	} catch {
		$result.Errors.Add("Błąd przy odczycie zmiennych NVM_HOME/NVM_SYMLINK: $($_.Exception.Message)")
	}

	try {
		$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
		$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
		$processPath = $env:Path

		# Jeśli mamy klasyczne node.exe wykryte w PATH, sprawdzamy czy jego katalog jest w PATH.
		# Dla nvm-windows: realny node.exe znajduje się w NVM_HOME\vX.Y.Z, który NIE musi być w PATH (w PATH jest NVM_SYMLINK).
		if ($result.NodeHome -and $result.Manager -ne 'nvm-windows') {
			$nodeDir = Split-Path $result.NodeHome -Parent
			$hasInMachine = Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $nodeDir
			$hasInUser    = Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $nodeDir
			$hasInProcess = Test-PathContainsDirectory -PathVariableValue $processPath -Directory $nodeDir
			if (-not ($hasInMachine -or $hasInUser -or $hasInProcess)) {
				$result.Errors.Add("Katalog node.exe nie występuje w PATH (Machine/User/Process): '$nodeDir'")
			}
		}

		# Dla nvm-windows oczekujemy, że w PATH będą NVM_HOME i NVM_SYMLINK
		if ($result.NvmHome) {
			$hasNvmHome = (
				(Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $result.NvmHome) -or
				(Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $result.NvmHome) -or
				(Test-PathContainsDirectory -PathVariableValue $processPath -Directory $result.NvmHome)
			)
			if (-not $hasNvmHome) {
				$result.Errors.Add("NVM_HOME nie występuje w PATH (Machine/User/Process): '$($result.NvmHome)'")
			}
		}

		if ($result.NvmSymlink) {
			$hasNvmSym = (
				(Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $result.NvmSymlink) -or
				(Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $result.NvmSymlink) -or
				(Test-PathContainsDirectory -PathVariableValue $processPath -Directory $result.NvmSymlink)
			)
			if (-not $hasNvmSym) {
				$result.Errors.Add("NVM_SYMLINK nie występuje w PATH (Machine/User/Process): '$($result.NvmSymlink)'")
			}
		}
	} catch {
		$result.Errors.Add("Błąd przy analizie PATH: $($_.Exception.Message)")
	}

	# -------------------------------------------------------------------------
	# 4. Jeśli nadal nie znaleziono node — przeszukaj popularne lokalizacje
	# -------------------------------------------------------------------------

	if (-not $result.Installed) {
		try {
			$possiblePaths = @(
				"$env:ProgramFiles\\nodejs",
				"$env:ProgramFiles(x86)\\nodejs",
				"$env:LOCALAPPDATA\\Programs\\nodejs",
				"$env:APPDATA\\nvm",
				"C:\\Program Files\\nodejs",
				"C:\\Program Files (x86)\\nodejs",
				"$env:USERPROFILE\\scoop\\apps",
				"C:\\ProgramData\\chocolatey\\bin",
				"C:\\ProgramData\\chocolatey\\lib"
			) | Where-Object { $_ -and (Test-Path $_) }

			$found = search_system_for_compiler `
				-CompilerNames     @('node') `
				-CompilerExtension 'exe' `
				-SearchPaths       $possiblePaths `
				-Depth             5

			if ($found.Count -gt 0) {
				$best = $found |
					Sort-Object -Property @(
						@{ Expression = { if ($_.FullPath -match '\\nodejs\\node\.exe$') { 0 } elseif ($_.FullPath -match '\\nvm\\v?\d+\.\d+\.\d+\\node\.exe$') { 1 } else { 2 } } },
						@{ Expression = { $_.FullPath.Length } }
					) |
					Select-Object -First 1

				$result.Installed = $true
				$result.NodeHome  = $best.FullPath
				$result.Errors.Add("Znaleziono 'node.exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie katalogu do PATH lub skonfiguruj nvm-windows (NVM_HOME/NVM_SYMLINK).")

				try {
					$ver = Try-GetNodeVersion -NodePath $best.FullPath
					if ($ver) {
						$result.Version = $ver
					} else {
						$result.Errors.Add("Nie udało się sparsować wersji Node.js z pliku '$($best.FullPath)'.")
					}
				} catch {
					$result.Errors.Add("Błąd przy wywołaniu '$($best.FullPath) --version': $($_.Exception.Message)")
				}
			}
		} catch {
			$result.Errors.Add("Błąd podczas wywołania search_system_for_compiler dla node: $($_.Exception.Message)")
		}
	}

	$result.Errors = $result.Errors.ToArray()
	return $result
}

Export-ModuleMember -Function check_node_runtime
