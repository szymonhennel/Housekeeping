function Move-CanonMP4 {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Source = "C:\Users\Szymon\Documents\My_Documents\Code\PowerShell\Test",
        [Parameter(Mandatory=$false)]
        [string]$Destination = "Offline_Archive\Videos\Canon",
        [Parameter(Mandatory=$false)]
        [string]$DestinationDriveSerialNumber = "Z131909R0JN8U6S",
        [Parameter(Mandatory=$false)]
        [string]$DestinationPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    )

    # Check if the destination base path is missing a drive letter
    $Destination = Get-DrivePath -Path $Destination -DiskSerialNumber $DestinationDriveSerialNumber -PartitionUUID $DestinationPartitionUUID

    # Validate paths
    if (-not (Test-Path -Path $Source)) {
        Write-Error "Source path '$Source' does not exist. Please provide a valid source path."
        return
    }
    if (-not (Test-Path -Path $Destination)) {
        Write-Error "Destination path '$Destination' does not exist. Please provide a valid destination path."
        return
    }

    # Calculate total size of MP4 files
    $mp4Files = Get-ChildItem -Path $Source -Filter *.MP4 -Recurse
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
            $relativePath = $file.FullName.Substring($Source.Length).TrimStart('\')
            $destinationPath = Join-Path -Path $Destination -ChildPath $relativePath
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

        if ($PSCmdlet.ShouldProcess($Source, "Move all MP4 files to $Destination")) {
            robocopy "$Source" "$Destination" *.mp4 /mov /s /mt:8 /r:2 /w:1
        }

        $endDate = Get-Date
        $elapsedTime = $endDate - $startDate
        $writeSpeed = [math]::Round(($totalSize / 1MB) / $elapsedTime.TotalSeconds, 2)
        Write-Verbose "Finished moving all files at $endDate."
        Write-Verbose "Elapsed time: $($elapsedTime.ToString('hh\:mm\:ss\.ff'))"
        Write-Verbose "Average write speed: $writeSpeed MB/s"
    }

    # Check for and remove empty directories
    $directories = Get-ChildItem -Path $Source -Directory -Recurse
    foreach ($dir in $directories) {
        $items = Get-ChildItem -Path $dir.FullName
        if ($items.Count -eq 0) {
            Remove-Item -Path $dir.FullName -Force
            Write-Host "Removed empty directory: $($dir.FullName)"
        }
    }
}