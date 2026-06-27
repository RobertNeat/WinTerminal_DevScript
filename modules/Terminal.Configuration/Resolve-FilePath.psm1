# Resolves the path to an executable file or to a file inside a directory.
# [input-param] Candidate: path to a file or directory to check
# [input-param] FallbackRelativePaths: relative paths checked inside Candidate when Candidate is a directory
# [output-param] string|null: full path to the found file, or null when nothing matches
function Resolve-FilePath {
    param(
        [string]$Candidate,
        [string[]]$FallbackRelativePaths
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    $c = $Candidate.Trim().Trim('"')

    try {
        if (Test-Path -LiteralPath $c) {
            $item = Get-Item -LiteralPath $c -ErrorAction SilentlyContinue
            if ($item -and -not $item.PSIsContainer) {
                return $item.FullName
            }
            if ($item -and $item.PSIsContainer) {
                foreach ($rel in $FallbackRelativePaths) {
                    $p = Join-Path $item.FullName $rel
                    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
                }
            }
        }
    } catch {
        return $null
    }

    return $null
}


Export-ModuleMember -Function Resolve-FilePath
