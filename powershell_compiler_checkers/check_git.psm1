Import-Module ".\powershell_compiler_checkers\search_system_for_compiler"

function check_git {
	$result = [PSCustomObject]@{
		Name            = "Git"
		Installed       = $false
		InPath          = $false
		Version         = $null
		LatestVersion   = $null
		UpdateAvailable = $false
		WingetAvailable = $false
		GitHome         = $null
		BashHome        = $null
		Manager         = $null
		GitExecPath     = $null
		GitSsh          = $null
		GitSshCommand   = $null
		GitAskPass      = $null
		Errors          = (New-Object System.Collections.Generic.List[string])
	}

	function Get-GitCandidateRoots {
		param(
			[Parameter(Mandatory = $true)][string]$GitExePath
		)

		$roots = New-Object System.Collections.Generic.List[string]

		function Add-Root {
			param([string]$Path)
			if (-not $Path) { return }
			$norm = Normalize-Dir $Path
			if (-not $norm) { return }
			if (-not ($roots.Contains($norm))) {
				$roots.Add($norm)
			}
		}

		try {
			$gitExeDir = Split-Path $GitExePath -Parent
			Add-Root (Split-Path $gitExeDir -Parent) # ...\Git\cmd\git.exe -> ...\Git
			Add-Root $gitExeDir
		} catch {
			# ignore
		}

		try {
			# Git for Windows typically returns something like:
			#   C:\Program Files\Git\mingw64\libexec\git-core
			# or C:\Program Files\Git\libexec\git-core
			$execPathOut = & $GitExePath --exec-path 2>$null
			$execPath = ($execPathOut | Select-Object -First 1 | Out-String).Trim()
			if ($execPath) {
				Add-Root (Split-Path (Split-Path $execPath -Parent) -Parent) # trim \libexec\git-core
				Add-Root (Split-Path $execPath -Parent)
				Add-Root $execPath
				# handle mingw64\libexec\git-core by also trying to trim one more segment
				$parent = Split-Path (Split-Path (Split-Path $execPath -Parent) -Parent) -Parent
				Add-Root $parent
			}
		} catch {
			# ignore; not fatal
		}

		return $roots.ToArray()
	}

	function Find-GitBashLauncher {
		param(
			[Parameter(Mandatory = $true)][string]$GitExePath
		)

		$roots = Get-GitCandidateRoots -GitExePath $GitExePath
		foreach ($root in $roots) {
			# Prefer real bash.exe shipped with Git for Windows
			$candidates = @(
				(Join-Path $root 'usr\bin\bash.exe'),
				(Join-Path $root 'bin\bash.exe'),
				(Join-Path $root 'mingw64\bin\bash.exe'),
				(Join-Path $root 'git-bash.exe')
			)

			foreach ($candidate in $candidates) {
				try {
					if ($candidate -and (Test-Path $candidate)) {
						return $candidate
					}
				} catch {
					# ignore
				}
			}
		}

		return $null
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

	function Try-ParseGitVersion {
		param([string]$VersionString)
		if (-not $VersionString) { return $null }
		# git --version -> np. "git version 2.45.1.windows.1"
		if ($VersionString -match '(?i)git\s+version\s+([0-9]+\.[0-9]+\.[0-9]+(?:\.[^\s]+)?)') {
			return $Matches[1]
		}
		# fallback: pierwszy sensowny ciąg wersji
		if ($VersionString -match '(\d+\.\d+\.\d+(?:\.\d+)?)') {
			return $Matches[1]
		}
		return $null
	}

	function Try-ParseComparableVersion {
		param([string]$VersionString)
		if (-not $VersionString) { return $null }
		if ($VersionString -match '(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?') {
			$maj = $Matches[1]
			$min = $Matches[2]
			$pat = $Matches[3]
			$bld = if ($Matches[4]) { $Matches[4] } else { '0' }
			try {
				return [Version]"$maj.$min.$pat.$bld"
			} catch {
				return $null
			}
		}
		return $null
	}

	function Infer-ManagerFromPath {
		param([string]$ExePath)
		if (-not $ExePath) { return $null }
		if ($ExePath -match '(?i)\\scoop\\apps\\') { return 'scoop' }
		if ($ExePath -match '(?i)\\chocolatey\\') { return 'chocolatey' }
		if ($ExePath -match '(?i)\\msys64\\|\\msys2\\') { return 'msys2' }
		if ($ExePath -match '(?i)\\Program Files\\Git\\') { return 'git-for-windows' }
		return $null
	}

	# -------------------------------------------------------------------------
	# 1. Sprawdzenie git.exe w PATH + wersja
	# -------------------------------------------------------------------------

	$gitCmd = $null
	foreach ($candidate in @('git.exe', 'git')) {
		try {
			$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
			if ($cmd) {
				$gitCmd = $cmd
				break
			}
		} catch {
			$result.Errors.Add("Błąd przy Get-Command '$candidate': $($_.Exception.Message)")
		}
	}

	if ($gitCmd) {
		try {
			$gitVersionOut = & $gitCmd.Source --version 2>&1
			$gitVersionStr = $gitVersionOut | Select-Object -First 1 | Out-String
			$parsed = Try-ParseGitVersion $gitVersionStr

			if ($parsed) {
				$result.Installed  = $true
				$result.InPath     = $true
				$result.Version    = $parsed
				$result.GitHome    = $gitCmd.Source
				$result.BashHome   = Find-GitBashLauncher -GitExePath $gitCmd.Source
				$result.Manager    = Infer-ManagerFromPath $gitCmd.Source
				if (-not $result.BashHome) {
					$result.Errors.Add("Nie udało się odnaleźć bash.exe (ani git-bash.exe) dla wykrytego Git: '$($gitCmd.Source)'.")
				}
			} else {
				$result.Errors.Add("Nie udało się sparsować wersji Git z 'git --version'. Surowy wynik: '$($gitVersionStr.Trim())'")
			}
		} catch {
			$result.Errors.Add("Błąd przy wywołaniu git --version: $($_.Exception.Message)")
		}
	}

	# -------------------------------------------------------------------------
	# 2. Sprawdzenie zmiennych środowiskowych (Path + wybrane GIT_*)
	# -------------------------------------------------------------------------

	try {
		$result.GitExecPath   = Get-EnvVarValue -Name 'GIT_EXEC_PATH'
		$result.GitSsh        = Get-EnvVarValue -Name 'GIT_SSH'
		$result.GitSshCommand = Get-EnvVarValue -Name 'GIT_SSH_COMMAND'
		$result.GitAskPass    = Get-EnvVarValue -Name 'GIT_ASKPASS'
	} catch {
		$result.Errors.Add("Błąd przy odczycie zmiennych GIT_*: $($_.Exception.Message)")
	}

	try {
		$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
		$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
		$processPath = $env:Path

		if ($result.GitHome) {
			$gitExeDir = Split-Path $result.GitHome -Parent
			$hasInMachine = Test-PathContainsDirectory -PathVariableValue $machinePath -Directory $gitExeDir
			$hasInUser    = Test-PathContainsDirectory -PathVariableValue $userPath    -Directory $gitExeDir
			$hasInProcess = Test-PathContainsDirectory -PathVariableValue $processPath -Directory $gitExeDir
			if (-not ($hasInMachine -or $hasInUser -or $hasInProcess)) {
				$result.Errors.Add("Katalog z git.exe nie występuje w PATH (Machine/User/Process): '$gitExeDir'")
			}
		}

		if ($result.GitExecPath) {
			if (-not (Test-Path $result.GitExecPath)) {
				$result.Errors.Add("GIT_EXEC_PATH wskazuje na nieistniejącą ścieżkę: '$($result.GitExecPath)'")
			}
		}
	} catch {
		$result.Errors.Add("Błąd przy analizie PATH: $($_.Exception.Message)")
	}

	# -------------------------------------------------------------------------
	# 3. Jeśli nie znaleziono w PATH — przeszukaj popularne lokalizacje
	# -------------------------------------------------------------------------

	if (-not $result.Installed) {
		try {
			$possiblePaths = @(
				"$env:ProgramFiles\\Git",
				"$env:ProgramFiles(x86)\\Git",
				"$env:LOCALAPPDATA\\Programs\\Git",
				"$env:USERPROFILE\\scoop\\apps",
				"C:\\ProgramData\\chocolatey\\bin",
				"C:\\ProgramData\\chocolatey\\lib",
				"C:\\msys64",
				"C:\\msys2"
			) | Where-Object { $_ -and (Test-Path $_) }

			$found = search_system_for_compiler `
				-CompilerNames     @('git') `
				-CompilerExtension 'exe' `
				-SearchPaths       $possiblePaths `
				-Depth             5

			if ($found.Count -gt 0) {
				# Preferuj Git for Windows: ...\Git\cmd\git.exe
				$best = $found |
					Sort-Object -Property @(
						@{ Expression = { if ($_.FullPath -match '(?i)\\Git\\cmd\\git\.exe$') { 0 } elseif ($_.FullPath -match '(?i)\\Git\\bin\\git\.exe$') { 1 } else { 2 } } },
						@{ Expression = { $_.FullPath.Length } }
					) |
					Select-Object -First 1

				$result.Installed  = $true
				$result.GitHome    = $best.FullPath
				$result.BashHome   = Find-GitBashLauncher -GitExePath $best.FullPath
				$result.Manager    = Infer-ManagerFromPath $best.FullPath
				$result.Errors.Add("Znaleziono 'git.exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie '$($best.Directory)' do PATH.")
				if (-not $result.BashHome) {
					$result.Errors.Add("Nie udało się odnaleźć bash.exe (ani git-bash.exe) dla znalezionego Git: '$($best.FullPath)'.")
				}

				try {
					$verOut = & $best.FullPath --version 2>&1
					$verStr = $verOut | Select-Object -First 1 | Out-String
					$parsed = Try-ParseGitVersion $verStr
					if ($parsed) {
						$result.Version = $parsed
					} else {
						$result.Errors.Add("Nie udało się sparsować wersji Git z pliku '$($best.FullPath)'. Surowy wynik: '$($verStr.Trim())'")
					}
				} catch {
					$result.Errors.Add("Błąd przy wywołaniu '$($best.FullPath) --version': $($_.Exception.Message)")
				}
			}
		} catch {
			$result.Errors.Add("Błąd podczas wywołania search_system_for_compiler dla git: $($_.Exception.Message)")
		}
	}

	# -------------------------------------------------------------------------
	# 4. Sprawdź, czy jest nowsza wersja przez winget (bez instalacji)
	# -------------------------------------------------------------------------

	try {
		$wingetCmd = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
		if (-not $wingetCmd) {
			$wingetCmd = Get-Command 'winget' -ErrorAction SilentlyContinue
		}

		if ($wingetCmd) {
			$result.WingetAvailable = $true
			$showOut = & $wingetCmd.Source show --id Git.Git -e --source winget --accept-source-agreements 2>&1
			foreach ($line in $showOut) {
				$s = ($line | Out-String).Trim()
				if ($s -match '^Version:\s*(\S+)') {
					$result.LatestVersion = $Matches[1]
					break
				}
			}
			if (-not $result.LatestVersion) {
				# fallback: spróbuj wyciągnąć pierwszą wersję z całego outputu
				$joined = ($showOut | Out-String)
				if ($joined -match '(\d+\.\d+\.\d+(?:\.\d+)?)') {
					$result.LatestVersion = $Matches[1]
				}
			}
		}
	} catch {
		$result.Errors.Add("Błąd przy sprawdzaniu wersji w winget: $($_.Exception.Message)")
	}

	# Porównanie wersji (tylko jeśli mamy obie)
	try {
		if ($result.Version -and $result.LatestVersion) {
			$installedComparable = Try-ParseComparableVersion $result.Version
			$latestComparable    = Try-ParseComparableVersion $result.LatestVersion
			if ($installedComparable -and $latestComparable) {
				$result.UpdateAvailable = ($latestComparable -gt $installedComparable)
			}
		}
	} catch {
		# nie traktujemy tego jako błąd krytyczny
	}

	$result.Errors = $result.Errors.ToArray()
	return $result
}

Export-ModuleMember -Function check_git
