# Quick performance test - just one album

Write-Host "=== Quick Performance Test ===" -ForegroundColor Cyan

# Import optimized function
. "$PSScriptRoot\Private\Get-SpotifyAlbumMatches-Fast.ps1"

$testAlbum = "Fratres"
$testArtist = "Arvo Pärt" 
$testYear = "1995"
$query = "artist:`"$testArtist`" album:`"$testAlbum`" year:$testYear"

Write-Host "Testing: $testAlbum by $testArtist ($testYear)" -ForegroundColor Yellow
Write-Host "Query: $query" -ForegroundColor White

# Test current approach
Write-Host "`nCURRENT APPROACH:" -ForegroundColor Red
$stopwatch1 = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $currentResults = Get-SpotifyAlbumMatches -Query $query -AlbumName $testAlbum
    $stopwatch1.Stop()
    
    Write-Host "Time: $($stopwatch1.ElapsedMilliseconds)ms" -ForegroundColor White
    Write-Host "Results: $($currentResults.Count)" -ForegroundColor White
    if ($currentResults.Count -gt 0) {
        Write-Host "Best: $($currentResults[0].AlbumName) (Score: $([math]::Round($currentResults[0].Score, 2)))" -ForegroundColor White
    }
} catch {
    $stopwatch1.Stop()
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $currentResults = @()
}

# Test optimized approach  
Write-Host "`nOPTIMIZED APPROACH:" -ForegroundColor Green
$stopwatch2 = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $optimizedResults = Get-SpotifyAlbumMatches-Fast -Query $query -AlbumName $testAlbum -ArtistName $testArtist -Year $testYear -MinScore 0.6
    $stopwatch2.Stop()
    
    Write-Host "Time: $($stopwatch2.ElapsedMilliseconds)ms" -ForegroundColor White
    Write-Host "Results: $($optimizedResults.Count)" -ForegroundColor White
    if ($optimizedResults.Count -gt 0) {
        Write-Host "Best: $($optimizedResults[0].AlbumName) (Score: $([math]::Round($optimizedResults[0].Score, 2)))" -ForegroundColor White
    }
} catch {
    $stopwatch2.Stop()
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $optimizedResults = @()
}

# Compare
if ($stopwatch1.ElapsedMilliseconds -gt 0 -and $stopwatch2.ElapsedMilliseconds -gt 0) {
    $speedup = [math]::Round($stopwatch1.ElapsedMilliseconds / $stopwatch2.ElapsedMilliseconds, 1)
    Write-Host "`nSpeedup: ${speedup}x faster!" -ForegroundColor Cyan
}