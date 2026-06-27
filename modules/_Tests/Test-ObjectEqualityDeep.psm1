
# Compares two objects recursively with support for JSON-shaped PowerShell structures.
# [input-param] Left: first object to compare
# [input-param] Right: second object to compare
# [input-param] MaxDepth: maximum depth for recursive comparison
# [input-param] Depth: current recursion depth used by internal calls
# [output-param] bool: true when the objects are equal according to deep comparison
function Test-ObjectEqualityDeep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Left,

        [Parameter(Mandatory = $true)]
        $Right,

        [Parameter(Mandatory = $false)]
        [int] $MaxDepth = 200,

        [Parameter(Mandatory = $false)]
        [int] $Depth = 0
    )

    if ($Depth -gt $MaxDepth) {
        return $true
    }

    if ($null -eq $Left -and $null -eq $Right) { return $true }
    if ($null -eq $Left -or $null -eq $Right) { return $false }

    # Treat numeric types as numeric, regardless of exact CLR type
    $leftIsNumber = $Left -is [byte] -or $Left -is [sbyte] -or $Left -is [int16] -or $Left -is [uint16] -or $Left -is [int32] -or $Left -is [uint32] -or $Left -is [int64] -or $Left -is [uint64] -or $Left -is [single] -or $Left -is [double] -or $Left -is [decimal]
    $rightIsNumber = $Right -is [byte] -or $Right -is [sbyte] -or $Right -is [int16] -or $Right -is [uint16] -or $Right -is [int32] -or $Right -is [uint32] -or $Right -is [int64] -or $Right -is [uint64] -or $Right -is [single] -or $Right -is [double] -or $Right -is [decimal]
    if ($leftIsNumber -and $rightIsNumber) {
        try { return ([decimal]$Left -eq [decimal]$Right) } catch { return ([double]$Left -eq [double]$Right) }
    }

    # Strings / bools / simple scalars
    if ($Left -is [string] -or $Right -is [string]) { return ([string]$Left -ceq [string]$Right) }
    if ($Left -is [bool] -or $Right -is [bool]) { return ([bool]$Left -eq [bool]$Right) }
    if ($Left -is [datetime] -or $Right -is [datetime]) { return ([datetime]$Left -eq [datetime]$Right) }

    # Arrays / lists (order matters)
    $leftIsEnumerable = ($Left -is [System.Collections.IEnumerable]) -and -not ($Left -is [string]) -and -not ($Left -is [System.Collections.IDictionary])
    $rightIsEnumerable = ($Right -is [System.Collections.IEnumerable]) -and -not ($Right -is [string]) -and -not ($Right -is [System.Collections.IDictionary])
    if ($leftIsEnumerable -or $rightIsEnumerable) {
        if (-not ($leftIsEnumerable -and $rightIsEnumerable)) { return $false }

        $l = @($Left)
        $r = @($Right)
        if ($l.Count -ne $r.Count) { return $false }

        for ($i = 0; $i -lt $l.Count; $i++) {
            if (-not (Test-ObjectEqualityDeep -Left $l[$i] -Right $r[$i] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # Dictionaries / hashtables (order does not matter)
    if ($Left -is [System.Collections.IDictionary] -or $Right -is [System.Collections.IDictionary]) {
        if (-not ($Left -is [System.Collections.IDictionary] -and $Right -is [System.Collections.IDictionary])) { return $false }

        if ($Left.Keys.Count -ne $Right.Keys.Count) { return $false }
        foreach ($k in $Left.Keys) {
            if (-not $Right.Contains($k)) { return $false }
            if (-not (Test-ObjectEqualityDeep -Left $Left[$k] -Right $Right[$k] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # PSCustomObject / other objects: compare note properties by name (order does not matter)
    $leftProps = @($Left.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
    $rightProps = @($Right.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })

    # JSON empty objects become empty PSCustomObject instances; treat them as equal.
    if (
        $leftProps.Count -eq 0 -and
        $rightProps.Count -eq 0 -and
        $Left.GetType().FullName -eq 'System.Management.Automation.PSCustomObject' -and
        $Right.GetType().FullName -eq 'System.Management.Automation.PSCustomObject'
    ) {
        return $true
    }

    if ($leftProps.Count -gt 0 -or $rightProps.Count -gt 0) {
        if ($leftProps.Count -ne $rightProps.Count) { return $false }

        $rightMap = @{}
        foreach ($p in $rightProps) { $rightMap[$p.Name] = $p.Value }

        foreach ($p in $leftProps) {
            if (-not $rightMap.ContainsKey($p.Name)) { return $false }
            if (-not (Test-ObjectEqualityDeep -Left $p.Value -Right $rightMap[$p.Name] -MaxDepth $MaxDepth -Depth ($Depth + 1))) { return $false }
        }
        return $true
    }

    # Fallback: direct comparison
    return ($Left -eq $Right)
}

Export-ModuleMember -Function Test-ObjectEqualityDeep
