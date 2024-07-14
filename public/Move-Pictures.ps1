function Move-Pictures {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourceDirectory,
        [Parameter(Mandatory=$true)]
        [string]$DestinationDirectory
    )

    if (-not (Test-Path -Path $SourceDirectory)) {
        Write-Error "Source directory '$SourceDirectory' does not exist."
        return
    }
    if (-not (Test-Path -Path $DestinationDirectory)) {
        Write-Error "Destination directory '$DestinationDirectory' does not exist."
        return
    }

    # Load the System.Drawing assembly to read EXIF data from JPEG files
    Add-Type -AssemblyName System.Drawing

    $totalFiles = Get-ChildItem -Path $SourceDirectory -Recurse -Include @("*.JPG", "*.AVI") | Measure-Object | Select-Object -ExpandProperty Count
    $processedFiles = 0

    Get-ChildItem -Path $SourceDirectory -Recurse -Include @("*.JPG", "*.AVI") | ForEach-Object {
        $processedFiles++
        Write-Progress -Activity "Processing $($_.FullName)" -Status "$processedFiles of $totalFiles" -PercentComplete ((($processedFiles-1) / $totalFiles) * 100)

        $file = $_
        $dateTaken = $null

        if ($file.Extension -eq ".JPG") {
            try {
                $img = [System.Drawing.Image]::FromFile($file.FullName)
                # 36867 is the EXIF tag for DateTimeOriginal
                $dateTakenStr = [System.Text.Encoding]::ASCII.GetString($img.GetPropertyItem(36867).Value).Trim([char]0)
                $dateTaken = [datetime]::ParseExact($dateTakenStr, "yyyy:MM:dd HH:mm:ss", $null)
                $img.Dispose()
            } catch {
                Write-Warning "Could not read EXIF data for $($file.Name), using LastWriteTime. Error: $_"
                $dateTaken = $file.LastWriteTime
            }
            if (-not $dateTaken) {
                Write-Warning "Could not determine date taken for $($file.Name), using LastWriteTime."
                $dateTaken = $file.LastWriteTime
            }
        } else {
            $dateTaken = $file.LastWriteTime
        }

        $formattedDate = $dateTaken.ToString("yyyyMMdd_HHmmss")
        $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.fullname)
        $fileExtension = [System.IO.Path]::GetExtension($file.fullname)

        $newFileName = $fileNameWithoutExtension + "_" + $formattedDate + $fileExtension
        $targetFolder = Join-Path -Path $DestinationDirectory -ChildPath ($dateTaken.ToString("yyyy-MM"))
        
        if (-not (Test-Path -Path $targetFolder)) {
            if ($PSCmdlet.ShouldProcess($targetFolder, "Create new directory")) {
                New-Item -ItemType Directory -Path $targetFolder | Out-Null
            }
        }

        $targetPath = Join-Path -Path $targetFolder -ChildPath $newFileName
        if ($PSCmdlet.ShouldProcess($file.FullName, "Move file to $targetPath")) {
            Move-Item -Path $file.FullName -Destination $targetPath
        }
    }
    Write-Progress -Activity "Processing Files" -Completed

    # Remove any empty subdirectories recursively (directories containing only empty directories will also be removed)
    $simulatedDeletions = @() # For WhatIf mode
    do {
        $emptyDirectories = Get-ChildItem -Path $SourceDirectory -Recurse -Directory | 
            Where-Object { -not ($_.GetFileSystemInfos() | Where-Object { $simulatedDeletions -notcontains $_.FullName }) -and $_.FullName -ne $SourceDirectory } | 
            Where-Object { $simulatedDeletions -notcontains $_.FullName } | 
            Select-Object -ExpandProperty FullName

        foreach ($dir in $emptyDirectories) {
            if ($PSCmdlet.ShouldProcess($dir, "Remove empty directory")) {
                Remove-Item -Path $dir
                Write-Host "Removed empty directory: $dir"
            } else {
                # Simulate deletion by adding to the list, or actually delete if not in WhatIf mode
                $simulatedDeletions += $dir
            }
        }
        # Condition to exit the loop: No more empty directories or all would-be-deleted directories are simulated
    } while ($emptyDirectories.Count -gt 0)
}