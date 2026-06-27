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