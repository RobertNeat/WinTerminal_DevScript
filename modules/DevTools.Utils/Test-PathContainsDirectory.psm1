Import-Module ".\modules\DevTools.Utils\ConvertTo-NormalizedPathEntry.psm1" -ErrorAction Stop

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
    $dirNorm = ConvertTo-NormalizedPathEntry $Directory
	if (-not $dirNorm) { return $false }

	foreach ($entry in ($PathVariableValue -split ';')) {
		$entryNorm = ConvertTo-NormalizedPathEntry $entry
		if ($entryNorm -and ($entryNorm -ieq $dirNorm)) {
			return $true
		}
	}

	return $false
}


Export-ModuleMember -Function Test-PathContainsDirectory
