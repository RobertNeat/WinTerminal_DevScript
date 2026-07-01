# Tests whether the current console host can run the interactive setup TUI.
# [output-param] Boolean: true when the host supports interactive key input and unredirected console output; otherwise false.
# [side-effect] Probes console properties and suppresses host capability exceptions.
function Test-TerminalSetupInteractiveHost {
    try {
        if (-not [Environment]::UserInteractive) {
            return $false
        }

        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
            return $false
        }

        $null = [Console]::KeyAvailable
        return $true
    }
    catch {
        return $false
    }
}

Export-ModuleMember -Function Test-TerminalSetupInteractiveHost
