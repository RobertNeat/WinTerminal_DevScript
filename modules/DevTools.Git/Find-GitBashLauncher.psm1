Import-Module ".\modules\DevTools.Git\Get-GitCandidateRoot.psm1" -ErrorAction Stop

# Finds bash.exe or git-bash.exe for the detected Git installation.
# [input-param] GitExePath: full path to git.exe
# [output-param] string|null: path to bash.exe/git-bash.exe, or null when not found
# [side-effect] Checks file existence in Git installation directories.
function Find-GitBashLauncher {
	param(
		[Parameter(Mandatory = $true)][string]$GitExePath
	)

	$roots = Get-GitCandidateRoot -GitExePath $GitExePath
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


Export-ModuleMember -Function Find-GitBashLauncher
