# Resolves the GitHub API URI for Oh My Posh release metadata.
# [input-param] Tag: release tag to resolve, or latest for the newest release
# [output-param] String: GitHub API URI for the requested Oh My Posh release metadata
# [side-effect] None.
function Get-OhMyPoshReleaseMetadataUri {
    param(
        [string] $Tag = 'latest'
    )

    if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag -eq 'latest') {
        return 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest'
    }

    return "https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/tags/$Tag"
}

Export-ModuleMember -Function Get-OhMyPoshReleaseMetadataUri
