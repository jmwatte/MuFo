function Set-Tracks {
    param (
        [string]$SortMethod,
        [array]$AudioFiles,
        [array]$SpotifyTracks
    )

    switch ($SortMethod) {
        "byName" {
            $AudioFiles = $AudioFiles | Sort-Object Title
            $SpotifyTracks = $SpotifyTracks | Sort-Object Title
        }
        "byTrackNumber" {
            $AudioFiles = $AudioFiles | Sort-Object DiscNumber, TrackNumber
            $SpotifyTracks = $SpotifyTracks | Sort-Object DiscNumber, TrackNumber
        }
        "byDuration" {
            $AudioFiles = $AudioFiles | Sort-Object Duration
            $SpotifyTracks = $SpotifyTracks | Sort-Object Duration
        }
        "manual" {
            #this should call a function that accepts $AudioFiles and $SpotifyTracks and lets the user manually match them
            #function Select-matches($AudioFiles, $SpotifyTracks) { ... }
            $AudioFiles = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks
            # no sorting
        }
    }

    return @{ Audio = $AudioFiles; Spotify = $SpotifyTracks }
}