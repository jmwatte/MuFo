# Direct test of Spotify artist extraction - no loops, no Clear-Host
# Usage: .\test-spotify-artist-extraction.ps1 -AlbumId "spotify_album_id"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AlbumId
)

Write-Host "`n=== Direct Spotify Artist Extraction Test ===" -ForegroundColor Cyan
Write-Host "Album ID: $AlbumId`n" -ForegroundColor Gray

# Ensure Spotishell is loaded
if (-not (Get-Module -Name Spotishell)) {
    Write-Host "Loading Spotishell module..." -ForegroundColor Yellow
    Import-Module Spotishell -ErrorAction Stop
}

try {
    Write-Host "Fetching album details from Spotify..." -ForegroundColor Yellow
    $album = Get-Album -Id $AlbumId
    
    Write-Host "Fetching album tracks from Spotify..." -ForegroundColor Yellow
    $tracks = Get-AlbumTracks -Id $AlbumId
    
    Write-Host "`n`n========================================" -ForegroundColor Cyan
    Write-Host "=== EXTRACTION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "Total tracks: $($tracks.Count)" -ForegroundColor Green
    
    if ($tracks.Count -gt 0) {
        # Count tracks with/without artists
        $withArtists = @($tracks | Where-Object { $_.artists -and $_.artists.Count -gt 0 })
        $withoutArtists = @($tracks | Where-Object { -not $_.artists -or $_.artists.Count -eq 0 })
        
        Write-Host "`nTracks WITH artists: $($withArtists.Count)" -ForegroundColor $(if ($withArtists.Count -gt 0) { 'Green' } else { 'Red' })
        Write-Host "Tracks WITHOUT artists: $($withoutArtists.Count)" -ForegroundColor $(if ($withoutArtists.Count -eq 0) { 'Green' } else { 'Red' })
        
        # Extract album metadata
        Write-Host "`n--- Album Metadata ---" -ForegroundColor Yellow
        $albumArtist = if ($album.artists -and $album.artists.Count -gt 0) { 
            ($album.artists | Select-Object -First 1).name
        } else { "Unknown Album Artist" }
        
        $year = if ($album.release_date -match '(\d{4})') { $matches[1] } else { "Unknown" }
        $genres = if ($album.genres -and $album.genres.Count -gt 0) { $album.genres -join ', ' } else { "Unknown" }
        $label = if ($album.label) { $album.label } else { "Unknown" }
        
        Write-Host "Album: $($album.name)" -ForegroundColor Cyan
        Write-Host "Album Artist: $albumArtist" -ForegroundColor Cyan
        Write-Host "Year: $year" -ForegroundColor Cyan
        Write-Host "Genre: $genres" -ForegroundColor Cyan
        Write-Host "Label: $label" -ForegroundColor Gray
        Write-Host "Total Tracks: $($album.total_tracks)" -ForegroundColor Gray
        Write-Host "Popularity: $($album.popularity)" -ForegroundColor Gray
        
        # Show first track details
        Write-Host "`n--- First Track Example ---" -ForegroundColor Yellow
        $first = $tracks[0]
        Write-Host "Track: $($first.track_number) - $($first.name)" -ForegroundColor Cyan
        Write-Host "  artists.Count: $($first.artists.Count)" -ForegroundColor Gray
        if ($first.artists -and $first.artists.Count -gt 0) {
            foreach ($a in $first.artists) {
                Write-Host "    - $($a.name)" -ForegroundColor Green
            }
        }
        $artistString = if ($first.artists) { ($first.artists | ForEach-Object { $_.name }) -join '; ' } else { 'Unknown Artist' }
        Write-Host "  Artist String: $artistString" -ForegroundColor Gray
        Write-Host "  Duration: $([math]::Round($first.duration_ms / 1000, 0))s" -ForegroundColor Gray
        Write-Host "  Disc: $($first.disc_number)" -ForegroundColor Gray
        
        # If there are tracks without artists, show them
        if ($withoutArtists.Count -gt 0) {
            Write-Host "`n--- Tracks Missing Artists ---" -ForegroundColor Red
            foreach ($track in $withoutArtists) {
                Write-Host "  Track $($track.track_number): $($track.name)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n✓ SUCCESS: All tracks have artists!" -ForegroundColor Green
        }
        
        # Show all tracks table
        Write-Host "`n--- All Tracks Overview ---" -ForegroundColor Yellow
        $tracks | Format-Table @{L='Disc';E={$_.disc_number}},
                                @{L='Track';E={$_.track_number}}, 
                                @{L='Title';E={$_.name.Substring(0, [Math]::Min(40, $_.name.Length))}}, 
                                @{L='Artists';E={if ($_.artists) { $_.artists.Count } else { 0 }}},
                                @{L='Artist String';E={
                                    if ($_.artists) { 
                                        $str = (($_.artists | ForEach-Object { $_.name }) -join '; ')
                                        $str.Substring(0, [Math]::Min(30, $str.Length))
                                    } else { '' }
                                }},
                                @{L='Duration';E={"{0:mm}:{0:ss}" -f ([TimeSpan]::FromMilliseconds($_.duration_ms))}} -AutoSize
        
    } else {
        Write-Host "`n✗ No tracks returned!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n✗ ERROR: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
