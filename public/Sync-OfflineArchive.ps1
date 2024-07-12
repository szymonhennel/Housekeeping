function Sync-OfflineArchive {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$SourceDriveSerialNumber = "Z131909R0JN8U6S",
        [Parameter(Mandatory=$false)]
        [string]$DestinationDriveSerialNumber = "957EE7654321",
        [Parameter(Mandatory=$false)]
        [string]$SourcePartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001",
        [Parameter(Mandatory=$false)]
        [string]$DestinationPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    )


    # Retrieve the disk number for the given serial numbers using updated variable names
    $sourceDiskNumber = (Get-Disk | Where-Object SerialNumber -eq "Z131909R0JN8U6S").Number
    $destinationDiskNumber = (Get-Disk | Where-Object SerialNumber -eq "957EE7654321").Number

    # Retrieve the drive letter for the partitions with the specified unique IDs using updated variable names
    $sourceDriveLetter = (Get-Partition | Where-Object { $_.DiskNumber -eq $sourceDiskNumber -and $_.UniqueId -eq $SourcePartitionUUID }).DriveLetter
    $destinationDriveLetter = (Get-Partition | Where-Object { $_.DiskNumber -eq $destinationDiskNumber -and $_.UniqueId -eq $DestinationPartitionUUID }).DriveLetter

    # Construct the source and destination paths using updated variable names
    $sourcePath = "${sourceDriveLetter}:\Offline_Archive"
    $destinationPath = "${destinationDriveLetter}:\Szymon_Offline_Archive_Mirror"

    # Check if the source and destination paths exist
    if (-not (Test-Path -Path $sourcePath)) {
        Write-Error "Source path '$sourcePath' does not exist. Please provide a valid source path."
        return
    }
    if (-not (Test-Path -Path $destinationPath)) {
        Write-Error "Destination path '$destinationPath' does not exist. Please provide a valid destination path."
        return
    }

    # Use robocopy to mirror the directories
    if ($PSCmdlet.ShouldProcess("Syncing $sourcePath to mirror $destinationPath")) {
        robocopy $sourcePath $destinationPath /MIR /R:5 /W:1
        Write-Output "Sync completed from $sourcePath to mirror $destinationPath."
    } else {
        Write-Output "Starting a dry run of the sync operation..."
        robocopy $sourcePath $destinationPath /MIR /R:5 /W:1 /L
        Write-Output "Dry run completed. No changes were made."
    }
}