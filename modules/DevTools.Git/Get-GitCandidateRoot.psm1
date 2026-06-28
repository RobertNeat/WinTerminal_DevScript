Import-Module ".\modules\DevTools.Utils\ConvertTo-NormalizedPathEntry.psm1" -ErrorAction Stop

# Determines Git installation base directories from the git.exe path.
# [input-param] GitExePath: full path to git.exe
# [output-param] string[]: unique candidate directories where Git files may be located
# [side-effect] Runs git --exec-path for the provided path.
function Get-GitCandidateRoot {
	param(
		[Parameter(Mandatory = $true)][string]$GitExePath
	)

	$roots = New-Object System.Collections.Generic.List[string]

	# Adds a unique Git base directory to the local result list.
	# [input-param] Path: directory path to normalize and add
	# [side-effect] Modifies the parent function's local roots list.
	function Add-Root {
		param([string]$Path)
		if (-not $Path) { return }
		$norm = ConvertTo-NormalizedPathEntry $Path
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

Export-ModuleMember -Function Get-GitCandidateRoot