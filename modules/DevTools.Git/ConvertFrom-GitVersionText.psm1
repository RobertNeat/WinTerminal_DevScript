# Parses the Git version from text returned by git --version.
# [input-param] VersionString: text containing the Git version
# [output-param] string|null: parsed version, or null when the format does not match
function ConvertFrom-GitVersionText {
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

Export-ModuleMember -Function ConvertFrom-GitVersionText
