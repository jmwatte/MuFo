function Search-MBArtist {
    <#
    .SYNOPSIS
    Search for artists in MusicBrainz database.
    
    .DESCRIPTION
    Searches MusicBrainz for artists matching the query string.
    Returns normalized artist objects compatible with MuFo workflow.
    
    .PARAMETER Query
    Artist name or search query
    
    .PARAMETER Limit
    Maximum number of results to return (default: 25)
    
    .EXAMPLE
    Search-MBArtist -Query "Henryk Górecki"
    
    .EXAMPLE
    Search-MBArtist -Query "London Symphony Orchestra" -Limit 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [int]$Limit = 25
    )

    try {
        Write-Verbose "Searching MusicBrainz for artist: $Query"
        
        # Build MusicBrainz query using Lucene syntax
        # Escape special characters and build query
        $searchQuery = "artist:$Query"
        
        $queryParams = @{
            query = $searchQuery
            limit = $Limit
        }
        
        $response = Invoke-MusicBrainzRequest -Endpoint 'artist' -Query $queryParams
        
        if (-not $response -or -not (Get-IfExists $response 'artists')) {
            Write-Verbose "No artists found for query: $Query"
            return @()
        }
        
        $artists = $response.artists
        Write-Verbose "Found $($artists.Count) artists"
        
        # Normalize to Spotify-like structure
        $normalizedArtists = foreach ($artist in $artists) {
            # Extract genres/tags (MusicBrainz uses 'tags')
            $genres = @()
            if (Get-IfExists $artist 'tags') {
                $genres = $artist.tags | 
                    Where-Object { $_ -and (Get-IfExists $_ 'name') } | 
                    Select-Object -First 5 -ExpandProperty name
            }
            
            # Get artist type (Person, Group, Orchestra, Choir, etc.)
            $artistType = if (Get-IfExists $artist 'type') { $artist.type } else { 'Unknown' }
            
            # Build disambiguation if available
            $disambiguation = if (Get-IfExists $artist 'disambiguation') { 
                " ($($artist.disambiguation))" 
            } else { 
                "" 
            }
            
            [PSCustomObject]@{
                id = $artist.id  # MBID
                name = $artist.name + $disambiguation
                type = $artistType
                genres = $genres
                score = if (Get-IfExists $artist 'score') { $artist.score } else { 0 }
                country = if (Get-IfExists $artist 'country') { $artist.country } else { $null }
                _rawMusicBrainzObject = $artist
            }
        }
        
        # Sort by score (MusicBrainz provides relevance score)
        return $normalizedArtists | Sort-Object -Property score -Descending
    }
    catch {
        Write-Warning "MusicBrainz artist search failed: $_"
        return @()
    }
}
