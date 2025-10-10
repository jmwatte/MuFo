# Direct test of Qobuz artist extraction - no loops, no Clear-Host
# Usage: .\test-qobuz-artist-extraction.ps1 -AlbumUrl "/be-fr/album/album-name/id"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AlbumUrl
)

Write-Host "`n=== Direct Qobuz Artist Extraction Test ===" -ForegroundColor Cyan
Write-Host "Album URL: $AlbumUrl`n" -ForegroundColor Gray

# Directly call the private function by dot-sourcing it
$scriptRoot = $PSScriptRoot
. "$scriptRoot\Private\manual\Get-QAlbumTracks.ps1"
. "$scriptRoot\Private\manual\Invoke-DiscogsRequest.ps1"
. "$scriptRoot\Private\Get-IfExists.ps1"
. "$scriptRoot\Private\Get-Tags.ps1"
. "$scriptRoot\Private\Get-GenresTags.ps1"

# Load required dependencies
if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
    Write-Host "Installing PowerHTML module..." -ForegroundColor Yellow
    Install-Module PowerHTML -Scope CurrentUser -Force
}
Import-Module PowerHTML -ErrorAction Stop

try {
    Write-Host "Fetching album tracks from Qobuz..." -ForegroundColor Yellow
    Write-Host "(Watch for === TRACK XX DEBUG === sections)`n" -ForegroundColor Gray
    
    $tracks = Get-QAlbumTracks -Id $AlbumUrl -Verbose
    
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
        
        # Extract album metadata from first track (JSON-LD data is stored in each track)
        Write-Host "`n--- Album Metadata ---" -ForegroundColor Yellow
        $first = $tracks[0]
        
        # Get album name from JSON-LD (stored in track object)
        $albumName = if ($first.PSObject.Properties['album_name'] -and $first.album_name) { 
            $first.album_name 
        } elseif ($first.PSObject.Properties['name']) { 
            $first.name 
        } else { 
            "Unknown Album" 
        }
        
        # Get album artist from JSON-LD brand field (stored in track object)
        $albumArtist = if ($first.PSObject.Properties['album_artist'] -and $first.album_artist) {
            $first.album_artist
        } elseif ($first.artists -and $first.artists.Count -gt 0) { 
            ($first.artists | Where-Object { $_.type -eq 'album_artist' -or $_.type -eq 'main' } | Select-Object -First 1).name
        } else { 
            "Unknown Album Artist" 
        }
        if (-not $albumArtist -and $first.artists -and $first.artists.Count -gt 0) {
            $albumArtist = $first.artists[0].name
        }
        
        # Get release date and year from first track
        $releaseDate = if ($first.PSObject.Properties['release_date']) { $first.release_date } else { "Unknown" }
        $year = if ($releaseDate -match '(\d{4})') { $matches[1] } else { "Unknown" }
        
        # Get genres from first track
        $genres = if ($first.genres -and $first.genres.Count -gt 0) { 
            $first.genres -join ', ' 
        } else { "Unknown" }
        
        # Get label and quality
        $label = if ($first.label) { $first.label } else { "Unknown" }
        $quality = if ($first.quality) { $first.quality } else { "Unknown" }
        
        Write-Host "Album: $albumName" -ForegroundColor Cyan
        Write-Host "Album Artist (from API): $albumArtist" -ForegroundColor Cyan
        Write-Host "Release Date: $releaseDate" -ForegroundColor Cyan
        Write-Host "Year: $year" -ForegroundColor Cyan
        Write-Host "Genre: $genres" -ForegroundColor Cyan
        Write-Host "Label: $label" -ForegroundColor Gray
        Write-Host "Quality: $quality" -ForegroundColor Gray
        
        # Compute what album artist would be when tagging (shows classical music enhancement)
        try {
            $artist = [PSCustomObject]@{ name = $albumArtist; genres = @() }
            $albumObj = [PSCustomObject]@{ 
                name = $albumName
                genre = $genres
                genres = if ($first.genres) { $first.genres } else { @() }
                release_date = $releaseDate
            }
            $tags = Get-Tags -Artist $artist -Album $albumObj -SpotifyTrack $first -Verbose
            
            $computedColor = if ($tags.AlbumArtist -ne $albumArtist) { 'Green' } else { 'Cyan' }
            Write-Host "Album Artist (computed for tagging): $($tags.AlbumArtist)" -ForegroundColor $computedColor
            if ($tags.AlbumArtist -ne $albumArtist) {
                Write-Host "  ℹ️  Classical music detected - using performers instead of composer" -ForegroundColor Yellow
            }
        } catch {
            Write-Verbose "Could not compute album artist: $_"
        }
        
        # Show first track details
        Write-Host "`n--- First Track Example ---" -ForegroundColor Yellow
        Write-Host "Track: $($first.track_number) - $($first.Title)" -ForegroundColor Cyan
        Write-Host "  artists.Count: $($first.artists.Count)" -ForegroundColor Gray
        if ($first.artists -and $first.artists.Count -gt 0) {
            foreach ($a in $first.artists) {
                Write-Host "    - $($a.name) (type: $($a.type))" -ForegroundColor Green
            }
        }
        Write-Host "  Artist: $($first.Artist)" -ForegroundColor Gray
        Write-Host "  Composer: $($first.composer)" -ForegroundColor Gray
        Write-Host "  Conductor: $($first.Conductor)" -ForegroundColor Gray
        Write-Host "  Ensemble: $($first.Ensemble)" -ForegroundColor Gray
        Write-Host "  Comment: $($first.Comment)" -ForegroundColor Gray
        
        # If there are tracks without artists, show them
        if ($withoutArtists.Count -gt 0) {
            Write-Host "`n--- Tracks Missing Artists ---" -ForegroundColor Red
            foreach ($track in $withoutArtists) {
                Write-Host "  Track $($track.track_number): $($track.Title)" -ForegroundColor Yellow
            }
            
            Write-Host "`n=== DIAGNOSIS ===" -ForegroundColor Cyan
            Write-Host "Review the === TRACK XX DEBUG === sections above for these tracks:" -ForegroundColor Yellow
            Write-Host "  1. Check 'Raw performerInfo' - is it empty?" -ForegroundColor Gray
            Write-Host "  2. Check 'Parsed results' - did it extract anything?" -ForegroundColor Gray
            Write-Host "  3. Check if GTM fallback was attempted" -ForegroundColor Gray
            Write-Host "  4. If all empty, the HTML structure may have changed`n" -ForegroundColor Gray
        } else {
            Write-Host "`n✓ SUCCESS: All tracks have artists!" -ForegroundColor Green
        }
        
        # Show all tracks table
        Write-Host "`n--- All Tracks Overview ---" -ForegroundColor Yellow
        $tracks | Format-Table @{L='Track';E={$_.track_number}}, 
                                @{L='Title';E={$_.Title.Substring(0, [Math]::Min(40, $_.Title.Length))}}, 
                                @{L='Artists';E={if ($_.artists) { $_.artists.Count } else { 0 }}},
                                @{L='Artist String';E={$_.Artist.Substring(0, [Math]::Min(30, $_.Artist.Length))}} -AutoSize
        
    } else {
        Write-Host "`n✗ No tracks returned!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n✗ ERROR: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
