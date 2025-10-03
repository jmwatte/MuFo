# Simulate the call to Set-Tracks as it happens in Invoke-MuFoManual.ps1 line 325

Import-Module .\MuFo.psm1 -Force

# Mock data similar to what might be in Invoke-MuFoManual
$sortMethod = "byTrackNumber"
$audioFiles = @(
    [PSCustomObject]@{
        Title = "Song 1"
        DiscNumber = 1
        TrackNumber = 1
        Duration = 200000
        FilePath = "C:\temp\song1.mp3"
    },
    [PSCustomObject]@{
        Title = "Song 2"
        DiscNumber = 1
        TrackNumber = 2
        Duration = 180000
        FilePath = "C:\temp\song2.mp3"
    }
)
$tracksForAlbum = @(
    [PSCustomObject]@{
        name = "Song 1"
        disc_number = 1
        track_number = 1
        duration_ms = 200000
        id = "track1"
    },
    [PSCustomObject]@{
        name = "Song 2"
        disc_number = 1
        track_number = 2
        duration_ms = 180000
        id = "track2"
    }
)
$reverseSource = $false  # Or $true to test reverse

Write-Host "Simulating the call from Invoke-MuFoManual.ps1 line 325:"
Write-Host "`$pairedTracks = Set-Tracks -SortMethod `$sortMethod -AudioFiles `$audioFiles -SpotifyTracks `$tracksForAlbum -Reverse `$reverseSource"
Write-Host "Where:"
Write-Host "  SortMethod: $sortMethod"
Write-Host "  ReverseSource: $reverseSource"
Write-Host "  AudioFiles count: $($audioFiles.Count)"
Write-Host "  SpotifyTracks count: $($tracksForAlbum.Count)"
Write-Host ""

# The actual call
$pairedTracks = Set-Tracks -SortMethod $sortMethod -AudioFiles $audioFiles -SpotifyTracks $tracksForAlbum -Reverse $reverseSource

Write-Host "Result: `$pairedTracks contains $($pairedTracks.Count) pairs"
foreach ($pair in $pairedTracks) {
    Write-Host "  SpotifyTrack: $($pair.SpotifyTrack?.name ?? 'null') | AudioFile: $($pair.AudioFile?.Title ?? 'null')"
}