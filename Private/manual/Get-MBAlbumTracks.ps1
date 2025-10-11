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
        # Include artist-rels to get detailed artist info with aliases (for Latin script names)
        # Include work-rels to get work links, and work-level-rels for composer
        # Note: Need BOTH work-rels (to get the work) AND work-level-rels (to get work's composer)
        $inc = 'recordings+artist-credits+media+release-groups+genres+tags+artist-rels+work-rels+work-level-rels'
        
        $release = Invoke-MusicBrainzRequest -Endpoint 'release' -Id $Id -Inc $inc
        
        if (-not $release) {
            Write-Warning "No release found for ID: $Id"
            return @()
        }
        
        # Extract genres from release-group (album-level genres)
        $albumGenres = @()
        
        # First try 'genres' property (newer MusicBrainz API)
        if ($release.PSObject.Properties['genres'] -and $release.genres) {
            $albumGenres = @($release.genres | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                Select-Object -First 5 -ExpandProperty name)
            if ($albumGenres.Count -gt 0) {
                Write-Verbose "Found $($albumGenres.Count) genres from release.genres"
            }
        }
        
        # Fallback to 'tags' property (older API or when genres not available)
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['tags'] -and $release.tags) {
            $albumGenres = @($release.tags | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                Sort-Object -Property count -Descending |
                Select-Object -First 5 -ExpandProperty name)
            if ($albumGenres.Count -gt 0) {
                Write-Verbose "Found $($albumGenres.Count) tags from release.tags"
            }
        }
        
        # Also try release-groups if present
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['release-group'] -and $release.'release-group') {
            $rg = $release.'release-group'
            if ($rg.PSObject.Properties['genres'] -and $rg.genres) {
                $albumGenres = @($rg.genres | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                    Select-Object -First 5 -ExpandProperty name)
                if ($albumGenres.Count -gt 0) {
                    Write-Verbose "Found $($albumGenres.Count) genres from release-group.genres"
                }
            } elseif ($rg.PSObject.Properties['tags'] -and $rg.tags) {
                $albumGenres = @($rg.tags | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                    Sort-Object -Property count -Descending |
                    Select-Object -First 5 -ExpandProperty name)
                if ($albumGenres.Count -gt 0) {
                    Write-Verbose "Found $($albumGenres.Count) tags from release-group.tags"
                }
            }
        }
        
        if ($albumGenres.Count -eq 0) {
            Write-Verbose "No genres/tags found for release $Id"
            $albumGenres = @('Unknown')
        } else {
            Write-Verbose "Using album genres: $($albumGenres -join ', ')"
        }
        
        # Extract tracks from media (ensure it's an array)
        $media = @()
        if (Get-IfExists $release 'media') {
            $media = @($release.media)
        }
        
        if ($media.Count -eq 0) {
            Write-Warning "Release $Id has no media/tracks"
            return @()
        }
        
        $allTracks = @()
        
        foreach ($medium in $media) {
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
                            $artistName = $credit.artist.name
                            $artistId = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            
                            # If name contains non-Latin characters (Cyrillic, etc.), try to get Latin alias
                            if ($artistId -and $artistName -match '[^\x00-\x7F]') {
                                Write-Verbose "Artist name '$artistName' contains non-Latin characters, fetching Latin alias..."
                                $latinName = Get-MBArtistLatinName -ArtistId $artistId -OriginalName $artistName
                                if ($latinName -and $latinName -ne $artistName) {
                                    Write-Verbose "Using Latin name: $latinName (original: $artistName)"
                                    $artistName = $latinName
                                }
                            }
                            
                            $artists += [PSCustomObject]@{
                                name = $artistName
                                id = $artistId
                            }
                        }
                    }
                }
                
                # If no artists on recording, use release artist
                if ($artists.Count -eq 0 -and (Get-IfExists $release 'artist-credit')) {
                    foreach ($credit in $release.'artist-credit') {
                        if (Get-IfExists $credit 'artist' -and (Get-IfExists $credit.artist 'name')) {
                            $artistName = $credit.artist.name
                            $artistId = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            
                            # If name contains non-Latin characters, try to get Latin alias
                            if ($artistId -and $artistName -match '[^\x00-\x7F]') {
                                Write-Verbose "Artist name '$artistName' contains non-Latin characters, fetching Latin alias..."
                                $latinName = Get-MBArtistLatinName -ArtistId $artistId -OriginalName $artistName
                                if ($latinName -and $latinName -ne $artistName) {
                                    Write-Verbose "Using Latin name: $latinName (original: $artistName)"
                                    $artistName = $latinName
                                }
                            }
                            
                            $artists += [PSCustomObject]@{
                                name = $artistName
                                id = $artistId
                            }
                        }
                    }
                }
                
                # Fallback to unknown artist
                if ($artists.Count -eq 0) {
                    $artists = @([PSCustomObject]@{ name = 'Unknown Artist'; id = $null })
                }
                
                # Extract composer from work relationships
                $composer = $null
                if ($recording.PSObject.Properties['relations'] -and $recording.relations) {
                    Write-Verbose "Recording has $($recording.relations.Count) relations"
                    
                    # Debug: Show all relation types
                    foreach ($rel in $recording.relations) {
                        $relType = if ($rel.PSObject.Properties['type']) { $rel.type } else { 'NO-TYPE' }
                        $relTarget = if ($rel.PSObject.Properties['work']) { 'work' } elseif ($rel.PSObject.Properties['artist']) { 'artist' } else { 'unknown' }
                        Write-Verbose "  Relation: type='$relType', target='$relTarget'"
                    }
                    
                    # Look for work relationships (try both 'performance' and direct work links)
                    $workRels = @($recording.relations | Where-Object { 
                        $_.PSObject.Properties['work'] -and $_.work
                    })
                    
                    Write-Verbose "Found $($workRels.Count) work relationships"
                    
                    if ($workRels.Count -gt 0) {
                        $work = $workRels[0].work
                        Write-Verbose "Work: $($work.title) (id: $($work.id))"
                        
                        # Look for composer in work's relations
                        if ($work.PSObject.Properties['relations'] -and $work.relations) {
                            Write-Verbose "Work has $($work.relations.Count) relations"
                            $composerRels = @($work.relations | Where-Object {
                                $_.PSObject.Properties['type'] -and $_.type -eq 'composer' -and
                                $_.PSObject.Properties['artist'] -and $_.artist -and
                                $_.artist.PSObject.Properties['name']
                            })
                            
                            Write-Verbose "Found $($composerRels.Count) composer relationships"
                            
                            if ($composerRels.Count -gt 0) {
                                $composerName = $composerRels[0].artist.name
                                $composerId = if ($composerRels[0].artist.PSObject.Properties['id']) { 
                                    $composerRels[0].artist.id 
                                } else { 
                                    $null 
                                }
                                
                                # Check for non-Latin composer name and get Latin alias
                                if ($composerId -and $composerName -match '[^\x00-\x7F]') {
                                    Write-Verbose "Composer name '$composerName' contains non-Latin characters, fetching Latin alias..."
                                    $latinComposer = Get-MBArtistLatinName -ArtistId $composerId -OriginalName $composerName
                                    if ($latinComposer -and $latinComposer -ne $composerName) {
                                        Write-Verbose "Using Latin composer name: $latinComposer (original: $composerName)"
                                        $composerName = $latinComposer
                                    }
                                }
                                
                                $composer = $composerName
                                Write-Verbose "Found composer: $composer"
                            }
                        } else {
                            Write-Verbose "Work has no relations property"
                        }
                    }
                } else {
                    Write-Verbose "Recording has no relations property"
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
                    composer = $composer  # Add composer from work relationships
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
