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