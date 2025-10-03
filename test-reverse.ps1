# Load the module
Import-Module .\MuFo.psm1 -Force

# Mock data
$audioFiles = @(
    [PSCustomObject]@{
        Title = "Test Song 1"
        DiscNumber = 1
        TrackNumber = 1
        Duration = 200000  # ms
        FilePath = "C:\temp\test1.mp3"
    },
    [PSCustomObject]@{
        Title = "Test Song 2"
        DiscNumber = 1
        TrackNumber = 2
        Duration = 180000
        FilePath = "C:\temp\test2.mp3"
    }
)

$spotifyTracks = @(
    [PSCustomObject]@{
        name = "Test Song 1"
        disc_number = 1
        track_number = 1
        duration_ms = 200000
        id = "spotify1"
    },
    [PSCustomObject]@{
        name = "Test Song 2"
        disc_number = 1
        track_number = 2
        duration_ms = 180000
        id = "spotify2"
    },
    [PSCustomObject]@{
        name = "Test Song 3"
        disc_number = 1
        track_number = 3
        duration_ms = 190000
        id = "spotify3"
    }
)

# Test without -Reverse
Write-Host "Test 1: Without -Reverse (should iterate over Spotify tracks)"
$result1 = Set-Tracks -SortMethod "byTrackNumber" -AudioFiles $audioFiles -SpotifyTracks $spotifyTracks
$result1 | ForEach-Object { Write-Host "Spotify: $($_.SpotifyTrack.name) | Audio: $($_.AudioFile.Title)" }

# Test with -Reverse
Write-Host "`nTest 2: With -Reverse (should iterate over audio files)"
$result2 = Set-Tracks -SortMethod "byTrackNumber" -AudioFiles $audioFiles -SpotifyTracks $spotifyTracks -Reverse
$result2 | ForEach-Object { Write-Host "Spotify: $($_.SpotifyTrack.name) | Audio: $($_.AudioFile.Title)" }

# Test toggle simulation
Write-Host "`nTest 3: Simulating toggle (start false, then true)"
$reverseFlag = $false
Write-Host "Flag: $reverseFlag"
$result3 = Set-Tracks -SortMethod "byTrackNumber" -AudioFiles $audioFiles -SpotifyTracks $spotifyTracks -Reverse:$reverseFlag
$result3 | ForEach-Object { Write-Host "Spotify: $($_.SpotifyTrack.name) | Audio: $($_.AudioFile.Title)" }

$reverseFlag = $true
Write-Host "Flag: $reverseFlag"
$result4 = Set-Tracks -SortMethod "byTrackNumber" -AudioFiles $audioFiles -SpotifyTracks $spotifyTracks -Reverse:$reverseFlag
$result4 | ForEach-Object { Write-Host "Spotify: $($_.SpotifyTrack.name) | Audio: $($_.AudioFile.Title)" }