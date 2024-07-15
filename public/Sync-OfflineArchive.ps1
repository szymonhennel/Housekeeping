function Sync-OfflineArchive {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Source = "Offline_Archive",

        [Parameter(Mandatory=$false)]
        [string]$Destination = "Szymon_Offline_Archive_Mirror",

        [Parameter(Mandatory=$false)]
        [string]$SourceDriveSerialNumber = "Z131909R0JN8U6S",

        [Parameter(Mandatory=$false)]
        [string]$DestinationDriveSerialNumber = "957EE7654321",

        [Parameter(Mandatory=$false)]
        [string]$SourcePartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001",

        [Parameter(Mandatory=$false)]
        [string]$DestinationPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    )
    
    $Source = Get-DrivePath -Path $Source -DiskSerialNumber $SourceDriveSerialNumber -PartitionUUID $SourcePartitionUUID
    $Destination = Get-DrivePath -Path $Destination -DiskSerialNumber $DestinationDriveSerialNumber -PartitionUUID $DestinationPartitionUUID

    # Check if the source and destination paths exist
    if (-not (Test-Path -Path $Source)) {
        Write-Error "Source path '$Source' does not exist. Please provide a valid source path."
        return
    }
    if (-not (Test-Path -Path $Destination)) {
        Write-Error "Destination path '$Destination' does not exist. Please provide a valid destination path."
        return
    }

    # Use robocopy to mirror the directories
    if ($PSCmdlet.ShouldProcess("Syncing $Source to mirror $Destination")) {
        robocopy $Source $Destination /MIR /R:5 /W:1
        Write-Output "Sync completed from $Source to mirror $Destination."
    } else {
        Write-Output "Starting a dry run of the sync operation..."
        robocopy $Source $Destination /MIR /R:5 /W:1 /L
        Write-Output "Dry run completed. No changes were made."
    }
}