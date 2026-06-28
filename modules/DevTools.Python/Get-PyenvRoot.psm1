Import-Module ".\modules\DevTools.Utils\Get-EnvironmentVariableValue.psm1" -ErrorAction Stop

# Finds the pyenv-win root directory.
# [output-param] string|null: PYENV_ROOT/PYENV path or the default pyenv-win path
# [side-effect] Reads environment variables and appends errors to the parent function's report.
function Get-PyenvRoot {
	$pyenvRoot = $null
	foreach ($varName in @('PYENV_ROOT', 'PYENV')) {
		$candidate = Get-EnvironmentVariableValue -Name $varName
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


Export-ModuleMember -Function Get-PyenvRoot