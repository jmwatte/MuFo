# Direct test of Discogs artist extraction - no loops, no Clear-Host
# Usage: .\test-discogs-artist-extraction.ps1 -ReleaseId "12345" (release)
#    or: .\test-discogs-artist-extraction.ps1 -ReleaseId "m12345" (master release)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseId
)

Write-Host "`n=== Direct Discogs Artist Extraction Test ===" -ForegroundColor Cyan

# Strip square brackets if present (copied from Discogs site: [r2388472] or [m1764178])
$ReleaseId = $ReleaseId -replace '^\[|\]$', ''

# Strip 'r' prefix if present (Discogs format: r2388472)
$ReleaseId = $ReleaseId -replace '^r', ''

# Determine if this is a master release (m prefix) or regular release
$isMaster = $ReleaseId -match '^m(\d+)$'
if ($isMaster) {
    $numericId = $matches[1]
    Write-Host "Type: Master Release" -ForegroundColor Yellow
    Write-Host "Master ID: m$numericId`n" -ForegroundColor Gray
} else {
    Write-Host "Type: Release" -ForegroundColor Yellow
    Write-Host "Release ID: $ReleaseId`n" -ForegroundColor Gray
}

# Directly call the private function by dot-sourcing it
$scriptRoot = $PSScriptRoot
. "$scriptRoot\Private\manual\Invoke-DiscogsRequest.ps1"
. "$scriptRoot\Private\manual\Get-DAlbumTracks.ps1"
. "$scriptRoot\Private\Get-IfExists.ps1"

try {
    if ($isMaster) {
        Write-Host "Fetching master release details from Discogs..." -ForegroundColor Yellow
        $master = Invoke-DiscogsRequest -Uri "/masters/$numericId"
        
        Write-Host "Master: $($master.title) by $($master.artists[0].name)" -ForegroundColor Cyan
        Write-Host "Main Release ID: $($master.main_release)" -ForegroundColor Gray
        Write-Host "`nFetching main release details..." -ForegroundColor Yellow
        
        $release = Invoke-DiscogsRequest -Uri "/releases/$($master.main_release)"
        $actualReleaseId = $master.main_release
    } else {
        Write-Host "Fetching release details from Discogs..." -ForegroundColor Yellow
        $release = Invoke-DiscogsRequest -Uri "/releases/$ReleaseId"
        $actualReleaseId = $ReleaseId
    }
    
    Write-Host "Fetching release tracks from Discogs..." -ForegroundColor Yellow
    $tracks = Get-DAlbumTracks -Id $actualReleaseId -Verbose
    
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
        
        # Extract album metadata from release
        Write-Host "`n--- Album Metadata ---" -ForegroundColor Yellow
        $albumArtist = if ($release.artists -and $release.artists.Count -gt 0) { 
            ($release.artists | Select-Object -First 1).name
        } else { "Unknown Album Artist" }
        
        $year = if ($release.year) { $release.year } else { "Unknown" }
        $genres = if ($release.genres -and $release.genres.Count -gt 0) { $release.genres -join ', ' } else { "Unknown" }
        $styles = if ($release.styles -and $release.styles.Count -gt 0) { $release.styles -join ', ' } else { "Unknown" }
        $label = if ($release.labels -and $release.labels.Count -gt 0) { $release.labels[0].name } else { "Unknown" }
        $country = if ($release.country) { $release.country } else { "Unknown" }
        $format = if ($release.formats -and $release.formats.Count -gt 0) { 
            $release.formats[0].name + " (" + ($release.formats[0].descriptions -join ', ') + ")"
        } else { "Unknown" }
        
        Write-Host "Album: $($release.title)" -ForegroundColor Cyan
        Write-Host "Album Artist: $albumArtist" -ForegroundColor Cyan
        Write-Host "Year: $year" -ForegroundColor Cyan
        Write-Host "Genre: $genres" -ForegroundColor Cyan
        Write-Host "Style: $styles" -ForegroundColor Gray
        Write-Host "Label: $label" -ForegroundColor Gray
        Write-Host "Country: $country" -ForegroundColor Gray
        Write-Host "Format: $format" -ForegroundColor Gray
        Write-Host "Discogs ID: $($release.id)" -ForegroundColor Gray
        
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
        Write-Host "  Duration: $($first.duration_ms)ms" -ForegroundColor Gray
        Write-Host "  Position: $($first.position)" -ForegroundColor Gray
        
        # If there are tracks without artists, show them
        if ($withoutArtists.Count -gt 0) {
            Write-Host "`n--- Tracks Missing Artists ---" -ForegroundColor Red
            foreach ($track in $withoutArtists) {
                Write-Host "  Track $($track.track_number): $($track.name)" -ForegroundColor Yellow
            }
            
            Write-Host "`n=== DIAGNOSIS ===" -ForegroundColor Cyan
            Write-Host "Discogs tracks may inherit album artist if no track-specific artist is listed." -ForegroundColor Yellow
            Write-Host "This is common for tracks where the performer is the same as the album artist." -ForegroundColor Gray
        } else {
            Write-Host "`n✓ SUCCESS: All tracks have artists!" -ForegroundColor Green
        }
        
        # Show all tracks table
        Write-Host "`n--- All Tracks Overview ---" -ForegroundColor Yellow
        $tracks | Format-Table @{L='Pos';E={$_.position}},
                                @{L='Track';E={$_.track_number}}, 
                                @{L='Title';E={$_.name.Substring(0, [Math]::Min(40, $_.name.Length))}}, 
                                @{L='Artists';E={if ($_.artists) { $_.artists.Count } else { 0 }}},
                                @{L='Artist String';E={
                                    if ($_.artists) { 
                                        $str = (($_.artists | ForEach-Object { $_.name }) -join '; ')
                                        $str.Substring(0, [Math]::Min(30, $str.Length))
                                    } else { '' }
                                }},
                                @{L='Duration';E={$_.duration}} -AutoSize
        
    } else {
        Write-Host "`n✗ No tracks returned!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n✗ ERROR: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
