function Get-ImageCreationDate {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "File $FilePath does not exist."
        return
    }

    try {
        $img = [System.Drawing.Image]::FromFile($FilePath)
        # 36867 is the EXIF tag for DateTimeOriginal
        $fileDateStr = [System.Text.Encoding]::ASCII.GetString($img.GetPropertyItem(36867).Value).Trim([char]0)
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyy:MM:dd HH:mm:ss", $null)
        $img.Dispose()
    } catch {
        # Dispose again, in case the error happened before the object was disposed.
        try { $img.Dispose() } catch { Write-Warning "$FilePath`: could not dispose of image object." }
        Write-Warning "Could not read EXIF data for $FilePath, using LastWriteTime instead."
        $fileDate = (Get-Item $FilePath).LastWriteTime
    }

    # Sanity check
    if (-not $fileDate) {
        Write-Warning "Could not read EXIF data for $FilePath, using LastWriteTime instead."
        $fileDate = (Get-Item $FilePath).LastWriteTime
    } 

    return $fileDate
}