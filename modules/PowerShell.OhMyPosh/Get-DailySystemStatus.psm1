Import-Module "$PSScriptRoot\Write-StatusLines.psm1" -ErrorAction Stop

# Gets and prints a cached daily system status summary.
# [input-param] CacheTtlSeconds: number of seconds before cached status output is refreshed
# [output-param] None.
# [side-effect] Writes status output and updates a cache file under the current user's local app data directory.
function Get-DailySystemStatus {
    param(
        [int] $CacheTtlSeconds = 60
    )

    function Get-UsageBar {
        param(
            [double] $Percent,
            [int] $Width = 20
        )

        if ($Percent -lt 0) { $Percent = 0 }
        if ($Percent -gt 100) { $Percent = 100 }

        $filled = [math]::Round(($Percent / 100) * $Width)
        $empty = $Width - $filled

        return "[" + ("#" * $filled) + ("-" * $empty) + "]"
    }

    function Get-ProcessorLoadPercentage {
        $processor = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue

        if ($processor -and $null -ne $processor.PercentProcessorTime) {
            return [double] $processor.PercentProcessorTime
        }

        return 0
    }

    $cacheDirectory = Join-Path $env:LOCALAPPDATA 'Setup-Terminal'
    $cachePath = Join-Path $cacheDirectory 'DailySystemStatus.txt'

    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
        $cacheItem = Get-Item -LiteralPath $cachePath -ErrorAction SilentlyContinue
        if ($cacheItem -and ((Get-Date) - $cacheItem.LastWriteTime).TotalSeconds -lt $CacheTtlSeconds) {
            $cachedLines = Get-Content -LiteralPath $cachePath -ErrorAction SilentlyContinue
            if ($cachedLines -and $cachedLines.Count -ge 3) {
                Write-StatusLines -Lines $cachedLines
                return
            }
        }
    }

    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

    $computerInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
    $cpuPct = [math]::Round((Get-ProcessorLoadPercentage), 1)

    $totalRam = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 1)
    $freeRam = [math]::Round($computerInfo.AvailablePhysicalMemory / 1GB, 1)
    $usedRam = [math]::Round($totalRam - $freeRam, 1)
    $ramPct = [math]::Round(($usedRam / $totalRam) * 100, 1)

    $disks = [System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed -and $_.IsReady }

    $diskText = $disks |
        ForEach-Object {
            $usedPct = [math]::Round((($_.TotalSize - $_.AvailableFreeSpace) / $_.TotalSize) * 100, 1)
            "$($_.Name.TrimEnd('\')) $usedPct% used"
        }

    $avgDiskPct = ($disks |
        ForEach-Object {
            (($_.TotalSize - $_.AvailableFreeSpace) / $_.TotalSize) * 100
        } |
        Measure-Object -Average).Average

    $avgDiskPct = [math]::Round($avgDiskPct, 1)

    $statusLines = @(
        ("{0} CPU:  {1}% load" -f (Get-UsageBar $cpuPct), $cpuPct),
        ("{0} RAM:  {1} GB / {2} GB used ({3}%)" -f (Get-UsageBar $ramPct), $usedRam, $totalRam, $ramPct),
        ("{0} Disk: {1}" -f (Get-UsageBar $avgDiskPct), ($diskText -join " | "))
    )

    if (-not (Test-Path -LiteralPath $cacheDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
    }

    Set-Content -LiteralPath $cachePath -Value $statusLines -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-StatusLines -Lines $statusLines
}

Export-ModuleMember -Function Get-DailySystemStatus
