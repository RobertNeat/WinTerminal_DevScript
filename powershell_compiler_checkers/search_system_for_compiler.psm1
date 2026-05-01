function search_system_for_compiler {
    param(
        [string[]] $CompilerNames,
        [string]   $CompilerExtension,
        [string[]] $SearchPaths,
        [int]      $Depth = 3
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($searchPath in $SearchPaths) {
        if (-not (Test-Path $searchPath)) { continue }

        foreach ($compilerName in $CompilerNames) {
            $executableName = "$compilerName.$CompilerExtension"

            # Przeszukiwanie w głąb do $Depth poziomów
            Get-ChildItem -Path $searchPath -Filter $executableName `
                -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
            ForEach-Object {
                $results.Add([PSCustomObject]@{
                    CompilerName = $compilerName
                    FullPath     = $_.FullName
                    Directory    = $_.DirectoryName
                })
            }
        }
    }

    return $results
}

Export-ModuleMember -Function check_java_compiler