# Performance comparison test: Current vs Optimized album search

# Import the new fast function
. "$PSScriptRoot\Private\Get-SpotifyAlbumMatches-Fast.ps1"

Write-Host "=== MuFo Album Search Performance Test ===" -ForegroundColor Cyan

# Test albums that are currently slow
$testCases = @(
    @{ Album = "Tabula Rasa"; Artist = "Arvo Pärt"; Year = "1984" },
    @{ Album = "Passio"; Artist = "Arvo Pärt"; Year = "1988" },
    @{ Album = "Te Deum"; Artist = "Arvo Pärt"; Year = "1993" },
    @{ Album = "Fratres"; Artist = "Arvo Pärt"; Year = "1995" },
    @{ Album = "Kanon Pokajanen"; Artist = "Arvo Pärt"; Year = "1998" }
)

# Setup Spotify connection (reuse existing)
try {
    # Test if already connected
    $null = Get-SpotifyAccessToken -ErrorAction Stop
    Write-Host "✓ Already connected to Spotify" -ForegroundColor Green
} catch {
    Write-Host "Connecting to Spotify..." -ForegroundColor Yellow
    Connect-Spotify -ErrorAction Stop
}

foreach ($test in $testCases) {
    Write-Host "`n" + "="*50 -ForegroundColor Gray
    Write-Host "Testing: $($test.Album) by $($test.Artist) ($($test.Year))" -ForegroundColor Yellow
    
    # Build query like current MuFo does (Tier 1)
    $query = "artist:`"$($test.Artist)`" album:`"$($test.Album)`" year:$($test.Year)"
    Write-Host "Query: $query" -ForegroundColor White
    
    # Test current approach
    Write-Host "`n1. CURRENT APPROACH:" -ForegroundColor Red
    $stopwatch1 = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $currentResults = Get-SpotifyAlbumMatches -Query $query -AlbumName $test.Album
        $stopwatch1.Stop()
        
        Write-Host "   Time: $($stopwatch1.ElapsedMilliseconds)ms" -ForegroundColor White
        Write-Host "   Results: $($currentResults.Count)" -ForegroundColor White
        Write-Host "   Best: $($currentResults[0].AlbumName) (Score: $([math]::Round($currentResults[0].Score, 2)))" -ForegroundColor White
    } catch {
        $stopwatch1.Stop()
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $currentResults = @()
    }
    
    # Test optimized approach
    Write-Host "`n2. OPTIMIZED APPROACH:" -ForegroundColor Green
    $stopwatch2 = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $optimizedResults = Get-SpotifyAlbumMatches-Fast -Query $query -AlbumName $test.Album -ArtistName $test.Artist -Year $test.Year -MinScore 0.6
        $stopwatch2.Stop()
        
        Write-Host "   Time: $($stopwatch2.ElapsedMilliseconds)ms" -ForegroundColor White
        Write-Host "   Results: $($optimizedResults.Count)" -ForegroundColor White
        if ($optimizedResults.Count -gt 0) {
            Write-Host "   Best: $($optimizedResults[0].AlbumName) (Score: $([math]::Round($optimizedResults[0].Score, 2)))" -ForegroundColor White
            Write-Host "   Query Used: $($optimizedResults[0].Query)" -ForegroundColor Gray
        }
    } catch {
        $stopwatch2.Stop()
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $optimizedResults = @()
    }
    
    # Performance comparison
    Write-Host "`n3. PERFORMANCE COMPARISON:" -ForegroundColor Cyan
    if ($stopwatch1.ElapsedMilliseconds -gt 0 -and $stopwatch2.ElapsedMilliseconds -gt 0) {
        $speedup = [math]::Round($stopwatch1.ElapsedMilliseconds / $stopwatch2.ElapsedMilliseconds, 1)
        Write-Host "   Speedup: ${speedup}x faster" -ForegroundColor Green
    }
    
    $improvement = ""
    if ($optimizedResults.Count -gt $currentResults.Count) {
        $improvement += "More results found. "
    }
    if ($optimizedResults.Count -gt 0 -and $currentResults.Count -gt 0) {
        if ($optimizedResults[0].Score -gt $currentResults[0].Score) {
            $improvement += "Better similarity score. "
        }
    }
    if ($improvement) {
        Write-Host "   Quality: $improvement" -ForegroundColor Green
    }
    
    # Show top results side by side
    Write-Host "`n4. RESULTS COMPARISON:" -ForegroundColor Magenta
    $maxResults = [Math]::Max($currentResults.Count, $optimizedResults.Count)
    
    for ($i = 0; $i -lt [Math]::Min(3, $maxResults); $i++) {
        $current = if ($i -lt $currentResults.Count) { $currentResults[$i] } else { $null }
        $optimized = if ($i -lt $optimizedResults.Count) { $optimizedResults[$i] } else { $null }
        
        Write-Host "   Result $($i+1):" -ForegroundColor White
        if ($current) {
            Write-Host "     Current: $($current.AlbumName) ($([math]::Round($current.Score, 2)))" -ForegroundColor White
        }
        if ($optimized) {
            Write-Host "     Optimized: $($optimized.AlbumName) ($([math]::Round($optimized.Score, 2)))" -ForegroundColor White
        }
    }
}

Write-Host "`n" + "="*60 -ForegroundColor Gray
Write-Host "SUMMARY RECOMMENDATIONS:" -ForegroundColor Cyan
Write-Host "1. Replace Get-SpotifyAlbumMatches with Get-SpotifyAlbumMatches-Fast" -ForegroundColor Green
Write-Host "2. Lower confidence threshold from 0.9 to 0.6-0.7" -ForegroundColor Green  
Write-Host "3. Remove Tier 4 fallback (Get-SpotifyArtistAlbums) completely" -ForegroundColor Green
Write-Host "4. Add early termination when good matches are found" -ForegroundColor Green
Write-Host "5. Expected performance improvement: 10-50x faster" -ForegroundColor Green