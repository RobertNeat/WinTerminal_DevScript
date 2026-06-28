Import-Module ".\modules\DevTools.Node\ConvertFrom-NodeVersionText.psm1" -ErrorAction Stop

# Gets and parses the Node.js version for the specified executable.
# [input-param] NodePath: path to node.exe or the node command
# [output-param] string|null: parsed Node.js version, or null
# [side-effect] Runs node --version.
function Get-NodeVersion {
	param([Parameter(Mandatory = $true)][string]$NodePath)
	try {
		$out = & $NodePath @('--version') 2>&1
		$line = ($out | Select-Object -First 1 | Out-String).Trim()
		return (ConvertFrom-NodeVersionText $line)
	} catch {
		return $null
	}
}

Export-ModuleMember -Function Get-NodeVersion