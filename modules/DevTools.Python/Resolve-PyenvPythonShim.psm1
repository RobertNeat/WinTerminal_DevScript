# Finds a Python shim in the pyenv-win directory.
# [input-param] PyenvRoot: pyenv-win root directory
# [output-param] string|null: path to the first found python/python3 shim
# [side-effect] Checks file existence in the shims directory.
function Resolve-PyenvPythonShim {
	param([Parameter(Mandatory = $true)][string]$PyenvRoot)
	$shimsDir = Join-Path $PyenvRoot 'shims'
	$candidates = @(
		(Join-Path $shimsDir 'python.bat'),
		(Join-Path $shimsDir 'python3.bat'),
		(Join-Path $shimsDir 'python.cmd'),
		(Join-Path $shimsDir 'python3.cmd'),
		(Join-Path $shimsDir 'python.exe'),
		(Join-Path $shimsDir 'python3.exe')
	)
	foreach ($p in $candidates) {
		if (Test-Path $p) { return $p }
	}
	return $null
}

Export-ModuleMember -Function Resolve-PyenvPythonShim