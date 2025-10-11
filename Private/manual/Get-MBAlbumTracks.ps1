function Get-MBAlbumTracks {
    <#
    .SYNOPSIS
    Get tracks (recordings) from a MusicBrainz release.
    
    .DESCRIPTION
    Retrieves the track listing from a specific MusicBrainz release ID (MBID).
    Includes detailed artist credits and relationships (conductor, performer, etc.).
    Returns normalized track objects compatible with MuFo workflow.
    
    .PARAMETER Id
    MusicBrainz Release ID (MBID)
    
    .EXAMPLE
    Get-MBAlbumTracks -Id "f5e5f36f-4779-4c0b-9c6e-4b1b0c8c3c3c"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    try {
        Write-Verbose "Fetching MusicBrainz release: $Id"
        
        # Request release with media (tracks), artist credits, and genres/tags
        # Include release-groups to get album-level genre information
        $inc = 'recordings+artist-credits+media+release-groups+genres+tags'
        
        $release = Invoke-MusicBrainzRequest -Endpoint 'release' -Id $Id -Inc $inc
        
        if (-not $release) {
            Write-Warning "No release found for ID: $Id"
            return @()
        }
        
        # Extract genres from release-group (album-level genres)
        $albumGenres = @()
        
        # First try 'genres' property (newer MusicBrainz API)
        if ($release.PSObject.Properties['genres'] -and $release.genres) {
            $albumGenres = $release.genres | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                Select-Object -First 5 -ExpandProperty name
            Write-Verbose "Found $($albumGenres.Count) genres from release.genres"
        }
        
        # Fallback to 'tags' property (older API or when genres not available)
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['tags'] -and $release.tags) {
            $albumGenres = $release.tags | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                Sort-Object -Property count -Descending |
                Select-Object -First 5 -ExpandProperty name
            Write-Verbose "Found $($albumGenres.Count) tags from release.tags"
        }
        
        # Also try release-groups if present
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['release-group'] -and $release.'release-group') {
            $rg = $release.'release-group'
            if ($rg.PSObject.Properties['genres'] -and $rg.genres) {
                $albumGenres = $rg.genres | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                    Select-Object -First 5 -ExpandProperty name
                Write-Verbose "Found $($albumGenres.Count) genres from release-group.genres"
            } elseif ($rg.PSObject.Properties['tags'] -and $rg.tags) {
                $albumGenres = $rg.tags | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                    Sort-Object -Property count -Descending |
                    Select-Object -First 5 -ExpandProperty name
                Write-Verbose "Found $($albumGenres.Count) tags from release-group.tags"
            }
        }
        
        if ($albumGenres.Count -eq 0) {
            Write-Verbose "No genres/tags found for release $Id"
            $albumGenres = @('Unknown')
        } else {
            Write-Verbose "Using album genres: $($albumGenres -join ', ')"
        }
        
        # Extract tracks from media
        if (-not (Get-IfExists $release 'media') -or $release.media.Count -eq 0) {
            Write-Warning "Release $Id has no media/tracks"
            return @()
        }
        
        $allTracks = @()
        
        foreach ($medium in $release.media) {
            $discNumber = if (Get-IfExists $medium 'position') { $medium.position } else { 1 }
            $tracks = if (Get-IfExists $medium 'tracks') { $medium.tracks } else { @() }
            
            foreach ($track in $tracks) {
                $recording = if (Get-IfExists $track 'recording') { $track.recording } else { $null }
                
                if (-not $recording) {
                    Write-Verbose "Track missing recording data, skipping"
                    continue
                }
                
                # Extract artist credits
                $artists = @()
                if (Get-IfExists $recording 'artist-credit') {
                    foreach ($credit in $recording.'artist-credit') {
                        if (Get-IfExists $credit 'artist' -and (Get-IfExists $credit.artist 'name')) {
                            $artists += [PSCustomObject]@{
                                name = $credit.artist.name
                                id = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            }
                        }
                    }
                }
                
                # If no artists on recording, use release artist
                if ($artists.Count -eq 0 -and (Get-IfExists $release 'artist-credit')) {
                    foreach ($credit in $release.'artist-credit') {
                        if (Get-IfExists $credit 'artist' -and (Get-IfExists $credit.artist 'name')) {
                            $artists += [PSCustomObject]@{
                                name = $credit.artist.name
                                id = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            }
                        }
                    }
                }
                
                # Fallback to unknown artist
                if ($artists.Count -eq 0) {
                    $artists = @([PSCustomObject]@{ name = 'Unknown Artist'; id = $null })
                }
                
                # Extract duration (in milliseconds)
                $durationMs = 0
                if (Get-IfExists $recording 'length') {
                    $durationMs = [int]$recording.length
                } elseif (Get-IfExists $track 'length') {
                    $durationMs = [int]$track.length
                }
                
                # Track position/number
                $trackNumber = if (Get-IfExists $track 'position') { 
                    [int]$track.position 
                } else { 
                    $allTracks.Count + 1 
                }
                
                # Build track object
                $trackObj = [PSCustomObject]@{
                    id = $recording.id  # Recording MBID
                    name = $recording.title
                    title = $recording.title
                    disc_number = $discNumber
                    track_number = $trackNumber
                    duration_ms = $durationMs
                    artists = $artists
                    genres = $albumGenres  # Add album-level genres to track
                    _rawMusicBrainzObject = $recording
                }
                
                $allTracks += $trackObj
            }
        }
        
        Write-Verbose "Found $($allTracks.Count) tracks for release $Id"
        return $allTracks
    }
    catch {
        Write-Warning "Failed to get MusicBrainz release tracks: $_"
        return @()
    }
}
