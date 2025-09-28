function Show-Tracks {
    param (
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [string]$AlbumName,
        [object]$SpotifyArtist
    )

    Clear-Host
    Write-Host "Tracks for album $($AlbumName):`n"

    for ($i = 0; $i -lt $SpotifyTracks.Count; $i++) {
        $num = $i + 1
        $spotify = $SpotifyTracks[$i]
        $audio = $AudioFiles[$i]

        Write-Host "[$num]"
        Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $spotify.DiscNumber, $spotify.TrackNumber, $spotify.Title)
        Write-Host ("`t`tartist: {0}" -f ($spotify.Artist -join ', '))
        #write the genres if presernt
        if ($SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
            Write-Host ("`t`tgenres: {0}" -f ($SpotifyArtist.genres -join ', '))
        }

        $match = (
            $spotify.DiscNumber -eq $audio.DiscNumber -and
            $spotify.TrackNumber -eq $audio.TrackNumber -and
            $spotify.Name -eq $audio.Name
        )

        $color = if ($match) { 'Green' } else { 'Yellow' }

        Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
        Write-Host ("`t`tartist: {0}" -f $audio.Artist) -ForegroundColor $color
        #write the genres if present
        if ($audio.TagFile.Tag.Genres -and $audio.TagFile.Tag.Genres.Count -gt 0) {
            Write-Host ("`t`tgenres: {0}" -f ($audio.TagFile.Tag.Genres -join ', '))
        }
        Write-Host "filename: $($audio.Name)"
    }
}