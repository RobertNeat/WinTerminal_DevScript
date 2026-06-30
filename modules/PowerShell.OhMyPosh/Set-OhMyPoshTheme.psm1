Import-Module ".\modules\PowerShell.OhMyPosh\Get-OhMyPoshThemePath.psm1" -ErrorAction Stop
Import-Module ".\modules\PowerShell.OhMyPosh\Set-OhMyPoshThemePerformanceOptions.psm1" -ErrorAction Stop
Import-Module ".\modules\Terminal.UI\Request-SetupTerminalConsent.psm1" -ErrorAction Stop

# Sets the Oh My Posh theme selection used by the PowerShell profile.
# [input-param] ThemeName: theme file name to apply
# [input-param] ThemeDirectory: destination directory where the theme file should be stored
# [output-param] String: validated full path to the selected theme
# [side-effect] Creates or updates the selected theme file in ThemeDirectory.
function Set-OhMyPoshTheme {
    param(
        [string] $ThemeName = 'marcduiker.omp.json',

        [string] $ThemeUrl = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/marcduiker.omp.json',

        [string] $ThemeDirectory
    )

    if ([string]::IsNullOrWhiteSpace($ThemeDirectory)) {
        $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $ThemeDirectory = Join-Path $projectRoot 'resources\oh-my-posh'
    }

    $themePath = Join-Path $ThemeDirectory $ThemeName

    if (-not (Test-Path -LiteralPath $ThemeDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $ThemeDirectory -Force | Out-Null
    }

    $downloadApproved = Request-SetupTerminalConsent `
        -Title 'Download Oh My Posh theme' `
        -Description "The setup will download the '$ThemeName' theme file and store it next to the Windows Terminal settings file." `
        -Sources @($ThemeUrl) `
        -Consequence "The downloaded theme will be saved to '$themePath' and used by the PowerShell profile." `
        -DefaultNo

    try {
        if (-not $downloadApproved) {
            throw 'Theme download was skipped by the user.'
        }

        Write-Host "Downloading Oh My Posh theme: $ThemeName"
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $themePath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "Theme download failed. Trying installed/local Oh My Posh theme sources."
        try {
            $sourceThemePath = Get-OhMyPoshThemePath -ThemeName $ThemeName
            Copy-Item -LiteralPath $sourceThemePath -Destination $themePath -Force
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
