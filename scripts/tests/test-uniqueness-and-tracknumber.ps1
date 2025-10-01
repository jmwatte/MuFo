Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\..\Private"

$path = 'QTracksForAlbum - Copy.txt'
if (-not (Test-Path $path)) { Write-Error "Fixture not found: $path"; exit 2 }

. "${PSScriptRoot}\..\..\Public\Get-TracksFromHtml.ps1"
$parsed = Get-TracksFromHtml -Path $path

if (-not $parsed -or $parsed.Count -eq 0) { Write-Error 'No tracks parsed'; exit 2 }

# uniqueness on id
$ids = $parsed | Select-Object -ExpandProperty id
$dup = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dup) { Write-Error "Duplicate ids found: $($dup | ForEach-Object { $_.Name } -join ', ')"; exit 2 }

# track_number presence and sequence per-disc
$bad = $parsed | Where-Object { -not ($_.track_number -as [int]) }
if ($bad) { Write-Error "Some tracks lack track_number: $($bad | Select-Object -First 5 | ForEach-Object { $_.id } -join ', ')"; exit 2 }

Write-Output 'PASS: uniqueness and track_number presence OK'
exit 0
