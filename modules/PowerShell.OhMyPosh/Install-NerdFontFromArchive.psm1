# Installs a Nerd Font directly from the official Nerd Fonts release archive.
# [input-param] Name: Nerd Fonts archive font name, for example FiraCode
# [input-param] Scope: font installation scope passed to Fonts\Install-Font
# [output-param] None.
# [side-effect] Downloads a Nerd Fonts archive, extracts it, installs contained font files, and removes temporary files.
function Install-NerdFontFromArchive {
    param(
        [string] $Name,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser'
    )

    function Import-FontsModule {
        if (-not (Get-Module -ListAvailable -Name Fonts)) {
            Install-PSResource -Name Fonts -Scope CurrentUser -TrustRepository -Reinstall -ErrorAction Stop
        }

        Import-Module -Name Fonts -Force -ErrorAction Stop
        if (-not (Get-Command -Name 'Fonts\Install-Font' -ErrorAction SilentlyContinue)) {
            throw 'The Fonts module could not be imported.'
        }
    }

    Import-FontsModule

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Setup-Terminal-NerdFont-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $tempRoot ($Name + '.zip')
    $extractPath = Join-Path $tempRoot 'extracted'

    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    try {
        $downloadUri = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Name.zip"
        Invoke-WebRequest -Uri $downloadUri -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $fontFiles = @(Get-ChildItem -Path $extractPath -Recurse -File -Include '*.ttf', '*.otf')
        if ($fontFiles.Count -eq 0) {
            throw "No font files were found in $downloadUri."
        }

        Fonts\Install-Font -Path $extractPath -Scope $Scope -Force
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Install-NerdFontFromArchive
