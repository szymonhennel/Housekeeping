. "$PSScriptRoot\public\Move-CanonMP4.ps1"
. "$PSScriptRoot\public\Sync-OfflineArchive.ps1"
. "$PSScriptRoot\public\Move-Pictures.ps1"
. "$PSScriptRoot\public\Remove-EmptyDirectory.ps1"
. "$PSScriptRoot\public\Get-DriveLetter.ps1"
. "$PSScriptRoot\public\Get-DrivePath.ps1"

Export-ModuleMember -Function Move-CanonMP4
Export-ModuleMember -Function Sync-OfflineArchive
Export-ModuleMember -Function Move-Pictures
Export-ModuleMember -Function Remove-EmptyDirectory
Export-ModuleMember -Function Get-DriveLetter
Export-ModuleMember -Function Get-DrivePath