Import-Module ".\modules\DevTools.Search\Find-ExecutableFile.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\Get-EnvironmentVariableValue.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\ConvertTo-NormalizedPathEntry.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\Test-PathContainsDirectory.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Utils\ConvertFrom-VersionText.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Git\Find-GitBashLauncher.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Git\Get-GitInstallationManager.psm1" -ErrorAction Stop
Import-Module ".\modules\DevTools.Git\ConvertFrom-GitVersionText.psm1" -ErrorAction Stop

# Checks the Git for Windows installation and related tool configuration.
# [output-param] PSCustomObject: report with Name, Installed, InPath, Version, LatestVersion, UpdateAvailable, WingetAvailable, GitHome, BashHome, Manager, GitExecPath, GitSsh, GitSshCommand, GitAskPass, and Errors fields
# [side-effect] Runs git and winget, reads environment variables, and searches common installation directories.
function Get-GitInstallationReport {
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
			$parsed = ConvertFrom-GitVersionText $gitVersionStr

			if ($parsed) {
				$result.Installed  = $true
				$result.InPath     = $true
				$result.Version    = $parsed
				$result.GitHome    = $gitCmd.Source
				$result.BashHome   = Find-GitBashLauncher -GitExePath $gitCmd.Source
				$result.Manager    = Get-GitInstallationManager $gitCmd.Source
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
		$result.GitExecPath   = Get-EnvironmentVariableValue -Name 'GIT_EXEC_PATH'
		$result.GitSsh        = Get-EnvironmentVariableValue -Name 'GIT_SSH'
		$result.GitSshCommand = Get-EnvironmentVariableValue -Name 'GIT_SSH_COMMAND'
		$result.GitAskPass    = Get-EnvironmentVariableValue -Name 'GIT_ASKPASS'
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

			$found = Find-ExecutableFile `
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
				$result.Manager    = Get-GitInstallationManager $best.FullPath
				$result.Errors.Add("Znaleziono 'git.exe' poza PATH: '$($best.FullPath)'. Rozważ dodanie '$($best.Directory)' do PATH.")
				if (-not $result.BashHome) {
					$result.Errors.Add("Nie udało się odnaleźć bash.exe (ani git-bash.exe) dla znalezionego Git: '$($best.FullPath)'.")
				}

				try {
					$verOut = & $best.FullPath --version 2>&1
					$verStr = $verOut | Select-Object -First 1 | Out-String
					$parsed = ConvertFrom-GitVersionText $verStr
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
			$result.Errors.Add("Błąd podczas wywołania Find-ExecutableFile dla git: $($_.Exception.Message)")
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
			$installedComparable = ConvertFrom-VersionText $result.Version
			$latestComparable    = ConvertFrom-VersionText $result.LatestVersion
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

Export-ModuleMember -Function Get-GitInstallationReport
