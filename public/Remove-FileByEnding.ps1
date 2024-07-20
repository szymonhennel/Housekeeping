function Remove-FileByEnding {
    [CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[string]$Path,
		[string[]]$Endings,
		[switch]$Recurse,
		[switch]$Safely
	)

	Get-ChildItem -Path $Path -Recurse:$Recurse -File | ForEach-Object {
		foreach ($ending in $Endings) {
			if ($_.Name.EndsWith($ending)) {
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
				break
			}
		}
	}
}