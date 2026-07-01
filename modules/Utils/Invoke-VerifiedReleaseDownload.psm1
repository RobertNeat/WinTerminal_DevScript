# Downloads a release artifact and verifies its SHA-256 before exposing it at the destination path.
# [input-param] Uri: artifact URL
# [input-param] OutFile: final output path
# [input-param] ExpectedSha256: pinned SHA-256 for the artifact
# [input-param] ChecksumUri: URL to a release checksum file
# [input-param] ChecksumFileName: artifact file name as listed in the checksum file
# [output-param] PSCustomObject: downloaded path, source URI, and verified SHA-256
# [side-effect] Downloads files to a temporary directory and moves the verified artifact to OutFile.
function Invoke-VerifiedReleaseDownload {
    param(
        [Parameter(Mandatory)]
        [string] $Uri,

        [Parameter(Mandatory)]
        [string] $OutFile,

        [string] $ExpectedSha256,

        [string] $ChecksumUri,

        [string] $ChecksumFileName
    )

    function Get-Sha256FromChecksumText {
        param(
            [string[]] $Lines,
            [string] $FileName
        )

        foreach ($line in $Lines) {
            $match = [regex]::Match($line, '(?i)\b[a-f0-9]{64}\b')
            if (-not $match.Success) { continue }

            $listedFileName = ($line.Substring($match.Index + $match.Length).Trim() -replace '^\*', '')
            $listedFileName = [System.IO.Path]::GetFileName($listedFileName)
            if ($listedFileName -eq $FileName) {
                return $match.Value.ToUpperInvariant()
            }
        }

        throw "Checksum for '$FileName' was not found in $ChecksumUri."
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedSha256) -and [string]::IsNullOrWhiteSpace($ChecksumUri)) {
        throw 'ExpectedSha256 or ChecksumUri is required for verified download.'
    }

    $destinationDirectory = Split-Path -Path $OutFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Setup-Terminal-Download-' + [guid]::NewGuid().ToString('N'))
    $artifactPath = Join-Path $tempRoot ([System.IO.Path]::GetFileName($OutFile))
    $checksumPath = Join-Path $tempRoot 'checksums.txt'

    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        $expectedHash = $ExpectedSha256
        if ([string]::IsNullOrWhiteSpace($expectedHash)) {
            if ([string]::IsNullOrWhiteSpace($ChecksumFileName)) {
                $ChecksumFileName = [System.IO.Path]::GetFileName($OutFile)
            }

            Invoke-WebRequest -Uri $ChecksumUri -OutFile $checksumPath -UseBasicParsing -ErrorAction Stop
            $expectedHash = Get-Sha256FromChecksumText -Lines (Get-Content -LiteralPath $checksumPath) -FileName $ChecksumFileName
        }

        $expectedHash = $expectedHash.ToUpperInvariant()
        Invoke-WebRequest -Uri $Uri -OutFile $artifactPath -UseBasicParsing -ErrorAction Stop

        $actualHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "SHA-256 verification failed for $Uri. Expected $expectedHash, got $actualHash."
        }

        Move-Item -LiteralPath $artifactPath -Destination $OutFile -Force

        [PSCustomObject]@{
            Path   = (Resolve-Path -LiteralPath $OutFile).Path
            Uri    = $Uri
            SHA256 = $actualHash
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Invoke-VerifiedReleaseDownload
