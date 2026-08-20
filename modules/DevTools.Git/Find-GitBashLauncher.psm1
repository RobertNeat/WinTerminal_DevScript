Import-Module (Join-Path $PSScriptRoot 'Get-GitCandidateRoot.psm1') -ErrorAction Stop

# Finds a bash.exe belonging to the detected Git installation and selects it by
# the environment it actually starts. git-bash.exe is deliberately excluded:
# it is a terminal launcher and would open a separate window from Windows Terminal.
# [input-param] GitExePath: full path to git.exe
# [output-param] string|null: path to the best bash.exe, or null when none can be started
# [side-effect] Recursively discovers bash.exe files below Git installation roots and runs each with echo "$MSYSTEM".
function Find-GitBashLauncher {
	param(
		[Parameter(Mandatory = $true)][string]$GitExePath
	)

	$paths = New-Object System.Collections.Generic.List[string]
	$seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

	foreach ($root in @(Get-GitCandidateRoot -GitExePath $GitExePath)) {
		try {
			if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

			# Do not assume a particular Git for Windows directory layout. Searching
			# specifically for bash.exe also keeps git-bash.exe out of the result.
			foreach ($item in @(Get-ChildItem -LiteralPath $root -Filter 'bash.exe' -File -Recurse -ErrorAction SilentlyContinue)) {
				if ($item -and $seenPaths.Add($item.FullName)) {
					$paths.Add($item.FullName)
				}
			}
		} catch {
			# One inaccessible candidate root must not prevent checking the others.
		}
	}

	$verified = foreach ($path in $paths) {
		try {
			# --login is important: the low-level MSYS bash initializes MSYSTEM as
			# MSYS only during login, while Git for Windows' wrapper reports MINGW64.
			$output = & $path '--login' '-c' 'echo "$MSYSTEM"' 2>$null
			if ($LASTEXITCODE -ne 0) { continue }

			$msystem = @($output |
				ForEach-Object { ([string]$_).Trim() } |
				Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
				Select-Object -Last 1)[0]
			if ([string]::IsNullOrWhiteSpace($msystem)) { continue }

			# MINGW64 is the preferred interoperable Git for Windows environment.
			# Other MinGW variants remain better choices than raw MSYS/MSYS2, which
			# is retained solely as the final fallback.
			$rank = if ($msystem -ieq 'MINGW64') {
				0
			} elseif ($msystem -match '^(?i:MINGW|UCRT|CLANG)') {
				1
			} elseif ($msystem -match '^(?i:MSYS|MSYS2)$') {
				3
			} else {
				2
			}

			[PSCustomObject]@{
				Path    = $path
				MSystem = $msystem
				Rank    = $rank
			}
		} catch {
			# A discovered file that cannot be executed is not a usable shell.
		}
	}

	$best = $verified |
		Sort-Object -Property @(
			@{ Expression = { $_.Rank } },
			@{ Expression = { $_.Path.Length } },
			@{ Expression = { $_.Path } }
		) |
		Select-Object -First 1

	if ($best) { return $best.Path }
	return $null
}

Export-ModuleMember -Function Find-GitBashLauncher
