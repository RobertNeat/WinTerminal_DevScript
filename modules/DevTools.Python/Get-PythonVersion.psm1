
Import-Module ".\modules\DevTools.Python\ConvertFrom-PythonVersionText.psm1" -ErrorAction Stop

# Gets and parses the Python version for the specified interpreter.
# [input-param] PythonPath: path to python.exe, python3.exe, or a pyenv shim
# [output-param] string|null: parsed Python version, or null
# [side-effect] Runs python --version.
function Get-PythonVersion {
	param([Parameter(Mandatory = $true)][string]$PythonPath)
	try {
		$out = & $PythonPath @('--version') 2>&1
		$line = ($out | Select-Object -First 1 | Out-String).Trim()
		return (ConvertFrom-PythonVersionText $line)
	} catch {
		return $null
	}
}


Export-ModuleMember -Function Get-PythonVersion