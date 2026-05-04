Import-Module ".\powershell_compiler_checkers\search_system_for_compiler"

function check_node_runtime {
	$result = [PSCustomObject]@{
		Name        = "Node.js Runtime"
		Installed   = $false
		InPath      = $false
		Version     = $null
		AllVersions = @()
		Manager     = $null
		NodeHome    = $null
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

	# -------------------------------------------------------------------------
	# 1. Sprawdzenie node.exe w PATH (PowerShell 5.1)
	# -------------------------------------------------------------------------

	$nodeCmd = $null
	foreach ($candidate in @('node.exe', 'node')) {
		try {
			$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
			if ($cmd) {
				$nodeCmd = $cmd
				break
			}
		} catch {
			$result.Errors.Add("Błąd przy Get-Command '$candidate': $($_.Exception.Message)")
		}
	}

	if ($nodeCmd) {
		try {
			$nodeVersionOut = & $nodeCmd.Source --version 2>&1
			$nodeVersionStr = $nodeVersionOut | Select-Object -First 1 | Out-String
			$parsed = Try-ParseNodeVersion $nodeVersionStr

			if ($parsed) {
				$result.Installed = $true
				$result.InPath    = $true
				$result.Version   = $parsed
				$result.NodeHome  = Split-Path $nodeCmd.Source -Parent
			} else {
				$result.Errors.Add("Nie udało się sparsować wersji Node.js z 'node --version'. Surowy wynik: '$($nodeVersionStr.Trim())'")
			}
		} catch {
			$result.Errors.Add("Błąd przy wywołaniu node --version: $($_.Exception.Message)")
		}
	}

	# -------------------------------------------------------------------------
	# 2. Sprawdzenie Node Version Manager (nvm-windows)
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

		# Aktywna wersja (jeśli node nie został wykryty powyżej)
		if (-not $result.Version) {
			try {
				$currentOut = & $nvmCmd.Source current 2>&1
				$currentStr = $currentOut | Select-Object -First 1 | Out-String
				$parsed = Try-ParseNodeVersion $currentStr
				if ($parsed) {
					$result.Version = $parsed
				}
			} catch {
				# nie traktujemy jako błąd krytyczny (nvm current nie zawsze działa)
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

		# Jeśli mamy node wykryty w PATH, sprawdzamy czy jego katalog faktycznie jest w PATH
		if ($result.NodeHome) {
			$hasInMachine = Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $result.NodeHome
			$hasInUser    = Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $result.NodeHome
			$hasInProcess = Test-PathContainsDirectory -PathVariableValue $processPath -Directory $result.NodeHome
			if (-not ($hasInMachine -or $hasInUser -or $hasInProcess)) {
				$result.Errors.Add("NodeHome nie występuje w PATH (Machine/User/Process): '$($result.NodeHome)'")
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
				$result.NodeHome  = $best.Directory
				$result.Errors.Add("Znaleziono 'node.exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie '$($best.Directory)' do PATH lub skonfiguruj nvm-windows (NVM_HOME/NVM_SYMLINK).")

				try {
					$verOut = & $best.FullPath --version 2>&1
					$verStr = $verOut | Select-Object -First 1 | Out-String
					$parsed = Try-ParseNodeVersion $verStr
					if ($parsed) {
						$result.Version = $parsed
					} else {
						$result.Errors.Add("Nie udało się sparsować wersji Node.js z pliku '$($best.FullPath)'. Surowy wynik: '$($verStr.Trim())'")
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
