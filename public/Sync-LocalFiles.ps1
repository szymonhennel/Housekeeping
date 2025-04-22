function Sync-LocalFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [string[]]$Source = @(
            "C:\Users\Szymon\Pictures"
            "C:\Users\Szymon\Documents\Games"
            "C:\Users\Szymon\Documents\Katrin"
            "C:\Users\Szymon\Documents\My_Documents"
            "C:\Users\Szymon\Documents\WindowsPowerShell"
        ),

        [Parameter(Mandatory=$false)]
        [string]$Destination = "Local_Files_Mirror",

        [Parameter(Mandatory=$false)]
        [string[]]$ExcludedDirs = @(
            "node_modules"
            ".venv"
        ),

        [Parameter(Mandatory=$false)]
        [string]$DestinationDriveSerialNumber = "Z131909R0JN8U6S",

        [Parameter(Mandatory=$false)]
        [string]$DestinationPartitionUUID = "{00000000-0000-0000-0000-100000000000}5000000000000001"
    )

    # Check if the source paths exist
    foreach ($Path in $Source) {
        if (-not (Test-Path -Path $Path)) {
            Write-Error "Source path '$Path' does not exist. Please provide a valid source path."
            return
        }
    }

    $Destination = Get-DrivePath -Path $Destination -DiskSerialNumber $DestinationDriveSerialNumber -PartitionUUID $DestinationPartitionUUID

    # Check if the destination path exists
    if (-not (Test-Path -Path $Destination)) {
        Write-Error "Destination path '$Destination' does not exist. Please provide a valid destination path."
        return
    }

    foreach ($Path in $Source) {
        Write-Verbose "Processing $Path"
        $LeafDirectory = Split-Path -Path $Path -Leaf
        $DestinationPath = Join-Path -Path $Destination -ChildPath $LeafDirectory

        if (-not (Test-Path -Path $DestinationPath)) {
            if ($PSCmdlet.ShouldProcess($DestinationPath, "Create directory")) {
                New-Item -ItemType Directory -Path $DestinationPath | Out-Null
                Write-Verbose "Created directory $DestinationPath"
            }
        }

        $RobocopyArgs = @(
            @($Path)
            @($DestinationPath)
            "/MIR"
            "/XD"
            $ExcludedDirs
            "/R:5"
            "/W:1"
        )

        if ($PSCmdlet.ShouldProcess("Syncing $Path to mirror $DestinationPath")) {
            robocopy @RobocopyArgs
        } else {
            $RobocopyArgs = $RobocopyArgs + "/L"
            Write-Output "Starting a dry run of the sync operation..."
            robocopy @RobocopyArgs
            Write-Output "Dry run completed. No changes were made."
        }
    }

}