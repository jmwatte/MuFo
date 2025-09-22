# MuFo Track Artist Complexity Test
# Tests MuFo's handling of albums with multiple featured artists

Write-Host "🎭 MUFO TRACK ARTIST COMPLEXITY TEST" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

# Import MuFo module
Import-Module "$PSScriptRoot\MuFo.psm1" -Force

Write-Host "`n🔍 Testing MuFo's track artist handling logic..." -ForegroundColor Cyan

# Simulate Afrika Bambaataa album data (realistic Spotify response)
$mockSpotifyAlbum = @{
    name = "Planet Rock The Album"
    artists = @(
        @{ name = "Afrika Bambaataa"; id = "4ljZuCGGvsZOl5Sp1MNp4G" }
        @{ name = "The Soul Sonic Force"; id = "2PVGnP5PgKfDaGW8z4Xjvi" }
    )
    tracks = @{
        items = @(
            @{
                name = "Planet Rock"
                artists = @(
                    @{ name = "Afrika Bambaataa" }
                    @{ name = "The Soul Sonic Force" }
                )
            },
            @{
                name = "Looking For The Perfect Beat"
                artists = @(
                    @{ name = "Afrika Bambaataa" }
                    @{ name = "The Soul Sonic Force" }
                )
            },
            @{
                name = "Renegades Of Funk"
                artists = @(
                    @{ name = "Afrika Bambaataa" }
                    @{ name = "The Soul Sonic Force" }
                )
            },
            @{
                name = "Frantic Situation (feat. Shango)"
                artists = @(
                    @{ name = "Afrika Bambaataa" }
                    @{ name = "The Soul Sonic Force" }
                    @{ name = "Shango" }
                )
            }
        )
    }
}

Write-Host "`n📊 MOCK SPOTIFY ALBUM DATA:" -ForegroundColor Yellow
Write-Host "Album: $($mockSpotifyAlbum.name)" -ForegroundColor White
Write-Host "Main Artists: $($mockSpotifyAlbum.artists.name -join ' & ')" -ForegroundColor White
Write-Host "Track Count: $($mockSpotifyAlbum.tracks.items.Count)" -ForegroundColor White

Write-Host "`n🎵 TRACK ARTIST ANALYSIS:" -ForegroundColor Green
foreach ($track in $mockSpotifyAlbum.tracks.items) {
    $trackArtists = $track.artists.name -join ' & '
    $hasMultipleArtists = $track.artists.Count -gt 1
    $hasFeature = $track.name -like "*feat*" -or $track.name -like "*ft*"
    
    Write-Host "`n  🎵 $($track.name)" -ForegroundColor Cyan
    Write-Host "     Artists: $trackArtists" -ForegroundColor White
    Write-Host "     Multiple Artists: $hasMultipleArtists" -ForegroundColor $(if ($hasMultipleArtists) { "Yellow" } else { "Gray" })
    Write-Host "     Has Featuring: $hasFeature" -ForegroundColor $(if ($hasFeature) { "Magenta" } else { "Gray" })
}

# Test MuFo's track artist processing logic
Write-Host "`n🔧 TESTING MUFO TRACK ARTIST PROCESSING:" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

function Test-MuFoTrackArtistLogic {
    param($Album, $Track)
    
    # Simulate MuFo's track artist determination logic
    $albumArtists = $Album.artists.name
    $trackArtists = $Track.artists.name
    
    Write-Host "`n🎯 Track: $($Track.name)" -ForegroundColor Cyan
    Write-Host "   Album Artists: $($albumArtists -join ', ')" -ForegroundColor White
    Write-Host "   Track Artists: $($trackArtists -join ', ')" -ForegroundColor White
    
    # Logic 1: If track artists match album artists exactly
    if (($trackArtists | Sort-Object) -join ',' -eq ($albumArtists | Sort-Object) -join ',') {
        $recommendedArtist = $albumArtists -join ' & '
        Write-Host "   → SIMPLE: Use album artist(s): '$recommendedArtist'" -ForegroundColor Green
    }
    # Logic 2: If track has additional artists (featuring)
    elseif ($trackArtists.Count -gt $albumArtists.Count) {
        $additionalArtists = $trackArtists | Where-Object { $_ -notin $albumArtists }
        $recommendedArtist = "$($albumArtists -join ' & ') feat. $($additionalArtists -join ', ')"
        Write-Host "   → FEATURING: '$recommendedArtist'" -ForegroundColor Magenta
    }
    # Logic 3: If track has subset of album artists
    else {
        $recommendedArtist = $trackArtists -join ' & '
        Write-Host "   → SUBSET: Use track artists: '$recommendedArtist'" -ForegroundColor Yellow
    }
    
    return $recommendedArtist
}

# Test each track
$trackArtistResults = @()
foreach ($track in $mockSpotifyAlbum.tracks.items) {
    $result = Test-MuFoTrackArtistLogic -Album $mockSpotifyAlbum -Track $track
    $trackArtistResults += @{
        Track = $track.name
        RecommendedArtist = $result
    }
}

Write-Host "`n📋 FINAL TRACK ARTIST RECOMMENDATIONS:" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
foreach ($result in $trackArtistResults) {
    Write-Host "🎵 $($result.Track)" -ForegroundColor Cyan
    Write-Host "   Artist: $($result.RecommendedArtist)" -ForegroundColor White
}

# Test current MuFo functions if available
Write-Host "`n🧪 TESTING ACTUAL MUFO FUNCTIONS:" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow

try {
    # Test Get-SpotifyArtist-Enhanced with complex name
    $artistName = "Afrika Bambaataa and the Soul Sonic Force"
    Write-Host "`n🔍 Testing Get-SpotifyArtist-Enhanced with: '$artistName'" -ForegroundColor Cyan
    
    if (Get-Command "Get-SpotifyArtist-Enhanced" -ErrorAction SilentlyContinue) {
        $spotifyArtist = Get-SpotifyArtist-Enhanced -ArtistName $artistName -Verbose
        if ($spotifyArtist) {
            Write-Host "✅ Found Spotify artist: $($spotifyArtist.name)" -ForegroundColor Green
            Write-Host "   ID: $($spotifyArtist.id)" -ForegroundColor Gray
        }
        else {
            Write-Host "❌ No Spotify artist found" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠️  Get-SpotifyArtist-Enhanced function not available" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Error testing MuFo functions: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✅ TRACK ARTIST COMPLEXITY TEST COMPLETE!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "`nKey Findings:" -ForegroundColor Cyan
Write-Host "• MuFo should handle multiple track artists correctly" -ForegroundColor White
Write-Host "• Featuring artists should be detected and formatted properly" -ForegroundColor White
Write-Host "• Enhanced artist search should find complex artist names" -ForegroundColor White
Write-Host "• LocalArtist display should show correct folder name" -ForegroundColor White