# Resolves an Oh My Posh theme file path from the installed themes directories.
# [input-param] ThemeName: theme file name to find
# [output-param] String: full path to the matching Oh My Posh theme file
# [side-effect] None.
function Get-OhMyPoshThemePath {
    param(
        [string] $ThemeName = 'marcduiker.omp.json'
    )

    $candidateRoots = @()

    if (-not [string]::IsNullOrWhiteSpace($env:POSH_THEMES_PATH)) {
        $candidateRoots += $env:POSH_THEMES_PATH
    }

    foreach ($basePath in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not [string]::IsNullOrWhiteSpace($basePath)) {
            $candidateRoots += (Join-Path $basePath 'oh-my-posh\themes')
            $candidateRoots += (Join-Path $basePath 'Programs\oh-my-posh\themes')
        }
    }

    $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $candidateRoots += (Join-Path $projectRoot 'resources\oh-my-posh')

    foreach ($root in ($candidateRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $candidate = Join-Path $root $ThemeName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Oh My Posh theme was not found: $ThemeName"
}

Export-ModuleMember -Function Get-OhMyPoshThemePath
