function Move-Pictures {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory=$true)]
        [string]$DestinationDirectory,

        [Parameter(Mandatory=$false)]
        [string[]]$Extensions = @("*.JPG"),

        [Parameter(Mandatory=$false)]
        [string]$DefaultPrefix = "IMG"
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

    # Get the list of files to process to count them for a progress bar
    $totalFiles = Get-ChildItem -Path $SourceDirectory -Recurse -Include $Extensions | 
        Measure-Object | 
        Select-Object -ExpandProperty Count
    $processedFiles = 0

    # Get the list of files to process and pass to the main loop
    Get-ChildItem -Path $SourceDirectory -Recurse -Include $Extensions | ForEach-Object {
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
            try {
                $img = [System.Drawing.Image]::FromFile($file.FullName)
                # 36867 is the EXIF tag for DateTimeOriginal
                $dateTakenStr = [System.Text.Encoding]::ASCII.GetString($img.GetPropertyItem(36867).Value).Trim([char]0)
                $dateTaken = [datetime]::ParseExact($dateTakenStr, "yyyy:MM:dd HH:mm:ss", $null)
                $img.Dispose()
                $dateFromExif = $true
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

        # This will be added as timestamp to the file name
        $formattedDate = $dateTaken.ToString("yyyyMMdd_HHmmss")

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
        if ($fileNameWithoutExtension -match "^(\d{5})PORTRAIT_(\d{5})_BURST(\d{17})$") {
            $newFileName = $DefaultPrefix + "_" + $formattedDate
        } elseif ($fileNameWithoutExtension -match "^(\d{5})dPORTRAIT_(\d{5})_BURST(\d{17})_COVER$") {
            $newFileName = $DefaultPrefix + "_" + $formattedDate + "_Portrait"
        # Burst photos taken with the Android camera app.
        } elseif ($fileNameWithoutExtension -match "^(\d{5})IMG_(\d{5})_BURST(\d{14})(?:_COVER)?$") {
            $newFileName = $DefaultPrefix + "_" + $formattedDate + "_BURST_" + "{0:D2}" -f [int]$matches[1]
        # Other special case rules
        } else {
            # Add an underscore to any existing timestamps.
            $fileNameWithoutExtension = $fileNameWithoutExtension -replace "(.*)(\d{8})(\d{6})(.*)", '$1$2_$3$4'
            
            # Warn if a differently formatted date is already present in the file name. The regex checks if the existing
            # file name contains formatted dates.
            if ($fileNameWithoutExtension -match "\d{8}_\d{6}") {
                $existingDateObj = [datetime]::ParseExact($matches[0], "yyyyMMdd_HHmmss", $null)
                
                if ([math]::Abs(($existingDateObj - $dateTaken).TotalDays) -gt 1) {
                    if ($dateFromExif) {
                        Write-Warning @"
Formatted date differing from EXIF data by more than one day already present in file name. A second timestamp will be 
added.
"@
                    } else {
                        # We don't trust the write time enough to challenge the file name.
                        Write-Warning @"
Formatted date differing from LastWriteTime by more than one day already present in file name.
"@
                        $appendTimestamp = $false
                    }
                } else {
                    Write-Warning "Formatted date differing from metadata by less than one day already present in file name."
                    $appendTimestamp = $false
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
                $newFileName = $newFileName -replace "^($prefix)_(.*)", ($DefaultPrefix + '_$2_$1')
            }

            # If a file name starts with digits, add the prefix $DefaultPrefix.
            if ($newFileName -match "^\d") {
                $newFileName = $DefaultPrefix + "_" + $newFileName
            }
        }
       
        # The target folder is the destination directory plus the year and month the picture was taken.
        $targetFolder = Join-Path -Path $DestinationDirectory -ChildPath ($dateTaken.ToString("yyyy-MM"))
        
        # Create the target folder if it does not exist
        if (-not (Test-Path -Path $targetFolder)) {
            if ($PSCmdlet.ShouldProcess($targetFolder, "Create new directory")) {
                New-Item -ItemType Directory -Path $targetFolder | Out-Null
            }
        }

        $newFileNameWithExtension = $newFileName + $fileExtension

        $targetPath = Join-Path -Path $targetFolder -ChildPath $newFileNameWithExtension

        # If the target file already exists, append _altN to the file name until a unique name is found.
        $counter = 1
        while (Test-Path -Path $targetPath) {
            $newFileNameWithExtension = $newFileName + "_alt$counter" + $fileExtension
            $targetPath = Join-Path -Path $targetFolder -ChildPath $newFileNameWithExtension
            $counter++
        }

        Write-Verbose "New file name: $newFileNameWithExtension"

        if ($PSCmdlet.ShouldProcess($file.FullName, "Move file to $targetPath")) {
            Move-Item -Path $file.FullName -Destination $targetPath
        }
    }
    Write-Progress -Activity "Processing Files" -Completed

    # Remove-EmpyDirectory is defined in public/Remove-EmptyDirectory.ps1 in the same module
    Remove-EmptyDirectory -Target $SourceDirectory -Recurse -OnlySubDirectories
}