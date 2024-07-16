function Remove-EmacsBackupFiles {
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

    Get-ChildItem -Path $Path -Recurse:$Recurse -File | ForEach-Object {
        foreach ($marker in $backupMarkers) {
            if ($_.Name.EndsWith($marker)) {
                if ($Safely) {
                    if ($PSCmdlet.ShouldProcess($_.FullName, "Move to Recycle Bin")) {
                        Remove-ItemSafely -Path $_.FullName
                    }
                } else {
                    if ($PSCmdlet.ShouldProcess($_.FullName, "Remove")) {
                        Remove-Item -Path $_.FullName
                    }
                }
                break
            }
        }
    }
}