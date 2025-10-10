# Test the album artist builder with real Discogs data
# Usage: .\test-album-artist-builder.ps1

$scriptRoot = $PSScriptRoot
. "$scriptRoot\Private\manual\Invoke-DiscogsRequest.ps1"
. "$scriptRoot\Private\manual\Get-DAlbumTracks.ps1"
. "$scriptRoot\Private\Get-IfExists.ps1"
. "$scriptRoot\Private\manual\Test-AlbumArtistAmbiguity.ps1"
. "$scriptRoot\Private\manual\Invoke-AlbumArtistBuilder.ps1"

Write-Host "`n=== Testing Album Artist Builder ===" -ForegroundColor Cyan

# Test with Händel/Koopman album (ambiguous case)
$releaseId = "35060666"

Write-Host "`nFetching Händel/Koopman album from Discogs..." -ForegroundColor Yellow
$release = Invoke-DiscogsRequest -Uri "/releases/$releaseId"
$tracks = Get-DAlbumTracks -Id $releaseId

$albumObj = [PSCustomObject]@{
    name = $release.title
    genre = if ($release.genres) { $release.genres -join ', ' } else { "Unknown" }
    genres = if ($release.genres) { $release.genres } else { @() }
}

$currentArtist = if ($release.artists -and $release.artists.Count -gt 0) { 
    $release.artists[0].name
} else { 
    "Unknown" 
}

Write-Host "`nAlbum: $($albumObj.name)" -ForegroundColor Cyan
Write-Host "Genre: $($albumObj.genre)" -ForegroundColor Cyan
Write-Host "Current album artist: $currentArtist" -ForegroundColor Cyan
Write-Host "Tracks: $($tracks.Count)" -ForegroundColor Gray

# Test ambiguity detection
Write-Host "`n--- Testing Ambiguity Detection ---" -ForegroundColor Yellow
$isAmbiguous = Test-AlbumArtistAmbiguity -Album $albumObj -Tracks $tracks -Verbose

if ($isAmbiguous) {
    Write-Host "✓ Ambiguity detected - would trigger album artist builder" -ForegroundColor Green
    
    Write-Host "`n--- Launching Album Artist Builder ---" -ForegroundColor Yellow
    Write-Host "(This is interactive - try selecting artists, reordering, etc.)" -ForegroundColor Gray
    Write-Host "Press any key to start..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    $newAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $albumObj.name -Tracks $tracks -CurrentAlbumArtist $currentArtist
    
    Clear-Host
    Write-Host "`n=== Results ===" -ForegroundColor Cyan
    Write-Host "Original album artist: $currentArtist" -ForegroundColor Yellow
    Write-Host "New album artist:      $newAlbumArtist" -ForegroundColor Green
    
} else {
    Write-Host "✗ No ambiguity detected - would not trigger builder" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
