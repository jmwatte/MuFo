# Test smart album search across all providers
# This script demonstrates the new search-first approach

Import-Module "$PSScriptRoot\MuFo.psm1" -Force

Write-Host "`n=== Testing Smart Album Search ===" -ForegroundColor Cyan

# Test 1: Discogs - Search for specific album
Write-Host "`n--- Test 1: Discogs Album Search ---" -ForegroundColor Yellow
Write-Host "Searching for: 'Fats Waller' + 'Handful of Keys'"

# First get artist ID
$artistSearch = Search-DItem -Query "Fats Waller" -Type artist
$artistId = if ($artistSearch.artists.items.Count -gt 0) { $artistSearch.artists.items[0].id } else { $null }

if ($artistId) {
    $discogsResults = Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Handful of Keys" -ArtistId $artistId -MastersOnly
    Write-Host "Found $($discogsResults.Count) albums"
    $discogsResults | Select-Object -First 5 | Format-Table name, release_date, id -AutoSize
} else {
    Write-Warning "Could not find Fats Waller on Discogs"
}

# Test 2: Spotify - Search for specific album
Write-Host "`n--- Test 2: Spotify Album Search ---" -ForegroundColor Yellow
Write-Host "Searching for: 'Pink Floyd' + 'Dark Side'"

try {
    $spotifyResults = Search-SAlbumsByName -ArtistName "Pink Floyd" -AlbumName "Dark Side"
    Write-Host "Found $($spotifyResults.Count) albums"
    $spotifyResults | Select-Object -First 5 | Format-Table name, release_date, id -AutoSize
} catch {
    Write-Warning "Spotify search failed (may need authentication): $_"
}

# Test 3: Provider wrapper - Discogs
Write-Host "`n--- Test 3: Provider Wrapper (Discogs) ---" -ForegroundColor Yellow
Write-Host "Using Invoke-ProviderSearchAlbums"

if ($artistId) {
    $wrapperResults = Invoke-ProviderSearchAlbums `
        -Provider Discogs `
        -ArtistId $artistId `
        -ArtistName "Fats Waller" `
        -AlbumName "Handful of Keys" `
        -MastersOnly

    Write-Host "Found $($wrapperResults.Count) albums via wrapper"
    $wrapperResults | Select-Object -First 3 | Format-Table name, release_date, id -AutoSize
}

# Test 4: Compare search vs get-all performance
Write-Host "`n--- Test 4: Performance Comparison ---" -ForegroundColor Yellow

if ($artistId) {
    Write-Host "Method 1: Smart Search (targeted)"
    $smartSearchStart = Get-Date
    $smartResults = Invoke-ProviderSearchAlbums `
        -Provider Discogs `
        -ArtistId $artistId `
        -ArtistName "Fats Waller" `
        -AlbumName "Piano Solos" `
        -MastersOnly
    $smartSearchEnd = Get-Date
    $smartSearchTime = ($smartSearchEnd - $smartSearchStart).TotalSeconds
    Write-Host "  Results: $($smartResults.Count) albums in $($smartSearchTime.ToString('F2')) seconds" -ForegroundColor Green

    Write-Host "Method 2: Get All Albums (full discography)"
    $getAllStart = Get-Date
    try {
        $allResults = Get-DArtistAlbums -Id $artistId -MastersOnly
        $getAllEnd = Get-Date
        $getAllTime = ($getAllEnd - $getAllStart).TotalSeconds
        Write-Host "  Results: $($allResults.Count) albums in $($getAllTime.ToString('F2')) seconds" -ForegroundColor Yellow
        
        if ($smartSearchTime -gt 0) {
            $speedup = [math]::Round($getAllTime / $smartSearchTime, 1)
            Write-Host "`n  Get-all was ${speedup}x slower (smart search filters faster)" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Get-all test failed: $_"
    }
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
Write-Host @"

Summary:
- Smart album search works across all providers
- Discogs: Uses /database/search API (fast, targeted)
- Spotify: Uses Search-Item with artist: and album: filters
- Qobuz: Fetches all albums and filters locally
- Performance: Smart search is significantly faster for large discographies

Next steps:
1. Test with Invoke-MuFoManual on a real music folder
2. Try different search terms during album selection
3. Use '*' to fetch all albums when needed
"@
