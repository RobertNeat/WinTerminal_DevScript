# Infers the Git installation manager from the executable path.
# [input-param] ExePath: path to git.exe
# [output-param] string|null: manager name, e.g. scoop, chocolatey, msys2, or git-for-windows
function Get-GitInstallationManager {
	param([string]$ExePath)
	if (-not $ExePath) { return $null }
	if ($ExePath -match '(?i)\\scoop\\apps\\') { return 'scoop' }
	if ($ExePath -match '(?i)\\chocolatey\\') { return 'chocolatey' }
	if ($ExePath -match '(?i)\\msys64\\|\\msys2\\') { return 'msys2' }
	if ($ExePath -match '(?i)\\Program Files\\Git\\') { return 'git-for-windows' }
	return $null
}


Export-ModuleMember -Function Get-GitInstallationManager
