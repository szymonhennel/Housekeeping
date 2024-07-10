function Move-CanonMP4 {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$SourceBasePath = "C:\Users\Szymon\Documents\My_Documents\Code\PowerShell\Test",

        [Parameter(Mandatory=$false)]
        [string]$DestinationBasePath = "D:\Offline_Archive\Videos\Canon"
    )

    Write-Verbose "Checking if the destination drive is the expected Samsung portable SSD."
    # Unique identifier for the Samsung portable SSD
    $expectedDriveSerialNumber = "Z131909R0JN8U6S"
    $expectedPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    Write-Verbose "Expected drive serial number: $expectedDriveSerialNumber"
    Write-Verbose "Expected partition UUID: $expectedPartitionUUID"
    
    $driveLetter = $DestinationBasePath[0]
    $diskNumber = (Get-Partition | Where-Object { $_.DriveLetter -eq $driveLetter }).DiskNumber
    $driveSerialNumber = (Get-Disk | Where-Object { $_.Number -eq $diskNumber }).SerialNumber
    $partitionUUID = (Get-Partition | Where-Object { $_.DriveLetter -eq $driveLetter }).UniqueID
    
    Write-Verbose "Destination drive serial number: $($driveSerialNumber)"
    Write-Verbose "Destination partition UUID: $($partitionUUID)"
    
    # Check if the drive's serial number and partition UUID match the expected values
    if ($driveSerialNumber -ne $expectedDriveSerialNumber -or $partitionUUID -ne $expectedPartitionUUID) {
        Write-Error "The destination drive is not the expected Samsung portable SSD. Aborting operation."
        return
    }

    $mp4Files = Get-ChildItem -Path $SourceBasePath -Filter *.MP4 -Recurse
    $totalSize = ($mp4Files | Measure-Object -Property Length -Sum).Sum
    $movedSize = 0

    $progressParams = @{
        Activity = "Moving MP4 Files"
        Status   = "Progress:"
        PercentComplete = 0
    }

    if ($mp4Files.Count -eq 0) {
        if ($PSCmdlet.ShouldProcess($SourceBasePath, "No MP4 files found")) {
            Write-Warning "No MP4 files found in the specified source path. Nothing will be done."
        }
    }

    Write-Progress @progressParams

    foreach ($file in $mp4Files) {
        $relativePath = $file.FullName.Substring($SourceBasePath.Length).TrimStart('\')
        $destinationPath = Join-Path -Path $DestinationBasePath -ChildPath $relativePath
        $destinationDir = Split-Path -Path $destinationPath

        if (-not (Test-Path -Path $destinationDir)) {
            if ($PSCmdlet.ShouldProcess($destinationDir, "Create directory")) {
                New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            }
        }

        if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destinationPath")) {
            Write-Verbose "Moving $file.FullName to $destinationPath"
            Move-Item -Path $file.FullName -Destination $destinationPath -ErrorAction Stop
            $movedSize += $file.Length

            if ($totalSize -gt 0) {
                $progressParams.PercentComplete = [math]::Round(($movedSize / $totalSize) * 100)
            } else {
                $progressParams.PercentComplete = 100
            }

            Write-Progress @progressParams
        }

        $sourceDir = Split-Path -Path $file.FullName
        $childItems = Get-ChildItem -Path $sourceDir
        if ($childItems.Count -eq 0) {
            if ($PSCmdlet.ShouldProcess($sourceDir, "Remove empty directory")) {
                Remove-Item -Path $sourceDir -Force
            }
        }
    }
    Write-Progress @progressParams -Completed
}