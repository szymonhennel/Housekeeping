function Move-CanonMP4 {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$SourceBasePath = "C:\Users\Szymon\Documents\My_Documents\Code\PowerShell\Test",

        [Parameter(Mandatory=$false)]
        [string]$DestinationBasePath = "D:\Offline_Archive\Videos\Canon"
    )

    # Validate SourceBasePath
    if (-not (Test-Path -Path $SourceBasePath)) {
        Write-Error "Source path '$SourceBasePath' does not exist. Please provide a valid source path."
        return
    }

    # Validate DestinationBasePath
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

    # Group MP4 files by their parent directory
    $groupedFiles = $mp4Files | Group-Object { $_.DirectoryName }

    if ($mp4Files.Count -eq 0) {
        if ($PSCmdlet.ShouldProcess($SourceBasePath, "No MP4 files found")) {
            Write-Warning "No MP4 files found in the specified source path. Nothing will be done."
        }
    }

    $startDate = Get-Date

    foreach ($group in $groupedFiles) {
        $sourceDir = $group.Name
        $relativePath = $sourceDir.Substring($SourceBasePath.Length)
        $destinationDir = Join-Path -Path $DestinationBasePath -ChildPath $relativePath
    
        # Ensure the destination directory exists
        if ($PSCmdlet.ShouldProcess($destinationDir, "Create destination directory")) {
            if (-not (Test-Path -Path $destinationDir)) {
                New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            }
        }
    
        # Calculate the total size of files in the current group
        $groupSize = ($group.Group | Measure-Object -Property Length -Sum).Sum
        $fileNames = $group.Group | Select-Object -ExpandProperty Name

        $currentDate = Get-Date
        $statusMessage = "Moving files from $sourceDir (Batch size $([math]::Round($groupSize / 1MB, 2)) MB) started $($currentDate.ToString('HH:mm:ss'))"
        $estimatedTimeSeconds = [math]::Ceiling(($groupSize / 1MB) / 35)
        $estimatedFinishTime = $currentDate.AddSeconds($estimatedTimeSeconds).ToString('HH:mm:ss')
        $statusMessage += " - estimated Finish: $estimatedFinishTime"
        Write-Host $statusMessage

        # Execute Robocopy
        if ($PSCmdlet.ShouldProcess("$sourceDir", "Move " + ($fileNames -join ", ") + " to $destinationDir")) {
            try {
                robocopy "$sourceDir" "$destinationDir" *.mp4 /mov
            } catch {
                Write-Error "An error occurred while moving files from $sourceDir to $destinationDir`: $_"
            }
        }

        # Update moved size and progress
        $movedSize += $groupSize
        if ($totalSize -gt 0) {
            $percentComplete = [math]::Round(($movedSize / $totalSize) * 100)
        } else {
            $percentComplete = 100
        }
        Write-Host "Overall progress: $percentComplete% completed."

        # Optionally, remove the source directory if empty
        $remainingItems = Get-ChildItem -Path $sourceDir
        if ($remainingItems.Count -eq 0) {
            if ($PSCmdlet.ShouldProcess("$sourceDir", "Remove empty directory")) {
                Remove-Item -Path $sourceDir -Force
            }
        }
    }

    $endDate = Get-Date
    $elapsedTime = $endDate - $startDate
    $writeSpeed = [math]::Round(($totalSize / 1MB) / $elapsedTime.TotalSeconds, 2)
    Write-Verbose "Total size moved: $([math]::Round($totalSize / 1MB, 2)) MB"
    Write-Verbose "Elapsed time: $($elapsedTime.ToString('hh\:mm\:ss\.ff'))"
    Write-Verbose "Average write speed: $writeSpeed MB/s"
}