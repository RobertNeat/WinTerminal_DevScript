# Initializes a NoteProperty on an object when it is missing or has a null value.
# [input-param] Object: object on which the property should be set
# [input-param] Name: NoteProperty name
# [input-param] DefaultValue: value set when the property does not exist or is null
# [side-effect] Modifies the passed object through Add-Member or value assignment.
function Initialize-NoteProperty {
    param(
        [Parameter(Mandatory = $true)][psobject]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$DefaultValue
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultValue -Force
    } elseif ($null -eq $Object.$Name) {
        $Object.$Name = $DefaultValue
    }
}

Export-ModuleMember -Function Initialize-NoteProperty
