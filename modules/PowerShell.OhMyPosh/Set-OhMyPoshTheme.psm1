Import-Module (Join-Path $PSScriptRoot 'Get-OhMyPoshThemePath.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'Get-OhMyPoshReleaseMetadataUri.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'Set-OhMyPoshThemePerformanceOptions.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\Terminal.UI\Request-SetupTerminalConsent.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot '..\Utils\Invoke-VerifiedReleaseDownload.psm1') -ErrorAction Stop

# Sets the Oh My Posh theme selection used by the PowerShell profile.
# [input-param] ThemeName: theme file name to apply
# [input-param] ReleaseTag: Oh My Posh release tag to use, or latest
# [input-param] ThemeDirectory: destination directory where the theme file should be stored
# [output-param] String: validated full path to the selected theme
# [side-effect] Creates or updates the selected theme file in ThemeDirectory.
function Set-OhMyPoshTheme {
    param(
        [string] $ThemeName = 'marcduiker.omp.json',

        [string] $ReleaseTag = 'latest',

        [string] $ThemeDirectory
    )

    function Get-OhMyPoshThemesArchiveAsset {
        param([string] $MetadataUri)

        $release = Invoke-RestMethod -Uri $MetadataUri -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -eq 'themes.zip' } | Select-Object -First 1
        if (-not $asset) {
            throw "Oh My Posh release '$($release.tag_name)' does not contain themes.zip."
        }

        $digestMatch = [regex]::Match([string] $asset.digest, '^sha256:(?<Hash>[a-fA-F0-9]{64})$')
        if ([string]::IsNullOrWhiteSpace($asset.digest) -or -not $digestMatch.Success) {
            throw "Oh My Posh themes.zip release asset does not expose a SHA-256 digest."
        }

        return [PSCustomObject]@{
            Tag       = $release.tag_name
            Uri       = $asset.browser_download_url
            Sha256    = $digestMatch.Groups['Hash'].Value.ToUpperInvariant()
            AssetName = $asset.name
        }
    }

    function Copy-ThemeFromArchive {
        param(
            [string] $ArchivePath,
            [string] $ThemeFileName,
            [string] $DestinationPath
        )

        $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) ('Setup-Terminal-OhMyPoshThemes-' + [guid]::NewGuid().ToString('N'))
        try {
            Expand-Archive -LiteralPath $ArchivePath -DestinationPath $extractPath -Force

            $themeFiles = @(Get-ChildItem -Path $extractPath -Recurse -File | Where-Object { $_.Name -eq $ThemeFileName })
            if ($themeFiles.Count -eq 0) {
                throw "Theme '$ThemeFileName' was not found in $ArchivePath."
            }

            if ($themeFiles.Count -gt 1) {
                throw "Theme '$ThemeFileName' is ambiguous in $ArchivePath. Found $($themeFiles.Count) matching files."
            }

            Copy-Item -LiteralPath $themeFiles[0].FullName -Destination $DestinationPath -Force
        } finally {
            if (Test-Path -LiteralPath $extractPath) {
                Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($ThemeDirectory)) {
        $projectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $ThemeDirectory = Join-Path $projectRoot 'resources\oh-my-posh'
    }

    $themePath = Join-Path $ThemeDirectory $ThemeName

    if (-not (Test-Path -LiteralPath $ThemeDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $ThemeDirectory -Force | Out-Null
    }

    $releaseMetadataUri = Get-OhMyPoshReleaseMetadataUri -Tag $ReleaseTag
    $downloadApproved = Request-SetupTerminalConsent `
        -Title 'Download Oh My Posh themes archive' `
        -Description "The setup will resolve an Oh My Posh release, download themes.zip, verify its SHA-256 digest, and extract '$ThemeName'." `
        -Sources @($releaseMetadataUri, 'release asset: themes.zip') `
        -Consequence "The selected theme will be saved to '$themePath' and used by the PowerShell profile." `
        -DefaultNo

    try {
        if (-not $downloadApproved) {
            throw 'Theme download was skipped by the user.'
        }

        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Setup-Terminal-OhMyPoshThemeDownload-' + [guid]::NewGuid().ToString('N'))
        $archivePath = Join-Path $tempRoot 'themes.zip'
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        try {
            $themesArchive = Get-OhMyPoshThemesArchiveAsset -MetadataUri $releaseMetadataUri
            Write-Host "Downloading Oh My Posh themes archive: $($themesArchive.Tag)/$($themesArchive.AssetName)"
            Invoke-VerifiedReleaseDownload `
                -Uri $themesArchive.Uri `
                -OutFile $archivePath `
                -ExpectedSha256 $themesArchive.Sha256 | Out-Null

            Copy-ThemeFromArchive -ArchivePath $archivePath -ThemeFileName $ThemeName -DestinationPath $themePath
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "Oh My Posh themes archive download failed: $($_.Exception.Message)"
        Write-Host "Trying installed/local Oh My Posh theme sources."
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
