# Tests whether Windows can resolve an installed Nerd Font.
# [input-param] Name: Nerd Fonts archive/module font name, for example FiraCode
# [input-param] ExpectedFontFace: expected Windows font face name, for example FiraCode Nerd Font
# [output-param] Boolean: true when the font is registered or present in a Windows font directory
# [side-effect] None.
function Test-NerdFontInstalled {
    param(
        [string] $Name,

        [string] $ExpectedFontFace
    )

    $fontRegistryPaths = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )

    foreach ($fontRegistryPath in $fontRegistryPaths) {
        if (-not (Test-Path -LiteralPath $fontRegistryPath)) { continue }

        $matchingFont = (Get-ItemProperty -Path $fontRegistryPath).PSObject.Properties |
            Where-Object {
                $_.Name -like "$ExpectedFontFace*" -or
                $_.Name -like "$Name*Nerd*" -or
                [string] $_.Value -like "*$Name*Nerd*"
            } |
            Select-Object -First 1

        if ($matchingFont) { return $true }
    }

    $fontDirectories = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
        (Join-Path $env:WINDIR 'Fonts')
    )

    foreach ($fontDirectory in $fontDirectories) {
        if (-not (Test-Path -LiteralPath $fontDirectory)) { continue }

        $matchingFile = Get-ChildItem -LiteralPath $fontDirectory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$Name*Nerd*" -or $_.Name -like "*$Name*NFM*" } |
            Select-Object -First 1

        if ($matchingFile) { return $true }
    }

    return $false
}

Export-ModuleMember -Function Test-NerdFontInstalled
