# Gets the real sys.executable path for the specified Python interpreter.
# [input-param] PythonPath: path to python.exe, python3.exe, or a pyenv shim
# [output-param] string|null: path from sys.executable, or null
# [side-effect] Runs Python with a short command that imports sys.
function Get-PythonSysExecutable {
	param([Parameter(Mandatory = $true)][string]$PythonPath)
	try {
		$out = & $PythonPath @('-c', 'import sys; print(sys.executable)') 2>&1
		$line = ($out | Select-Object -First 1 | Out-String).Trim()
		if ($line -and (Test-Path $line)) { return $line }
	} catch {
		return $null
	}
	return $null
}

Export-ModuleMember -Function Get-PythonSysExecutable