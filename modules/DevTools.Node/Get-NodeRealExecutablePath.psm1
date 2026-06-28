# Determines the real node.exe path for the active Node.js process.
# [input-param] NodePath: path to node.exe or the node command
# [output-param] string|null: real path from fs.realpathSync(process.execPath), or null
# [side-effect] Runs Node.js with a JavaScript expression that reads the real process path.
function Get-NodeRealExecutablePath {
	param([Parameter(Mandatory = $true)][string]$NodePath)
	try {
		# W nvm-windows node bywa uruchamiany przez symlink/junction (np. C:\nvm\nodejs\node.exe).
		# process.execPath może wskazywać ścieżkę logiczną; fs.realpathSync daje ścieżkę docelową.
		$out = & $NodePath @('-p', "require('fs').realpathSync(process.execPath)") 2>&1
		$line = ($out | Select-Object -First 1 | Out-String).Trim()
		if ($line -and (Test-Path $line)) { return $line }
	} catch {
		return $null
	}
	return $null
}

Export-ModuleMember -Function Get-NodeRealExecutablePath