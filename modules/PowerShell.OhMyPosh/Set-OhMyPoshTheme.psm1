Import-Module ".\modules\PowerShell.OhMyPosh\Get-OhMyPoshThemePath.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Set-OhMyPoshThemePerformanceOptions.psm1" -ErrorAction Stop

# Sets the Oh My Posh theme selection used by the PowerShell profile.
# [input-param] ThemeName: theme file name to apply
# [output-param] String: validated full path to the selected theme
# [side-effect] None.
function Set-OhMyPoshTheme {
    param(
        [string] $ThemeName = 'marcduiker.omp.json',

        [string] $ThemeUrl = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/marcduiker.omp.json'
    )

    $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $themeDirectory = Join-Path $projectRoot 'resources\oh-my-posh'
    $themePath = Join-Path $themeDirectory $ThemeName

    if (-not (Test-Path -LiteralPath $themeDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $themeDirectory -Force | Out-Null
    }

    try {
        Write-Host "Downloading Oh My Posh theme: $ThemeName"
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $themePath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "Theme download failed. Trying installed/local Oh My Posh theme sources."
        try {
            $themePath = Get-OhMyPoshThemePath -ThemeName $ThemeName
        } catch {
            $ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
            if (-not $ohMyPosh) {
                throw 'oh-my-posh is required to export the selected theme.'
            }

            $themeId = $ThemeName -replace '\.omp\.json$', ''

            Write-Host "Oh My Posh theme was not found locally. Exporting built-in theme: $themeId"
            $themeJson = & $ohMyPosh.Source config export --config $themeId
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($themeJson -join "`n"))) {
                throw "Oh My Posh theme could not be exported: $themeId"
            }

            $themeJson | Set-Content -LiteralPath $themePath -Encoding UTF8
        }
    }

    Set-OhMyPoshThemePerformanceOptions -Path $themePath

    $themePath = (Resolve-Path -LiteralPath $themePath).Path
    Write-Host "Oh My Posh theme selected: $themePath"

    return $themePath
}

Export-ModuleMember -Function Set-OhMyPoshTheme
