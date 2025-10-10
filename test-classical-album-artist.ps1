# Test Get-Tags function with classical music
# Verifies that album artist is set to performers (conductor/orchestra) instead of composer

$scriptRoot = $PSScriptRoot
. "$scriptRoot\Private\Get-Tags.ps1"
. "$scriptRoot\Private\Get-GenresTags.ps1"
. "$scriptRoot\Private\Get-IfExists.ps1"

Write-Host "`n=== Testing Get-Tags with Classical Music ===" -ForegroundColor Cyan

# Test Case 1: Classical music with conductor and orchestra
Write-Host "`n--- Test 1: Discogs classical with conductor and orchestra ---" -ForegroundColor Yellow

$artist = [PSCustomObject]@{
    name = "Hector Berlioz"  # Composer
    genres = @()
}

$album = [PSCustomObject]@{
    name = "La Valse"
    genre = "Classical"
    genres = @("Classical")
    release_date = "2025-01-01"
}

$track = [PSCustomObject]@{
    name = "No.1, Rêveries – Passions"
    track_number = 1
    disc_number = 1
    artists = @(
        [PSCustomObject]@{ name = "Hector Berlioz" }
        [PSCustomObject]@{ name = "Maurice Ravel" }
        [PSCustomObject]@{ name = "Klaus Mäkelä" }
        [PSCustomObject]@{ name = "Orchestre De Paris" }
    )
    Conductor = "Klaus Mäkelä"
    composer = @("Hector Berlioz", "Maurice Ravel")
}

$tags = Get-Tags -Artist $artist -Album $album -SpotifyTrack $track -Verbose

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Album: $($tags.Album)"
Write-Host "  Title: $($tags.Title)"
Write-Host "  Track Artists (Performers): $($tags.Performers)"
Write-Host "  Album Artist: $($tags.AlbumArtist)" -ForegroundColor $(if ($tags.AlbumArtist -eq "Hector Berlioz") { "Red" } else { "Green" })
Write-Host "  Composers: $($tags.Composers)"
Write-Host "  Conductor: $($tags.Conductor)"
Write-Host "  Genre: $($tags.Genres)"

if ($tags.AlbumArtist -match "Klaus|Orchestre") {
    Write-Host "`n✓ SUCCESS: Album artist uses performers!" -ForegroundColor Green
} else {
    Write-Host "`n✗ FAILED: Album artist still using composer: $($tags.AlbumArtist)" -ForegroundColor Red
}

# Test Case 2: Non-classical music (should use artist name)
Write-Host "`n--- Test 2: Non-classical music (should use artist name) ---" -ForegroundColor Yellow

$artist2 = [PSCustomObject]@{
    name = "The Beatles"
    genres = @("Rock", "Pop")
}

$album2 = [PSCustomObject]@{
    name = "Abbey Road"
    genre = "Rock"
    genres = @("Rock", "Pop")
    release_date = "1969-09-26"
}

$track2 = [PSCustomObject]@{
    name = "Come Together"
    track_number = 1
    disc_number = 1
    artists = @(
        [PSCustomObject]@{ name = "The Beatles" }
    )
}

$tags2 = Get-Tags -Artist $artist2 -Album $album2 -SpotifyTrack $track2 -Verbose

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Album: $($tags2.Album)"
Write-Host "  Album Artist: $($tags2.AlbumArtist)" -ForegroundColor $(if ($tags2.AlbumArtist -eq "The Beatles") { "Green" } else { "Red" })
Write-Host "  Genre: $($tags2.Genres)"

if ($tags2.AlbumArtist -eq "The Beatles") {
    Write-Host "`n✓ SUCCESS: Non-classical uses artist name!" -ForegroundColor Green
} else {
    Write-Host "`n✗ FAILED: Expected 'The Beatles', got: $($tags2.AlbumArtist)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
