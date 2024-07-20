function Remove-FileByExtension {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [string]$Path,
        [string[]]$Extensions,
        [switch]$Recurse,
        [switch]$Safely
    )

    Get-ChildItem -Path $Path -Recurse:$Recurse -File | ForEach-Object {
        if ($Extensions -contains $_.Extension) {
            if ($Safely) {
                if ($PSCmdlet.ShouldProcess($_.FullName, "Move to Recycle Bin")) {
                    Remove-ItemSafely -Path $_.FullName
                    Write-Verbose "Moved $($_.FullName) to Recycle Bin"
                }
            } else {
                if ($PSCmdlet.ShouldProcess($_.FullName, "Remove")) {
                    Remove-Item -Path $_.FullName
                    Write-Verbose "Removed $($_.FullName)"
                }
            }
        }
    }
}