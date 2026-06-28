# Parses the Python version from output text.
# [input-param] Line: text line containing the version number
# [output-param] string|null: version in major.minor.patch format, or null
function ConvertFrom-PythonVersionText {
	param([string]$Line)
	if (-not $Line) { return $null }
	if ($Line -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
	return $null
}

Export-ModuleMember -Function ConvertFrom-PythonVersionText