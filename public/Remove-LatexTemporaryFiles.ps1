function Remove-LatexTemporaryFiles {
    [CmdletBinding(supportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Recurse,

        [Parameter(Mandatory = $false)]
        [switch]$Safely
    )

    $extensions = @(
        ".aux", ".bbl", ".blg", ".el", ".fdb_latexmk", ".fls", ".lof", ".log", ".lot", ".out", ".synctex.gz", ".toc"
    )

    Get-ChildItem -Path $Path -Recurse:$Recurse -File | ForEach-Object {
        if ($extensions -contains $_.Extension) {
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

    # Remove empty auto directories. When identifying them, we ignore .el files so that -WhatIf gives a realistic
    # result. Without -WhatIf, those files will have been deleted in the previous step.
    Get-ChildItem -Path $Path -Recurse -Directory | 
        Where-Object { $_.Name -eq "auto" -and (Get-ChildItem -Path $_.FullName -File -Force | Where-Object { $_.Extension -ne ".el" }).Count -eq 0 } |
        ForEach-Object {
            if ($Safely) {
                if ($PSCmdlet.ShouldProcess($_.FullName, "Move to Recycle Bin")) {
                    Remove-ItemSafely -Path $_.FullName
                    Write-Verbose "Moved $_.FullName to Recycle Bin"
                }
            } else {
                if ($PSCmdlet.ShouldProcess($_.FullName, "Remove")) {
                    Remove-Item -Path $_.FullName
                }
            }
        }
}