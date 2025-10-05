function Search-DAlbumsByName {
    <#
    .SYNOPSIS
        Search Discogs for albums by artist and album name.
    
    .DESCRIPTION
        Uses Discogs /database/search endpoint to find albums matching both artist and album name.
        Returns targeted results instead of full artist discography.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistId
        Optional Discogs artist ID to filter results.
    
    .PARAMETER MastersOnly
        If specified, only return master releases (canonical album versions).
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Handful of Keys"
        Searches Discogs for albums matching "Fats Waller Handful of Keys".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistId,

        [Parameter()]
        [switch]$MastersOnly
    )

    Write-Verbose "Searching Discogs for artist '$ArtistName' and album '$AlbumName'"

    # Discogs search is best done by getting all albums for artist and filtering locally
    # The search API tends to return artist matches rather than release matches
    # If we don't have an artist ID, this won't work well
    if (-not $ArtistId) {
        Write-Verbose "No ArtistId provided - searching by name (less accurate)"
        # Fallback: try a plain search and hope for the best
        $searchQuery = "$ArtistName $AlbumName"
        $searchParams = @{
            Uri = 'https://api.discogs.com/database/search'
            Body = @{
                q = $searchQuery
                per_page = 50
            }
        }
    } else {
        Write-Verbose "Using artist ID $ArtistId to fetch albums"
        # Better approach: get all albums for artist and filter locally
        try {
            $allAlbums = Get-DArtistAlbums -Id $ArtistId -MastersOnly:$MastersOnly
            # Case-insensitive filtering
            $filtered = $allAlbums | Where-Object { $_.name -match [regex]::Escape($AlbumName) -or $_.name -like "*$AlbumName*" }
            
            # If no matches with contains, try fuzzy matching with Jaccard similarity
            if ($filtered.Count -eq 0 -and (Get-Command Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue)) {
                Write-Verbose "No direct matches, trying fuzzy matching"
                $filtered = $allAlbums | ForEach-Object {
                    $similarity = Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.name
                    if ($similarity -gt 0.3) {
                        $_ | Add-Member -NotePropertyName '_similarity' -NotePropertyValue $similarity -Force
                        $_
                    }
                } | Sort-Object { -$_._similarity }
            }
            
            Write-Verbose "Found $($filtered.Count) matching albums out of $($allAlbums.Count) total"
            return $filtered
        } catch {
            Write-Warning "Failed to fetch artist albums: $_"
            return @()
        }
    }

    # Fallback search path (when no artist ID)
    $searchParams = @{
        Uri = 'https://api.discogs.com/database/search'
        Body = @{
            q = "$ArtistName $AlbumName"
            per_page = 50
        }
    }

    try {
        $searchResults = Invoke-DiscogsRequest @searchParams
    }
    catch {
        Write-Warning "Discogs album search failed: $_"
        return @()
    }

    if (-not $searchResults.results -or $searchResults.results.Count -eq 0) {
        Write-Verbose "No albums found for: $searchQuery"
        return @()
    }

    $albums = @()
    foreach ($result in $searchResults.results) {
        # Filter by type - only include releases (albums)
        if ($result.type -ne 'release' -and $result.type -ne 'master') {
            continue
        }

        # If MastersOnly, skip non-master releases
        if ($MastersOnly -and $result.type -ne 'master') {
            continue
        }

        # If ArtistId provided, filter by artist
        if ($ArtistId) {
            $matchesArtist = $false
            
            # Check if this release is by the specified artist
            # Discogs search results don't always include full artist info,
            # so we do a fuzzy match on the artist name in the title
            if ($result.PSObject.Properties['title'] -and $result.title -like "*$ArtistName*") {
                $matchesArtist = $true
            }
            
            if (-not $matchesArtist) {
                continue
            }
        }

        # Extract album name from title (format: "Artist - Album Name")
        $albumTitle = $result.title
        if ($albumTitle -match '^\s*(.+?)\s*-\s*(.+?)\s*$') {
            $albumTitle = $matches[2].Trim()
        }

        # Build album object in Spotify-compatible format
        $album = [PSCustomObject]@{
            id = $result.id
            name = $albumTitle
            release_date = if ($result.PSObject.Properties['year']) { $result.year } else { '' }
            type = $result.type
            format = if ($result.PSObject.Properties['format']) { $result.format -join ', ' } else { '' }
            label = if ($result.PSObject.Properties['label']) { $result.label -join ', ' } else { '' }
            country = if ($result.PSObject.Properties['country']) { $result.country } else { '' }
            thumb = if ($result.PSObject.Properties['thumb']) { $result.thumb } else { '' }
            _searchScore = if ($result.PSObject.Properties['community']) { 
                # Discogs provides community stats (have/want) which can indicate popularity
                $have = if ($result.community.PSObject.Properties['have']) { $result.community.have } else { 0 }
                $want = if ($result.community.PSObject.Properties['want']) { $result.community.want } else { 0 }
                $have + $want
            } else { 
                0 
            }
        }

        $albums += $album
    }

    # Sort by search score (popularity) descending
    $albums = $albums | Sort-Object { -$_._searchScore }

    Write-Verbose "Found $($albums.Count) albums for: $searchQuery"
    
    return $albums
}
