# Tests whether the current PowerShell process should run interactive profile setup.
# [output-param] Boolean: true when the session is interactive and was not started for command/file execution
# [side-effect] None.
function Test-SetupTerminalInteractiveProfile {
    $nonInteractiveArguments = @('-command', '-c', '-encodedcommand', '-ec', '-file', '-f', '-noninteractive')

    foreach ($argument in [Environment]::GetCommandLineArgs()) {
        if ($nonInteractiveArguments -contains $argument.ToLowerInvariant()) {
            return $false
        }
    }

    return [Environment]::UserInteractive
}

Export-ModuleMember -Function Test-SetupTerminalInteractiveProfile
