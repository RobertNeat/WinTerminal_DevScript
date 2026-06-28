# Searches the specified directories for compiler or runtime executables.
# [input-param] CompilerNames: program names without extension, e.g. git, node, or python
# [input-param] CompilerExtension: file extension, e.g. exe
# [input-param] SearchPaths: starting directories to search
# [input-param] Depth: maximum recursion depth for Get-ChildItem
# [output-param] PSCustomObject[]: result list with CompilerName, FullPath, and Directory
# [side-effect] Reads the directory structure under the provided SearchPaths.
function Find-ExecutableFile {
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

Export-ModuleMember -Function Find-ExecutableFile
