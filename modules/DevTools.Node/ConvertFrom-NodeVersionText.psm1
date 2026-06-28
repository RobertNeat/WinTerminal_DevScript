# Parses the Node.js version from node --version or nvm text.
# [input-param] VersionString: text containing the Node.js version
# [output-param] string|null: version without the v prefix, or null when the format does not match
function ConvertFrom-NodeVersionText {
	param([string]$VersionString)
	if (-not $VersionString) { return $null }
	# node --version zwraca np. "v20.11.1"
	if ($VersionString -match 'v?(\d+\.\d+\.\d+)') {
		return $Matches[1]
	}
	return $null
}

Export-ModuleMember -Function ConvertFrom-NodeVersionText
