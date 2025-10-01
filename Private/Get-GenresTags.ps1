function get-GenresTags($ProviderArtist, $ProviderAlbum) {
    $artistGenres = @()
    if ($ProviderArtist -and $ProviderArtist.genres.Count -gt 0) {
        try {
            if ($ProviderArtist -is [System.Collections.IDictionary]) { $artistGenres = $ProviderArtist['genres'] }
            elseif ($ProviderArtist.PSObject.Properties.Match('genres')) { $artistGenres = $ProviderArtist.genres }
        }
        catch { $artistGenres = @() }
    }
    elseif ($null -ne $ProviderAlbum -and $null -ne $ProviderAlbum.genre) {
        try {
            if ($ProviderAlbum -is [System.Collections.IDictionary]) { $artistGenres = $ProviderAlbum['genre'] }
            elseif ($ProviderAlbum.PSObject.Properties.Match('genre')) { $artistGenres = $ProviderAlbum.genre }
        }
        catch { $artistGenres = @() }
    }
    return $artistGenres
}