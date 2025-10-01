. "$PSScriptRoot\..\Public\Get-TracksFromHtml.ps1"
$r = Get-TracksFromHtml -Path "$PSScriptRoot\..\Private\QTracksForAlbum.html"
$r | Select-Object -First 6 | Format-List *
Write-Output "COUNT: $($r.Count)"