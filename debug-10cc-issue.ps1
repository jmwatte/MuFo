# Debug artist search issue
Write-Host "=== Debugging 10cc Artist Search Issue ===" -ForegroundColor Cyan

# Test the artist search directly
try {
    Write-Host "`n1. Testing direct search for '10cc'..." -ForegroundColor Yellow
    $artists = Search-Artist -Name "10cc" -ErrorAction Stop
    
    Write-Host "Found $($artists.Count) artists:" -ForegroundColor Gray
    foreach ($artist in $artists | Select-Object -First 5) {
        Write-Host "  - $($artist.name) (popularity: $($artist.popularity))" -ForegroundColor White
    }
    
    Write-Host "`n2. Testing album search for '10cc'..." -ForegroundColor Yellow
    $albums = Get-SpotifyAlbumMatches-Fast -ArtistName "10cc" -ErrorAction Stop
    
    Write-Host "Found $($albums.Count) albums:" -ForegroundColor Gray
    foreach ($album in $albums | Select-Object -First 5) {
        Write-Host "  - Artist: $($album.artists[0].name) | Album: $($album.name)" -ForegroundColor White
    }
    
    Write-Host "`n3. Testing string similarity..." -ForegroundColor Yellow
    $similarity1 = Get-StringSimilarity-New -String1 "10cc" -String2 "10cc"
    $similarity2 = Get-StringSimilarity-New -String1 "10cc" -String2 "Daens, de musical"
    
    Write-Host "  '10cc' vs '10cc': $similarity1" -ForegroundColor White
    Write-Host "  '10cc' vs 'Daens, de musical': $similarity2" -ForegroundColor White
    
} catch {
    Write-Host "Error during search: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`n4. Testing actual Invoke-MuFo on test data..." -ForegroundColor Yellow

# Create a minimal test structure
$testPath = "C:\temp\TestMusic\10cc"
if (Test-Path $testPath) {
    Write-Host "Test path exists, running Invoke-MuFo..." -ForegroundColor Gray
    
    try {
        $result = Invoke-MuFo -Path $testPath -WhatIf -Verbose:$false -ErrorAction Stop
        
        Write-Host "Result:" -ForegroundColor Gray
        Write-Host "  LocalArtist: $($result.LocalArtist)" -ForegroundColor White
        Write-Host "  SpotifyArtist: $($result.SpotifyArtist)" -ForegroundColor White
        Write-Host "  Decision: $($result.Decision)" -ForegroundColor White
        
    } catch {
        Write-Host "Error in Invoke-MuFo: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Test path doesn't exist, skipping Invoke-MuFo test" -ForegroundColor Gray
}