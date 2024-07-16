function Remove-BackupFiles {
    [CmdletBinding(supportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Recurse,

        [Parameter(Mandatory = $false)]
        [switch]$Safely
    )

    $backupMarkers = @("~", ".bak", ".old", ".backup")

    Remove-FileByEnding -Path $Path -Endings $backupMarkers -Recurse:$Recurse -Safely:$Safely

}