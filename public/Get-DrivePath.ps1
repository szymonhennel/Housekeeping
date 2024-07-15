function Get-DrivePath {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$DiskSerialNumber,
        [string]$PartitionUUID
    )

    # Check if the path already has a drive letter
    if ($Path -match "^[A-Z]:\\") {
        return $Path
    } else {
        # Get the drive letter based on DiskSerialNumber and PartitionUUID
        # Get-DriveLetter is defined in Get-DriveLetter.ps1 in this module.
        $driveLetter = Get-DriveLetter -SerialNumber $DiskSerialNumber -PartitionUUID $PartitionUUID

        if (-not $driveLetter) {
            Write-Error "Drive letter could not be resolved."
            return $null
        }

        # Construct the full path with the drive letter
        $resolvedPath = Join-Path -Path "$driveLetter`:" -ChildPath $Path
        Write-Verbose "Drive letter identified as $driveLetter. Completed path: $resolvedPath"
        return $resolvedPath
    }
}