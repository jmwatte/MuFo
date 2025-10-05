function Get-DAlbumTracks {
    <#
    .SYNOPSIS
    Get tracks from a Discogs release.
    
    .DESCRIPTION
    Retrieves the track listing from a specific Discogs release ID.
    Transforms the data to match Spotify-like structure for compatibility.
    
    .PARAMETER Id
    The Discogs release ID (numeric).
    
    .EXAMPLE
    Get-DAlbumTracks -Id 249504
    Gets tracks for release ID 249504.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    try {
        Write-Verbose "Fetching Discogs release $Id..."
        
        # Get release details
        $release = Invoke-DiscogsRequest -Uri "/releases/$Id"
        
        if (-not $release) {
            Write-Warning "No release found for ID: $Id"
            return @()
        }
        
        # Extract tracks from tracklist
        $tracks = @()
        
        if ($release.tracklist) {
            foreach ($track in $release.tracklist) {
                # Parse position to extract disc and track numbers
                # Discogs positions can be: "A1", "B2", "1-1", "1", etc.
                $disc = 1
                $trackNum = 0
                
                if ($track.position -match '^([A-Z])(\d+)$') {
                    # Vinyl-style: A1, B2, etc. (A=1, B=2, C=3...)
                    $disc = [char]::ToUpper($matches[1]) - 64
                    $trackNum = [int]$matches[2]
                }
                elseif ($track.position -match '^(\d+)-(\d+)$') {
                    # Multi-disc CD format: 1-1, 2-3, etc.
                    $disc = [int]$matches[1]
                    $trackNum = [int]$matches[2]
                }
                elseif ($track.position -match '^\d+$') {
                    # Simple numbering: 1, 2, 3...
                    $disc = 1
                    $trackNum = [int]$track.position
                }
                else {
                    # Unknown format, try to parse as number or default
                    $disc = 1
                    if ($track.position -match '\d+') {
                        $trackNum = [int]$matches[0]
                    } else {
                        $trackNum = 0
                    }
                }
                
                # Parse duration from "MM:SS" format to milliseconds
                $durationMs = 0
                if ($track.duration -match '^(\d+):(\d+)$') {
                    $minutes = [int]$matches[1]
                    $seconds = [int]$matches[2]
                    $durationMs = ($minutes * 60 + $seconds) * 1000
                }
                
                # Determine track artist (use featured artists or fall back to album artist)
                $trackArtistName = if ($track.artists -and $track.artists.Count -gt 0) {
                    $track.artists[0].name
                } elseif ($release.artists -and $release.artists.Count -gt 0) {
                    $release.artists[0].name
                } else {
                    "Unknown Artist"
                }
                
                # Create track object matching Spotify structure
                $trackObj = [PSCustomObject]@{
                    id           = "$Id-$($track.position)"  # Synthetic ID (release-position)
                    name         = $track.title
                    title        = $track.title
                    disc_number  = $disc
                    track_number = $trackNum
                    duration_ms  = $durationMs
                    position     = $track.position  # Keep original Discogs position
                    artists      = @(
                        [PSCustomObject]@{
                            name = $trackArtistName
                        }
                    )
                }
                
                $tracks += $trackObj
            }
        }
        
        Write-Verbose "Found $($tracks.Count) tracks for release $Id"
        return $tracks
    }
    catch {
        Write-Warning "Failed to get Discogs release tracks: $_"
        return @()
    }
}
