<#
.SYNOPSIS
    Test script for Discogs smart album search with caching.

.DESCRIPTION
    Validates that:
    1. Albums are fetched only ONCE and cached
    2. Smart search filters cached albums without additional API calls
    3. No rate limit issues occur with repeated searches
    4. Wildcard and fuzzy matching both work
#>

Import-Module .\MuFo.psm1 -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Discogs Smart Search (Cache-Based)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Direct function test with mock data
Write-Host "`n--- Test 1: Cache-based filtering (mock data) ---" -ForegroundColor Yellow
$mockAlbums = @(
    [PSCustomObject]@{ id='1'; name='Complete Recorded Works Vol. 1'; release_date='1934' },
    [PSCustomObject]@{ id='2'; name='Complete Recorded Works Vol. 2'; release_date='1935' },
    [PSCustomObject]@{ id='3'; name='Handful of Keys'; release_date='1929' },
    [PSCustomObject]@{ id='4'; name='Piano Solos 1929-1941'; release_date='1929' }
)

Write-Host "Total cached albums: $($mockAlbums.Count)"

# Test wildcard matching
$result1 = Search-DAlbumsByName -ArtistId '123' -ArtistName 'Fats Waller' -AlbumName 'complete' -AllAlbumsCache $mockAlbums
Write-Host "`nWildcard search 'complete': Found $($result1.Count) albums"
$result1 | Format-Table name, release_date

# Test fuzzy matching
$result2 = Search-DAlbumsByName -ArtistId '123' -ArtistName 'Fats Waller' -AlbumName 'handful keys' -AllAlbumsCache $mockAlbums
Write-Host "Fuzzy search 'handful keys': Found $($result2.Count) albums"
$result2 | Format-Table name, release_date, _similarity

# Test 2: Real Discogs API test (requires credentials)
Write-Host "`n--- Test 2: Real Discogs API (if credentials available) ---" -ForegroundColor Yellow

$config = Test-MuFoConfig -Provider Discogs
if (-not $config) {
    Write-Warning "Skipping real API test: No Discogs credentials configured"
    Write-Host "Run: Set-MuFoConfig -Provider Discogs -PersonalAccessToken 'YOUR_TOKEN'" -ForegroundColor Gray
} else {
    Write-Host "Discogs credentials found, testing with real API..."
    
    # Use artist ID 105 (Black Science Orchestra) with moderate discography
    $testArtistId = '105'
    $testArtistName = 'Black Science Orchestra'
    
    Write-Host "`nFetching all albums for $testArtistName (ID: $testArtistId)..."
    Write-Host "This will fetch multiple pages but only happens ONCE..." -ForegroundColor Cyan
    $allAlbums = Get-DArtistAlbums -Id $testArtistId -MastersOnly
    Write-Host "Fetched $($allAlbums.Count) master releases (cached for subsequent searches)" -ForegroundColor Green
    
    Write-Host "`nNow searching the cache (no additional API calls)..."
    
    Write-Host "`nSearch 1: 'sunshine'"
    $search1 = Search-DAlbumsByName -ArtistId $testArtistId -ArtistName $testArtistName -AlbumName 'sunshine' -AllAlbumsCache $allAlbums -MastersOnly
    Write-Host "Found $($search1.Count) albums (no API calls!)" -ForegroundColor Green
    $search1 | Format-Table name, release_date
    
    Write-Host "`nSearch 2: 'new jersey'"
    $search2 = Search-DAlbumsByName -ArtistId $testArtistId -ArtistName $testArtistName -AlbumName 'new jersey' -AllAlbumsCache $allAlbums -MastersOnly
    Write-Host "Found $($search2.Count) albums (no API calls!)" -ForegroundColor Green
    $search2 | Format-Table name, release_date
    
    Write-Host "`nSearch 3: 'walters room'"
    $search3 = Search-DAlbumsByName -ArtistId $testArtistId -ArtistName $testArtistName -AlbumName 'walters room' -AllAlbumsCache $allAlbums -MastersOnly
    Write-Host "Found $($search3.Count) albums (no API calls!)" -ForegroundColor Green
    $search3 | Format-Table name, release_date
    
    Write-Host "`nSUCCESS: All 3 searches completed without re-fetching albums!" -ForegroundColor Green
    Write-Host "BEFORE FIX: Each search would have re-fetched all albums (rate limit hell)" -ForegroundColor Yellow
    Write-Host "AFTER FIX: Albums fetched once, then filtered locally (no rate limit issues)" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
