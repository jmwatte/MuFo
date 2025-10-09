#Requires -Version 7.3

<#
.SYNOPSIS
Test Discogs filtering options.

.DESCRIPTION
Shows the difference between various Discogs filtering options.
#>

Write-Host "`n=== Discogs Release Filtering Test ===" -ForegroundColor Cyan

# Import functions
. ".\Private\manual\Invoke-DiscogsRequest.ps1"
. ".\Private\manual\Get-DArtistAlbums.ps1"

$artistId = 253482  # Fats Waller

Write-Host "`nArtist: Fats Waller (ID: $artistId)" -ForegroundColor Yellow

# Test 1: Default (Main artist albums only, no singles/compilations)
Write-Host "`n1. DEFAULT - Main artist albums only (no singles/compilations)" -ForegroundColor Cyan
$default = Get-DArtistAlbums -Id $artistId
Write-Host "Found: $($default.Count) releases" -ForegroundColor Green
if ($default.Count -gt 0) {
    $default | Select-Object -First 5 name, release_date, type | Format-Table
}

# Test 2: Masters Only (canonical versions only)
Write-Host "`n2. MASTERS ONLY - Just the canonical versions" -ForegroundColor Cyan
$masters = Get-DArtistAlbums -Id $artistId -MastersOnly
Write-Host "Found: $($masters.Count) master releases" -ForegroundColor Green
if ($masters.Count -gt 0) {
    $masters | Select-Object -First 5 name, release_date, type | Format-Table
}

# Test 3: Include Singles
Write-Host "`n3. WITH SINGLES - Albums + singles" -ForegroundColor Cyan
$withSingles = Get-DArtistAlbums -Id $artistId -IncludeSingles
Write-Host "Found: $($withSingles.Count) releases (albums + singles)" -ForegroundColor Green

# Test 4: Include Compilations
Write-Host "`n4. WITH COMPILATIONS - Albums + compilations" -ForegroundColor Cyan
$withCompilations = Get-DArtistAlbums -Id $artistId -IncludeCompilations
Write-Host "Found: $($withCompilations.Count) releases (albums + compilations)" -ForegroundColor Green

# Test 5: Everything
Write-Host "`n5. EVERYTHING - All releases" -ForegroundColor Cyan
$everything = Get-DArtistAlbums -Id $artistId -IncludeSingles -IncludeCompilations -IncludeAppearances
Write-Host "Found: $($everything.Count) total releases (everything!)" -ForegroundColor Green

Write-Host "`n=== Summary ===" -ForegroundColor Yellow
Write-Host "Default (albums only):              $($default.Count)" -ForegroundColor White
Write-Host "Masters only:                       $($masters.Count)" -ForegroundColor White
Write-Host "With singles:                       $($withSingles.Count)" -ForegroundColor White
Write-Host "With compilations:                  $($withCompilations.Count)" -ForegroundColor White
Write-Host "Everything:                         $($everything.Count)" -ForegroundColor White

Write-Host "`n=== Recommendation ===" -ForegroundColor Cyan
Write-Host "For music library management, use DEFAULT (no extra flags)" -ForegroundColor Green
Write-Host "This gives you main artist albums without singles/compilations/appearances" -ForegroundColor Gray

Write-Host "`nTo use in Invoke-MuFoManual:" -ForegroundColor Yellow
Write-Host '  Invoke-MuFoManual "path" -Provider Discogs  # Uses default filtering' -ForegroundColor White
Write-Host ""
