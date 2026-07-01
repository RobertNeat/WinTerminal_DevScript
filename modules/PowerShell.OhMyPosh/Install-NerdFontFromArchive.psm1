Import-Module (Join-Path $PSScriptRoot '..\Terminal.UI\Request-SetupTerminalConsent.psm1') -ErrorAction Stop

# Installs a Nerd Font directly from the official Nerd Fonts release archive.
# [input-param] Name: Nerd Fonts archive font name, for example FiraCode
# [input-param] Scope: font installation scope
# [output-param] None.
# [side-effect] Downloads a Nerd Fonts archive, extracts it, registers contained font files, and removes temporary files.
function Install-NerdFontFromArchive {
    param(
        [string] $Name,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser'
    )

    function Install-FontFile {
        param(
            [System.IO.FileInfo] $FontFile,
            [string] $InstallScope
        )

        $extension = $FontFile.Extension.ToLowerInvariant()
        $fontType = if ($extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
        $registryName = '{0} ({1})' -f $FontFile.BaseName, $fontType

        if ($InstallScope -eq 'AllUsers') {
            $targetDirectory = Join-Path $env:WINDIR 'Fonts'
            $registryPath = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            $registryValue = $FontFile.Name
        } else {
            $targetDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
            $registryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            $registryValue = Join-Path $targetDirectory $FontFile.Name
        }

        if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $FontFile.FullName -Destination (Join-Path $targetDirectory $FontFile.Name) -Force
        New-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -PropertyType String -Force | Out-Null
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Setup-Terminal-NerdFont-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $tempRoot ($Name + '.zip')
    $extractPath = Join-Path $tempRoot 'extracted'
    $downloadUri = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Name.zip"

    $downloadApproved = Request-SetupTerminalConsent `
        -Title "Download Nerd Font archive: $Name" `
        -Description 'The setup will download a font archive before any font files are installed.' `
        -Sources @($downloadUri) `
        -Consequence "The archive will be stored temporarily under '$tempRoot' and removed after installation." `
        -DefaultNo

    if (-not $downloadApproved) {
        throw "Nerd Font download was skipped by the user: $Name"
    }

    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $downloadUri -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $fontFiles = @(Get-ChildItem -Path $extractPath -Recurse -File -Include '*.ttf', '*.otf')
        if ($fontFiles.Count -eq 0) {
            throw "No font files were found in $downloadUri."
        }

        $installApproved = Request-SetupTerminalConsent `
            -Title "Install downloaded Nerd Font files: $Name" `
            -Description ("The archive was downloaded and extracted. The setup found {0} font file(s)." -f $fontFiles.Count) `
            -Sources @($downloadUri) `
            -Consequence "The font files will be registered with Windows using scope '$Scope'." `
            -DefaultNo

        if (-not $installApproved) {
            throw "Nerd Font installation was skipped by the user after download: $Name"
        }

        foreach ($fontFile in $fontFiles) {
            Install-FontFile -FontFile $fontFile -InstallScope $Scope
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Install-NerdFontFromArchive
