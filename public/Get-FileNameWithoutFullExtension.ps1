function Get-FileNameWithoutFullExtension {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $baseFileName = Split-Path -Leaf $FileName

    if ($baseFileName  -match '^(.*?)(\.(?:\w+\.)*\w+)$') {
        return $Matches[1]
    } else {
        return [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    }
}