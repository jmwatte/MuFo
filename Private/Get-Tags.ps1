 
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

    # Extract track title (handle both Spotify 'name' and Qobuz 'title' properties)
    $trackTitle = if ($value = Get-IfExists $SpotifyTrack 'name') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'title') { $value } else { 'Unknown Title' }
    
    # Extract track number (handle both formats)
    $trackNumber = if ($value = Get-IfExists $SpotifyTrack 'track_number') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'TrackNumber') { $value } else { 0 }
    
    # Extract disc number (handle both formats)
    $discNumber = if ($value = Get-IfExists $SpotifyTrack 'disc_number') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'DiscNumber') { $value } else { 1 }

    # Extract and format performers (artists) - handle multiple provider formats
    $artistT = 'Unknown Artist'
    if ($value = Get-IfExists $SpotifyTrack 'artists') {
        if ($value -is [array]) {
            $artistT = ($value | ForEach-Object { if ($_.name) { $_.name } else { $_.ToString() } }) -join '; '
        } elseif ($value.name) {
            $artistT = $value.name
        } else {
            $artistT = $value.ToString()
        }
    } elseif ($value = Get-IfExists $SpotifyTrack 'performer') {
        $artistT = if ($value -is [array]) { $value -join '; ' } else { $value }
    } elseif ($value = Get-IfExists $SpotifyTrack 'Artist') {
        $artistT = if ($value -is [array]) { $value -join '; ' } else { $value }
    }

    # Build the tags hashtable
    $tags = @{
        Title       = $trackTitle
        Track       = "{0:D2}" -f $trackNumber
        Disc        = "{0:D2}" -f $discNumber
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

    # Add Conductor if present (Qobuz classical music)
    if ($value = Get-IfExists $SpotifyTrack 'Conductor') {
        $tags.Conductor = $value
    }

    # Add Comment field with full production credits (Qobuz)
    if ($value = Get-IfExists $SpotifyTrack 'Comment') {
        $tags.Comment = $value
    }

    # Return the tags hashtable
    return $tags
}
