function Get-DriveLetter {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SerialNumber,

        [Parameter(Mandatory=$true)]
        [string]$PartitionUUID
    )
    # Retrieve the drive letter for the partitions with the specified serial number and partition UUID
    $diskNumber = (Get-Disk | Where-Object SerialNumber -eq $SerialNumber).Number
    if (-not $diskNumber) {
        Write-Error "Disk with serial number '$SerialNumber' not found."
        return
    }

    $driveLetter = (Get-Partition | Where-Object { $_.DiskNumber -eq $diskNumber -and $_.UniqueId -eq $PartitionUUID }).DriveLetter

    # Check if $driveLetter is empty and abort the function if so
    if ([string]::IsNullOrEmpty($driveLetter)) {
        Write-Error "Drive letter not found for partition with UUID '$PartitionUUID'. The drive with serial number '$SerialNumber' has been identified as disk number $diskNumber."
        return
    }

    # Return the drive letter
    $driveLetter   
}