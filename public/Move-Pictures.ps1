function Move-Pictures {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$false)]
        [switch]$TagDuplicates,

        [Parameter(Mandatory=$false)]
        [string[]]$Extensions = @("*.JPG"),

        [Parameter(Mandatory=$false)]
        [string]$DefaultPrefix = $null,

        [Parameter(Mandatory=$false)]
        [switch]$TimestampFirst,

        [Parameter(Mandatory=$false)]
        [switch]$RemoveEmptySourceDirectory
    )

    if ($DefaultPrefix) {
        $DefaultPrefix = $DefaultPrefix + "_"
    }

    if (-not (Test-Path -Path $Source)) {
        Write-Error "Source directory '$Source' does not exist."
        return
    }
    if (-not (Test-Path -Path $Destination)) {
        Write-Error "Destination directory '$Destination' does not exist."
        return
    }

    # Load the System.Drawing assembly to read EXIF data from JPEG files
    Add-Type -AssemblyName System.Drawing

    # Get the list of files to process to count them for a progress bar
    $totalFiles = Get-ChildItem -Path $Source -Recurse -Include $Extensions | 
        Measure-Object | 
        Select-Object -ExpandProperty Count
    $processedFiles = 0

    # Get the list of files to process and pass to the main loop
    Get-ChildItem -Path $Source -Recurse -Include $Extensions | ForEach-Object {
        $processedFiles++

        # Update the progress bar
        Write-Progress -Activity "Processing $($_.FullName)" `
            -Status "$processedFiles of $totalFiles" `
            -PercentComplete ((($processedFiles-1) / $totalFiles) * 100)
        
        $file = $_ # Alias to avoid confusion further down when using $_ in nested scopes.
        $dateTaken = $null

        # Identify the date the picture was taken. If the file is a JPEG, read the EXIF data. Otherwise, use the last
        # write time.
        $dateFromExif = $false
        if ($file.Extension -eq ".JPG") {
            $dateTaken = Get-ImageCreationDate $file
        } elseif ($file.Extension -in @(".MP4", ".MOV", ".AVI")) {
            $dateTaken = Get-VideoCreationDate $file
        } else {
            Write-Warning "Could not determine date taken for $($file.Name), using LastWriteTime."
            $dateTaken = $file.LastWriteTime
        }

        # Last resort check: if we still don't have a date, use the last write time.
        if (-not $dateTaken) {
            Write-Warning "Could not determine date taken for $($file.Name), using LastWriteTime."
            $dateTaken = $file.LastWriteTime
        }

        # This will be added as timestamp to the file name
        $formattedDate = $dateTaken.ToString("yyyyMMdd_HHmmss")
        $folderDate = $dateTaken.ToString("yyyy-MM")

        # Get-FileNameWithoutFullExtension and Get-FullExtension are defined in corresponding files in public/ in this
        # same module
        $fileNameWithoutExtension = Get-FileNameWithoutFullExtension($file.FullName)
        $fileExtension = Get-FullExtension($file.fullname)

        # We will not append the timestamp if the file name already contains a timestamp in our format. 
        $appendTimestamp = $true

        Write-Verbose "File name: $($file.Name)"
        Write-Verbose ("Formatted " + ($(if ($dateFromExif) {"EXIF"} else {"last write"})) + " date: $formattedDate")
        Write-Verbose "File name without extension: $fileNameWithoutExtension"
        Write-Verbose "File extension: $fileExtension"

        # We have to handle some special cases. The first two are for portrait photos taken with the Android camera app.
        if ($fileNameWithoutExtension -match "^(\d{5})PORTRAIT_(\d{5})_BURST(\d{14,17})$") {
            $newFileName = $DefaultPrefix + $formattedDate
        } elseif ($fileNameWithoutExtension -match "^(\d{5})(\w)PORTRAIT_(\d{5})_BURST(\d{14,17})(_COV)?(ER)?$") {
            $newFileName = $DefaultPrefix + $formattedDate + "_Portrait"
        # Burst photos taken with the Android camera app.
        } elseif ($fileNameWithoutExtension -match "^(\d{5})IMG_(\d{5})_BURST(\d{14,17})(?:_COVER)?$") {
            $newFileName = $DefaultPrefix + $formattedDate + "_BURST_" + "{0:D2}" -f [int]$matches[1]
        # Other special case rules
        } else {
            # Add an underscore to any existing timestamps.
            $fileNameWithoutExtension = $fileNameWithoutExtension -replace "(.*?)(\d{8})(\d{6})(.*)", '$1$2_$3$4'
            
            # Warn if a differently formatted date is already present in the file name. The regex checks if the existing
            # file name contains formatted dates.
            if ($fileNameWithoutExtension -match "\d{8}_\d{6}") {
                try {
                    $existingDateObj = [datetime]::ParseExact($matches[0], "yyyyMMdd_HHmmss", $null)
                    
                    if ([math]::Abs(($existingDateObj - $dateTaken).TotalDays) -gt 1) {
                        if ($dateFromExif) {
                            Write-Warning ("$($file.Name): Formatted date differing from EXIF data by more than one day " +
                                "already present in file name. A second timestamp will be added.")
                        } else {
                            # We don't trust the write time enough to challenge the file name.
                            # We replace the timestamp with the one based on the file name.
                            $formattedDate = $existingDateObj.ToString("yyyyMMdd_HHmmss")
                            $folderDate = $existingDateObj.ToString("yyyy-MM")
                            Write-Warning ("$($file.Name): Formatted date differing from LastWriteTime by more than one " +
                                "day already present in file name.")
                            $appendTimestamp = $false
                        }
                    } else {
                        Write-Verbose ("$($file.Name): Formatted date differing from metadata by less than one day " +
                            "already present in file name.")
                        $appendTimestamp = $false
                    }
                } catch {
                    Write-Warning ("$($file.Name): Could not parse existing formatted date '$($matches[0])'. Error: $_")
                }
            }
            
            if ($appendTimestamp) {
                $newFileName = $fileNameWithoutExtension + "_" + $formattedDate
            } else {
                $newFileName = $fileNameWithoutExtension
            }

            $prefixesToMove = @("MVIMG", "PANO", "Burst_Cover_Collage", "Burst_Cover_GIF_Action")
            # If the file starts with any of the prefixes in $prefixesToMove, move it to the end to ensure chronological
            # order of Android camera pictures.
            foreach ($prefix in $prefixesToMove) {
                $newFileName = $newFileName -replace "^($prefix)_(.*)", ($DefaultPrefix + '$2_$1')
            }

            # If a file name starts with digits, add the prefix $DefaultPrefix.
            if ($DefaultPrefix -and $newFileName -match "^\d") {
                $newFileName = $DefaultPrefix + $newFileName
            }
        }
       
        # The target folder is the destination directory plus the year and month the picture was taken.
        $targetFolder = Join-Path -Path $Destination -ChildPath $folderDate
        
        # Create the target folder if it does not exist
        if (-not (Test-Path -Path $targetFolder)) {
            if ($PSCmdlet.ShouldProcess($targetFolder, "Create new directory")) {
                New-Item -ItemType Directory -Path $targetFolder | Out-Null
            }
        }

        if($TimestampFirst) {
            $newFileName = $newFileName -replace "(.*)_(\d{8}_\d{6,9})(.*)", '$2_$1$3'
        }

        $newFileNameWithExtension = $newFileName + $fileExtension

        Write-Verbose "New file name: $newFileNameWithExtension"

        $targetPath = Join-Path -Path $targetFolder -ChildPath $newFileNameWithExtension
        $moveToTarget = $true
        # If the target file already exists, append _altN to the file name until a unique name is found.
        if ($TagDuplicates) {
            $counter = 1
            while (Test-Path -Path $targetPath) {
                $newFileNameWithExtension = $newFileName + "_alt$counter" + $fileExtension
                $targetPath = Join-Path -Path $targetFolder -ChildPath $newFileNameWithExtension
                $counter++
            }
        } else {
            if (Test-Path -Path $targetPath) {

                $targetFileSize = (Get-Item -Path $targetPath).Length
                if ($file.Length -gt $targetFileSize) {                 
                    $targetDuplicatesFolder = Join-Path -Path $Source -ChildPath "TargetDuplicates"
                    $targetDuplicatesYearMonthFolder = Join-Path -Path $targetDuplicatesFolder -ChildPath $folderDate

                    # Create the target duplicates folder if it does not exist
                    if (-not (Test-Path -Path $targetDuplicatesFolder)) {
                        if ($PSCmdlet.ShouldProcess($targetDuplicatesFolder, "Create new directory")) {
                            New-Item -ItemType Directory -Path $targetDuplicatesFolder | Out-Null
                        }
                    }

                    # Create the target duplicates year-month folder if it does not exist
                    if (-not (Test-Path -Path $targetDuplicatesYearMonthFolder)) {
                        if ($PSCmdlet.ShouldProcess($targetDuplicatesYearMonthFolder, "Create new directory")) {
                            New-Item -ItemType Directory -Path $targetDuplicatesYearMonthFolder | Out-Null
                        }
                    }

                    # Move the file to the target duplicates year-month folder
                    $targetDuplicatesPath = Join-Path -Path $targetDuplicatesYearMonthFolder -ChildPath $newFileNameWithExtension
                    if ($PSCmdlet.ShouldProcess($targetPath, "Move file to $targetDuplicatesPath")) {
                        Move-Item -Path $targetPath -Destination $targetDuplicatesPath
                    }
                    Write-Warning ("A smaller file with the same name already exists at the target location " +
                        "$targetPath. Moving the smaller file to $targetDuplicatesYearMonthFolder before proceeding " +
                        "to move $($file.FullName) to the target location.")
                } else {
                    $moveToTarget = $false
                    Write-Warning ("A larger or equally sized file already exists at $targetPath. The file " +
                        "$($file.FullName) will not be moved.")
                }
            }
        }

        if ($moveToTarget -and $PSCmdlet.ShouldProcess($file.FullName, "Move file to $targetPath")) {
            Move-Item -Path $file.FullName -Destination $targetPath
        }
    }
    Write-Progress -Activity "Processing Files" -Completed

    # Remove-EmpyDirectory is defined in public/Remove-EmptyDirectory.ps1 in the same module
    Remove-EmptyDirectory -Target $Source -Recurse -OnlySubDirectories:(-not $RemoveEmptySourceDirectory)
}