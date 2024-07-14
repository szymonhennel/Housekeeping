function Remove-EmptyDirectory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        [Parameter(Mandatory=$false)]
        [switch]$OnlySubDirectories
    )

    if ($Recurse) {
        # Remove any empty subdirectories recursively (directories containing only empty directories will also be removed)
        $simulatedDeletions = @() # For WhatIf mode
        do {
            $emptyDirectories = Get-ChildItem -Path $Target -Recurse -Directory | 
                Where-Object { -not ($_.GetFileSystemInfos() | Where-Object { $simulatedDeletions -notcontains $_.FullName }) -and ($OnlySubDirectories -or $_.FullName -ne $Target) } | 
                Where-Object { $simulatedDeletions -notcontains $_.FullName } | 
                Select-Object -ExpandProperty FullName

            foreach ($dir in $emptyDirectories) {
                if ($PSCmdlet.ShouldProcess($dir, "Remove empty directory")) {
                    Remove-Item -Path $dir
                    Write-Host "Removed empty directory: $dir"
                } else {
                    # Simulate deletion by adding to the list, or actually delete if not in WhatIf mode
                    $simulatedDeletions += $dir
                }
            }
            # Condition to exit the loop: No more empty directories or all would-be-deleted directories are simulated
        } while ($emptyDirectories.Count -gt 0)
    }
    
    if (-not $OnlySubDirectories) {
        # Remove the target directory if it is empty
        if ((Get-ChildItem -Path $Target | Where-Object { $simulatedDeletions -notcontains $_.FullName }).Count -eq 0) {
            if ($PSCmdlet.ShouldProcess($Target, "Remove empty directory")) {
                Remove-Item -Path $Target
                Write-Host "Removed empty directory: $Target"
            }
        }
    }
}