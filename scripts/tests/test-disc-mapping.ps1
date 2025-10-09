Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\..\Private"

$path = 'QTracksForAlbum - Copy.txt'
if (-not (Test-Path $path)) { Write-Error "Fixture not found: $path"; exit 2 }

. "${PSScriptRoot}\..\..\Public\Get-TracksFromHtml.ps1"
$parsed = Get-TracksFromHtml -Path $path

if (-not $parsed -or $parsed.Count -eq 0) { Write-Error 'No tracks parsed'; exit 2 }

# Find first occurrence of a disc label change by inspecting disc_number sequence
$seq = $parsed | Select-Object id, name, disc_number, track_number

Write-Output "Total parsed: $($seq.Count)"

$before = $seq | Where-Object { $_.disc_number -eq 1 }
$after = $seq | Where-Object { $_.disc_number -eq 2 }

if ($before.Count -eq 0 -or $after.Count -eq 0) {
    Write-Error "Expected tracks on disc 1 and disc 2; got disc1=$($before.Count) disc2=$($after.Count)"; exit 2
}

Write-Output "Disc1 count: $($before.Count)  Disc2 count: $($after.Count)"
Write-Output 'PASS: Disc mapping present for disc 1 and disc 2'
exit 0
