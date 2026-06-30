# Runs an external command while rendering a compact console spinner.
# [input-param] FilePath: executable to run
# [input-param] ArgumentList: command arguments passed to the executable
# [input-param] Message: text displayed before the spinner glyph
# [output-param] PSCustomObject: process exit code
# [side-effect] Starts an external process and writes spinner status to the console.
function Invoke-ConsoleSpinnerCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    function ConvertTo-ProcessArgumentText {
        param([string] $Argument)

        if ($Argument -notmatch '[\s"]') {
            return $Argument
        }

        $escapedArgument = $Argument -replace '(\\+)"', '$1$1"'
        $escapedArgument = $escapedArgument -replace '(\\+)$', '$1$1'
        $escapedArgument = $escapedArgument -replace '"', '\"'
        return "`"$escapedArgument`""
    }

    $escapedArguments = $ArgumentList | ForEach-Object {
        ConvertTo-ProcessArgumentText -Argument ([string] $_)
    }
    $argumentText = $escapedArguments -join ' '

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $argumentText
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    [void] $process.Start()

    $frames = @('\', '|', '/', '-')
    $frameIndex = 0

    while (-not $process.HasExited) {
        Write-Host ("`r{0} {1}" -f $Message, $frames[$frameIndex]) -NoNewline
        $frameIndex = ($frameIndex + 1) % $frames.Count
        Start-Sleep -Milliseconds 120
    }

    $process.WaitForExit()
    Write-Host ("`r{0} done" -f $Message)

    [PSCustomObject]@{
        ExitCode       = $process.ExitCode
        StandardOutput = ''
        StandardError  = ''
    }
}

Export-ModuleMember -Function Invoke-ConsoleSpinnerCommand
