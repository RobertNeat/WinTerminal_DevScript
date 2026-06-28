# Copies terminal profile icon resources next to Windows Terminal settings.json.
# [input-param] SettingsPath: resolved path to Windows Terminal settings.json
# [input-param] ResourcesPath: optional path to the directory containing icon resources
# [output-param] hashtable: icon paths keyed by supported profile type: git, node, and python
# [side-effect] Creates the icons directory next to settings.json and copies matching icon files when they are missing.
function Copy-TerminalProfileIcons {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SettingsPath,

        [Parameter(Mandatory = $false)]
        [string] $ResourcesPath
    )

    if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        return @{}
    }

    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        return @{}
    }

    if ([string]::IsNullOrWhiteSpace($ResourcesPath)) {
        $ResourcesPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Resources'
    }

    if (-not (Test-Path -LiteralPath $ResourcesPath -PathType Container)) {
        return @{}
    }

    $settingsDirectory = Split-Path -Path $SettingsPath -Parent
    if ([string]::IsNullOrWhiteSpace($settingsDirectory)) {
        return @{}
    }

    $iconsDirectory = Join-Path -Path $settingsDirectory -ChildPath 'icons'
    if (-not (Test-Path -LiteralPath $iconsDirectory -PathType Container)) {
        [void](New-Item -Path $iconsDirectory -ItemType Directory -Force)
    }

    $iconsMap = @{}
    $resources = Get-ChildItem -Path $ResourcesPath -File | Where-Object { $_.Name -match '(?i)(git|node|python)' } | Sort-Object -Property Name

    foreach ($resource in $resources) {
        $profileType = $null
        if ($resource.Name -match '(?i)git') { $profileType = 'git' }
        elseif ($resource.Name -match '(?i)node') { $profileType = 'node' }
        elseif ($resource.Name -match '(?i)python') { $profileType = 'python' }

        if (-not $profileType) {
            continue
        }

        $destinationPath = Join-Path -Path $iconsDirectory -ChildPath $resource.Name
        if (-not (Test-Path -LiteralPath $destinationPath)) {
            Copy-Item -LiteralPath $resource.FullName -Destination $destinationPath
        }

        if (-not $iconsMap.ContainsKey($profileType)) {
            $iconsMap[$profileType] = $destinationPath
        }
    }

    return $iconsMap
}

Export-ModuleMember -Function Copy-TerminalProfileIcons
