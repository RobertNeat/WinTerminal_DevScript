function Get-ExecutableToken {
    param([string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $null }
    $s = $CommandLine.Trim()
    if ($s.StartsWith('"')) {
        $m = [regex]::Match($s, '^[\"]([^\"]+)[\"]')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    $m2 = [regex]::Match($s, '^(\S+)')
    if ($m2.Success) { return $m2.Groups[1].Value }
    return $null
}

Export-ModuleMember -Function Get-ExecutableToken