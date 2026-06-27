# Returns built-in color schemes for Windows Terminal profiles.
# [output-param] PSCustomObject[]: list of color schemes with names and terminal color values
function Get-TerminalColorSchemes {
    [CmdletBinding()]
    param()

    $schemes = @()

    # PowerShell
    $schemes += [pscustomobject]@{
        name = 'PowerShell Fluent'
        background = '#0B1220'
        foreground = '#DCE6F2'

        black = '#0A0F18'
        red = '#D16969'
        green = '#6CBF84'
        yellow = '#D7BA7D'
        blue = '#569CD6'
        purple = '#C586C0'
        cyan = '#4EC9B0'
        white = '#D4D4D4'

        brightBlack = '#5C6370'
        brightRed = '#F48771'
        brightGreen = '#8FDCA1'
        brightYellow = '#F5D38A'
        brightBlue = '#7DCFFF'
        brightPurple = '#DDB6F2'
        brightCyan = '#7FE4D2'
        brightWhite = '#FFFFFF'
    }

    # CMD
    $schemes += [pscustomobject]@{
        name = 'CMD Classic Modern'
        background = '#0C0C0C'
        foreground = '#F2F2F2'

        black = '#0C0C0C'
        red = '#C50F1F'
        green = '#13A10E'
        yellow = '#C19C00'
        blue = '#0037DA'
        purple = '#881798'
        cyan = '#3A96DD'
        white = '#CCCCCC'

        brightBlack = '#767676'
        brightRed = '#E74856'
        brightGreen = '#16C60C'
        brightYellow = '#F9F1A5'
        brightBlue = '#3B78FF'
        brightPurple = '#B4009E'
        brightCyan = '#61D6D6'
        brightWhite = '#F2F2F2'
    }

    # Git Bash
    $schemes += [pscustomobject]@{
        name = 'Git Bash Dark'
        background = '#0D1117'
        foreground = '#C9D1D9'

        black = '#010409'
        red = '#FF7B72'
        green = '#3FB950'
        yellow = '#D29922'
        blue = '#58A6FF'
        purple = '#BC8CFF'
        cyan = '#39C5CF'
        white = '#B1BAC4'

        brightBlack = '#6E7681'
        brightRed = '#FFA198'
        brightGreen = '#56D364'
        brightYellow = '#E3B341'
        brightBlue = '#79C0FF'
        brightPurple = '#D2A8FF'
        brightCyan = '#56D4DD'
        brightWhite = '#F0F6FC'
    }

    # Node.js
    $schemes += [pscustomobject]@{
        name = 'Node Evergreen'
        background = '#0B130F'
        foreground = '#DFF5E3'

        black = '#070A08'
        red = '#D16969'
        green = '#68CC7A'
        yellow = '#D7BA7D'
        blue = '#4FA3D1'
        purple = '#B392F0'
        cyan = '#4FD1C5'
        white = '#CFE3D5'

        brightBlack = '#5B6B61'
        brightRed = '#F28B82'
        brightGreen = '#8FE388'
        brightYellow = '#F2D28B'
        brightBlue = '#7DCFFF'
        brightPurple = '#D2B7FF'
        brightCyan = '#7BE7DC'
        brightWhite = '#F5FFF7'
    }

    # Python
    $schemes += [pscustomobject]@{
        name = 'Python Midnight'
        background = '#101827'
        foreground = '#EAF2FF'

        black = '#0B1120'
        red = '#E06C75'
        green = '#98C379'
        yellow = '#E5C07B'
        blue = '#61AFEF'
        purple = '#C678DD'
        cyan = '#56B6C2'
        white = '#D7E3F4'

        brightBlack = '#5C6370'
        brightRed = '#FF8B94'
        brightGreen = '#B5E48C'
        brightYellow = '#FFD97D'
        brightBlue = '#8EC7FF'
        brightPurple = '#E2B6FF'
        brightCyan = '#8BE9FD'
        brightWhite = '#FFFFFF'
    }

    return $schemes
}

Export-ModuleMember -Function Get-TerminalColorSchemes
