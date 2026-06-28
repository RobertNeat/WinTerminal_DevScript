# Gets an environment variable value from Machine, User, or the current process.
# [input-param] Name: environment variable name
# [output-param] string|null: first found variable value
# [side-effect] Reads system and user environment variables.
function Get-EnvironmentVariableValue {
	param(
		[Parameter(Mandatory = $true)][string]$Name
	)

	$value = [System.Environment]::GetEnvironmentVariable($Name, 'Machine')
	if (-not $value) {
		$value = [System.Environment]::GetEnvironmentVariable($Name, 'User')
	}
	if (-not $value) {
		$value = [System.Environment]::GetEnvironmentVariable($Name)  # bieżący proces
	}
	return $value
}

Export-ModuleMember -Function Get-EnvironmentVariableValue