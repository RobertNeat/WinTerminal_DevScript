# Creates one selectable setup menu option.
# [input-param] Key: stable option identifier returned to the caller when selected
# [input-param] Label: text displayed in the terminal menu
# [input-param] Group: option group name; supported values are Profile and Step
# [input-param] Selected: initial checked state for the option
# [output-param] PSCustomObject: menu option with Key, Label, Group, and Selected fields
# [side-effect] None.
function New-TerminalSetupOption {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Key,

        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Profile', 'Step')]
        [string] $Group,

        [bool] $Selected = $true
    )

    [PSCustomObject]@{
        Key      = $Key
        Label    = $Label
        Group    = $Group
        Selected = $Selected
    }
}

Export-ModuleMember -Function New-TerminalSetupOption
