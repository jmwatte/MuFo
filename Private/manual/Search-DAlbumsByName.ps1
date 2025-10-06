function Search-DAlbumsByName {
    <#
    .SYNOPSIS
        Search Discogs for albums by artist and album name.
    
    .DESCRIPTION
        Uses Discogs /database/search API with title and artist parameters to find matching albums.
        Falls back to cache-based filtering if API search fails or cache is provided.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistId
        Discogs artist ID (optional, used for cache-based fallback).
    
    .PARAMETER MastersOnly
        If specified, only return master releases (canonical album versions).
    
    .PARAMETER AllAlbumsCache
        Optional: Pre-fetched list of all albums. If provided, skips API search and filters locally.
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Complete Recorded Works"
        Searches Discogs API for albums matching the title.
    
    .EXAMPLE
        Search-DAlbumsByName -ArtistName "Fats Waller" -AlbumName "Keys" -AllAlbumsCache $cached
        Filters pre-cached albums locally (no API call).
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
        [switch]$MastersOnly,

        [Parameter()]
        [array]$AllAlbumsCache
    )

    Write-Verbose "Searching Discogs for artist '$ArtistName' albums matching '$AlbumName'"

    # If cache provided, use cache-based filtering (fast, no API calls)
    if ($AllAlbumsCache) {
        Write-Verbose "Using cached album list ($($AllAlbumsCache.Count) albums)"
        $allAlbums = $AllAlbumsCache
        
        # Filter albums by name using case-insensitive matching
        $filtered = @($allAlbums | Where-Object { 
            $_.name -like "*$AlbumName*" 
        })

        # If no direct matches, try fuzzy matching with Jaccard similarity
        if ($filtered.Count -eq 0 -and (Get-Command Get-StringSimilarity-Jaccard -ErrorAction SilentlyContinue)) {
            Write-Verbose "No direct matches, trying fuzzy matching with Jaccard similarity"
            $filtered = @($allAlbums | ForEach-Object {
                $similarity = Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.name
                if ($similarity -gt 0.3) {
                    $_ | Add-Member -NotePropertyName '_similarity' -NotePropertyValue $similarity -Force -PassThru
                }
            } | Sort-Object { -$_._similarity })
        }

        Write-Verbose "Found $($filtered.Count) matching albums from cache"
        return $filtered
    }

    # No cache - use Discogs API search
    Write-Verbose "Searching Discogs API with title='$AlbumName' and artist='$ArtistName'"
    
    try {
        $searchParams = @{
            artist = $ArtistName
            title = $AlbumName
        }
        
        # Add type filter if MastersOnly requested
        if ($MastersOnly) {
            $searchParams['type'] = 'master'
        } else {
            $searchParams['type'] = 'release'
        }
        
        $searchResult = Invoke-DiscogsRequest -Uri 'https://api.discogs.com/database/search' -Body $searchParams
        
        if (-not $searchResult.results -or $searchResult.results.Count -eq 0) {
            Write-Verbose "No albums found via API search"
            return @()
        }
        
        Write-Verbose "Found $($searchResult.results.Count) albums via API search"
        
        # Convert Discogs search results to album objects (Spotify-compatible format)
        $albums = @()
        foreach ($result in $searchResult.results) {
            # Extract album name from title (format: "Artist - Album Name")
            $albumTitle = $result.title
            if ($albumTitle -match '^\s*(.+?)\s*[-–]\s*(.+?)\s*$') {
                $albumTitle = $matches[2].Trim()
            }
            
            $album = [PSCustomObject]@{
                id = $result.id
                name = $albumTitle
                release_date = if ($result.PSObject.Properties['year']) { $result.year } else { '' }
                type = $result.type
                format = if ($result.PSObject.Properties['format']) { $result.format -join ', ' } else { '' }
                label = if ($result.PSObject.Properties['label']) { $result.label -join ', ' } else { '' }
                country = if ($result.PSObject.Properties['country']) { $result.country } else { '' }
                thumb = if ($result.PSObject.Properties['thumb']) { $result.thumb } else { '' }
                artist = if ($result.PSObject.Properties['user_data']) { 
                    # Extract artist from title
                    if ($result.title -match '^\s*(.+?)\s*[-–]\s*') { $matches[1].Trim() } else { $ArtistName }
                } else { 
                    $ArtistName 
                }
                resource_url = if ($result.PSObject.Properties['resource_url']) { $result.resource_url } else { '' }
            }
            
            $albums += $album
        }
        
        return $albums
        
    } catch {
        Write-Warning "Discogs API search failed: $_"
        
        # Fallback to fetching all albums if ArtistId provided
        if ($ArtistId) {
            Write-Verbose "Falling back to fetching all albums for artist ID: $ArtistId"
            try {
                $allAlbums = Get-DArtistAlbums -Id $ArtistId -MastersOnly:$MastersOnly
                $allAlbums = @($allAlbums)
                
                $filtered = @($allAlbums | Where-Object { $_.name -like "*$AlbumName*" })
                Write-Verbose "Found $($filtered.Count) albums via fallback method"
                return $filtered
            } catch {
                Write-Warning "Fallback album fetch failed: $_"
                return @()
            }
        }
        
        return @()
    }
}
