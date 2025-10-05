function Search-SAlbumsByName {
    <#
    .SYNOPSIS
        Search Spotify for albums by artist and album name.
    
    .DESCRIPTION
        Uses Spotishell's Search-Item to find albums matching both artist and album name.
        Returns targeted results instead of full artist discography.
    
    .PARAMETER ArtistName
        The artist name to search for.
    
    .PARAMETER AlbumName
        The album name to search for.
    
    .PARAMETER ArtistId
        Optional Spotify artist ID to filter results.
    
    .EXAMPLE
        Search-SAlbumsByName -ArtistName "Pink Floyd" -AlbumName "Dark Side of the Moon"
        Searches Spotify for albums matching "Pink Floyd Dark Side of the Moon".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistName,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter()]
        [string]$ArtistId
    )

    # Build search query: artist + album name
    $searchQuery = "artist:$ArtistName album:$AlbumName"
    
    Write-Verbose "Searching Spotify for: $searchQuery"

    try {
        $searchResults = Search-Item -Query $searchQuery -Type Album
    }
    catch {
        Write-Warning "Spotify album search failed: $_"
        return @()
    }

    if (-not $searchResults -or -not $searchResults.albums -or -not $searchResults.albums.items) {
        Write-Verbose "No albums found for: $searchQuery"
        return @()
    }

    $albums = $searchResults.albums.items

    # If ArtistId provided, filter by artist
    if ($ArtistId) {
        $albums = $albums | Where-Object {
            $albumArtists = $_.artists
            if ($albumArtists) {
                # Check if any of the album's artists match the provided ArtistId
                $matchFound = $false
                foreach ($artist in $albumArtists) {
                    if ($artist.id -eq $ArtistId) {
                        $matchFound = $true
                        break
                    }
                }
                $matchFound
            }
            else {
                $false
            }
        }
    }

    Write-Verbose "Found $($albums.Count) albums for: $searchQuery"
    
    return $albums
}
