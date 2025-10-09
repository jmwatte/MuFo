Import-Module -Name (Join-Path $PSScriptRoot '..\..\MuFo.psm1') -Force -ErrorAction Stop

$fixture = Resolve-Path (Join-Path $PSScriptRoot '..\..\debug-qobuz-album.html')
Write-Host "Using fixture: $fixture"

$tracks = Get-QAlbumTracks -HtmlFile $fixture
if (-not $tracks) { Write-Error "No tracks returned from Get-QAlbumTracks"; exit 2 }

# Group by disc_number and print counts
$group = $tracks | Group-Object -Property disc_number | Sort-Object Name
Write-Host "Track counts by disc:" -ForegroundColor Cyan
foreach ($g in $group) { Write-Host "Disc $($g.Name): $($g.Count)" }

# Find the label positions in the HTML for sanity-check
$html = Get-Content -Raw -Path $fixture
$pos1 = $html.IndexOf('DISQUE 1')
$pos2 = $html.IndexOf('DISQUE 2')
Write-Host "DISQUE 1 position: $pos1  DISQUE 2 position: $pos2"

# Check that all tracks that appear after DISQUE 2 textual label but before EOF have disc_number 2
# We'll approximate by using track nodes that contain data-disk="2" or by relying on ordering
$tracksAfter2 = $tracks | Where-Object { $_.disc_number -eq 2 }
if ($tracksAfter2.Count -eq 0) { Write-Error "No tracks found with disc_number 2"; exit 3 }

Write-Host "Found $($tracksAfter2.Count) tracks for disc 2. Sample IDs: $((($tracksAfter2|Select-Object -First 5).id) -join ', ')" -ForegroundColor Green

# Basic assertions
$errors = @()
foreach ($t in $tracks) {
    if (-not ($t.PSObject.Properties.Match('disc_number'))) { $errors += "Track $($t.id) missing disc_number"; continue }
    if (-not ($t.PSObject.Properties.Match('track_number'))) { $errors += "Track $($t.id) missing track_number" }
}

if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 4 }

Write-Host "All basic assertions passed.\nDetails:" -ForegroundColor Cyan
$tracks | Select-Object id,name,disc_number,track_number,duration_ms,Artist | Format-Table -AutoSize

Write-Host "TEST PASSED" -ForegroundColor Green