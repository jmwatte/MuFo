function Invoke-ProviderSearchAlbums {
    <#
    .SYNOPSIS
        Provider abstraction for searching albums by name.
    
    .DESCRIPTION
        Routes album search requests to the appropriate provider-specific function.
        Searches for albums matching both artist and album name instead of returning
        full artist discography.
    
    .PARAMETER Provider
        The metadata provider to use (Spotify, Qobuz, or Discogs).
    
    .PARAMETER ArtistId
        Provider-specific artist identifier.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER MastersOnly
        (Discogs only) If specified, only return master releases.
    
    .PARAMETER FallbackToAllAlbums
        If specified and smart search returns no results, automatically fetch all albums for the artist.
        Requires ArtistId to be provided.
    
    .EXAMPLE
        Invoke-ProviderSearchAlbums -Provider Spotify -ArtistName "Pink Floyd" -AlbumName "Dark Side" -FallbackToAllAlbums
        Searches for matching albums, falls back to all albums if no matches found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter()]
        [string]$ArtistId,

        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [switch]$MastersOnly,  # Discogs-specific

        [Parameter()]
        [switch]$FallbackToAllAlbums
    )

    Write-Verbose "Searching $Provider for albums: Artist='$ArtistName', Album='$AlbumName'"

    $results = switch ($Provider) {
        'Spotify' {
            Search-SAlbumsByName -ArtistName $ArtistName -AlbumName $AlbumName -ArtistId $ArtistId
        }
        'Qobuz' {
            if (-not $ArtistId) {
                Write-Warning "Qobuz album search requires ArtistId (artist URL)"
                return @()
            }
            Search-QAlbumsByName -ArtistId $ArtistId -AlbumName $AlbumName -ArtistName $ArtistName
        }
        'Discogs' {
            $searchParams = @{
                ArtistName = $ArtistName
                AlbumName = $AlbumName
            }
            if ($ArtistId) {
                $searchParams.ArtistId = $ArtistId
            }
            if ($MastersOnly) {
                $searchParams.MastersOnly = $true
            }
            if ($AllAlbumsCache) {
                $searchParams.AllAlbumsCache = $AllAlbumsCache
            }
            Search-DAlbumsByName @searchParams
        }
    }

    # Fallback to all albums if smart search returned no results
    if ($FallbackToAllAlbums -and $results.Count -eq 0 -and $ArtistId) {
        Write-Verbose "Smart search returned no results, falling back to all albums for artist"
        
        $allAlbums = Invoke-ProviderGetAlbums -Provider $Provider -ArtistId $ArtistId
        
        # Filter all albums by album name similarity
        $results = $allAlbums | Where-Object {
            $album = $_
            $albumName = Get-IfExists $album 'title' ''
            if (-not $albumName) { return $false }
            
            # Use string similarity for matching
            $similarity = Get-StringSimilarity $AlbumName $albumName
            $similarity -gt 0.6  # 60% similarity threshold
        } | ForEach-Object {
            # Add similarity score for sorting
            $album = $_
            $albumName = Get-IfExists $album 'title' ''
            $similarity = Get-StringSimilarity $AlbumName $albumName
            $album | Add-Member -NotePropertyName 'SimilarityScore' -NotePropertyValue $similarity -PassThru -Force
        } | Sort-Object -Property SimilarityScore -Descending
        
        Write-Verbose "Fallback search found $($results.Count) matching albums"
    }

    return $results
}
