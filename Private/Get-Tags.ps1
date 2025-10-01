 
function Get-Tags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Artist,

        [Parameter(Mandatory = $true)]
        [object]$Album,

        [Parameter(Mandatory = $true)]
        [object]$SpotifyTrack
    )

    # Get genres from the available Get-GenresTags function
    $genreT = Get-GenresTags -ProviderArtist $Artist -ProviderAlbum $Album
    $year = $Album.release_date
    if ($year -match '^(?<year>\d{4})') { $Year = $matches.year } else { $Year = 0000 }
    # Extract album artist value
    $albumArtistValue = if ($value = Get-IfExists $Artist 'name') { $value } else { $Artist }

    # Extract and format performers (artists)
    $artistT = $SpotifyTrack.artists.name -join '; '

    # Build the tags hashtable
    $tags = @{
        Title       = $SpotifyTrack.name
        Track       = "{0:D2}" -f $SpotifyTrack.track_number
        Disc        = "{0:D2}" -f $SpotifyTrack.disc_number
        Performers  = $artistT
        Genres      = $genreT
        AlbumArtist = $albumArtistValue
        Date        = $Year
        Album       = $Album.name
    }

    # Conditionally add composers if present in the Spotify track
    if ($value = Get-IfExists $SpotifyTrack  'composer') {
        $tags.Composers = $value -join '; '
    }

    # Return the tags hashtable
    return $tags
}
