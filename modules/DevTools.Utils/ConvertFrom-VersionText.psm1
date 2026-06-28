# Parses version text into a Version object suitable for comparisons.
# [input-param] VersionString: Git version text or winget version text
# [output-param] Version|null: version in major.minor.patch.build format, or null when parsing fails
function ConvertFrom-VersionText {
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


Export-ModuleMember -Function ConvertFrom-VersionText
