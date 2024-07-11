function Move-CanonMP4 {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$SourceBasePath = "C:\Users\Szymon\Documents\My_Documents\Code\PowerShell\Test",
        [Parameter(Mandatory=$false)]
        [string]$DestinationBasePath = "D:\Offline_Archive\Videos\Canon"
    )

    # Validate paths
    if (-not (Test-Path -Path $SourceBasePath)) {
        Write-Error "Source path '$SourceBasePath' does not exist. Please provide a valid source path."
        return
    }
    if (-not (Test-Path -Path $DestinationBasePath)) {
        Write-Error "Destination path '$DestinationBasePath' does not exist. Please provide a valid destination path."
        return
    }

    Write-Verbose "Checking if the destination drive is the expected Samsung portable SSD."
    # Unique identifier for the Samsung portable SSD
    $expectedDriveSerialNumber = "Z131909R0JN8U6S"
    $expectedPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    Write-Verbose "Expected drive serial number: $expectedDriveSerialNumber"
    Write-Verbose "Expected partition UUID: $expectedPartitionUUID"

    $sourceDrive = Split-Path -Path $SourceBasePath -Qualifier
    $destinationDrive = Split-Path -Path $DestinationBasePath -Qualifier

    $driveLetter = $destinationDrive[0]
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

    # Calculate total size of MP4 files
    $mp4Files = Get-ChildItem -Path $SourceBasePath -Filter *.MP4 -Recurse
    $totalSize = ($mp4Files | Measure-Object -Property Length -Sum).Sum
    if ($mp4Files.Count -eq 0) {
        Write-Warning "No MP4 files found in the specified source path. Nothing will be done."
        return
    }

    # Print the list of all mp4 files to be transferred
    Write-Verbose ("List of MP4 files to be transferred:`n" + ($mp4Files.FullName -join "`n"))

    # Execute Move-Item or Robocopy depending on whethere we are moving across drives
    if ($sourceDrive -eq $destinationDrive) {
        $progressParams = @{
            Activity = "Moving MP4 Files"
            Status   = "Initializing"
            PercentComplete = 0
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
                $progressParams.Status = "Moving $file.FullName"
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
        Write-Verbose "Finished moving all files."
    } else {
        # Calculate estimated time
        $startDate = Get-Date
        $estimatedTimeSeconds = [math]::Ceiling(($totalSize / 1MB) / 35) # Adjust the divisor based on your transfer speed
        $estimatedFinishTime = $startDate.AddSeconds($estimatedTimeSeconds).ToString('HH:mm:ss')
        Write-Verbose "Starting file move at $startDate."
        Write-Verbose "Total size: $([math]::Round($totalSize / 1MB, 2)) MB." 
        Write-Verbose "Estimated finish: $estimatedFinishTime"

        if ($PSCmdlet.ShouldProcess($SourceBasePath, "Move all MP4 files to $DestinationBasePath")) {
            robocopy "$SourceBasePath" "$DestinationBasePath" *.mp4 /mov /s /mt:8 /r:2 /w:1
        }

        $endDate = Get-Date
        $elapsedTime = $endDate - $startDate
        $writeSpeed = [math]::Round(($totalSize / 1MB) / $elapsedTime.TotalSeconds, 2)
        Write-Verbose "Finished moving all files at $endDate."
        Write-Verbose "Elapsed time: $($elapsedTime.ToString('hh\:mm\:ss\.ff'))"
        Write-Verbose "Average write speed: $writeSpeed MB/s"
    }

    # Check for and remove empty directories
    $directories = Get-ChildItem -Path $SourceBasePath -Directory -Recurse
    foreach ($dir in $directories) {
        $items = Get-ChildItem -Path $dir.FullName
        if ($items.Count -eq 0) {
            Remove-Item -Path $dir.FullName -Force
            Write-Host "Removed empty directory: $($dir.FullName)"
        }
    }
}