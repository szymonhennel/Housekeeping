function Get-VideoCreationDate {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "File $FilePath does not exist."
        return
    }

    # Run ffprobe to get the creation date
    try {
        $ffprobeOutput = & ffprobe -v quiet -select_streams v:0 -show_entries stream_tags=creation_time -of default=noprint_wrappers=1:nokey=1 -i $FilePath
        $fileDate = [datetime]::Parse($ffprobeOutput.Trim())
    } catch {
        Write-Warning "Could not extract creation date with ffprobe for $FilePath. Using LastWriteTime instead."
        $fileDate = (Get-Item $FilePath).LastWriteTime
    }

    # Sanity check
    if (-not $fileDate) {
        Write-Warning "Could not extract creation date with ffprobe for $FilePath. Using LastWriteTime instead."
        $fileDate = (Get-Item $FilePath).LastWriteTime
    } 
    return $fileDate
}