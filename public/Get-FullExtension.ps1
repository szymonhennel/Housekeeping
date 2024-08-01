function Get-FullExtension {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    if ($FileName -match '(\.(?:\w+\.)*\w+)$') {
        return $Matches[1]
    } else {
        return [System.IO.Path]::GetExtension($FileName)
    }
}