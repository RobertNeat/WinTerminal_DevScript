# Normalizes a PATH entry for directory comparisons.
# [input-param] Path: single path entry, optionally quoted
# [output-param] string|null: normalized path without a trailing separator, or null
function ConvertTo-NormalizedPathEntry {
	param([string]$Path)
	if (-not $Path) { return $null }
	$p = $Path.Trim()
	if ($p.StartsWith('"') -and $p.EndsWith('"')) {
		$p = $p.Trim('"')
	}
	return $p.Trim().TrimEnd('\\')
}

Export-ModuleMember -Function ConvertTo-NormalizedPathEntry