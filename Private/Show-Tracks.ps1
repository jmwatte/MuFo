function Show-Tracks {
    param (
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [string]$AlbumName,
        [object]$SpotifyArtist
    )

    #Clear-Host
    Write-Host "Tracks for album $($AlbumName):`n"

    for ($i = 0; $i -lt $SpotifyTracks.Count; $i++) {
        $num = $i + 1
        $spotify = $SpotifyTracks[$i]
        $audio = $AudioFiles[$i]

        Write-Host "[$num]"
        Write-Host ("↓`t{0:D2}.{1:D2}: {2}" -f $spotify.disc_number, $spotify.track_number, $spotify.name)
        # Artist: support multiple shapes (string, array of strings, array of objects with .name)
        $artistDisplay = ''
        # if ($spotify -and $spotify.PSObject.Properties.Match('Artist')) {
        #     $a = $spotify.Artist
        #     if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { $artistDisplay = ($a -join ', ') } else { $artistDisplay = $a }
        # }
        if ($null -ne $spotify -and $spotify.PSObject.Properties['artists']) {
            $a = $spotify.artists
            if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', ' } else { $artistDisplay = $a }
        }
        Write-Host ("`t`tartist: {0}" -f $artistDisplay)

        # write genres if present on SpotifyArtist object (defensive)
        $providerGenres = ''
        if ($null -ne $SpotifyArtist -and $SpotifyArtist.PSObject.Properties['genres'] -and $SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
            $providerGenres = $SpotifyArtist.genres -join ', '
            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
        }
        elseif ( $null -ne $spotify -and $spotify.PSObject.Properties['genres'] -and $spotify.genres) {
            $providerGenres = $spotify.genres -join ', '
            Write-Host ("`t`tgenres: {0}" -f $providerGenres)
        }
        # if ($null -ne $spotify -and $spotify.artists -and $spotify.artists.Count -gt 0) {
        #     Write-Host ("`t`tartist: {0}" -f ($spotify.artists -join ', '))
        # }
        # write composer if present (handle single string or array)

        $providerComposer = ''        
        if ($null -ne $spotify -and $spotify.PSObject.Properties['composer'] -and $spotify.Composer) {
            $c = $spotify.Composer
            if ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) { $providerComposer = ($c -join ', ') } else { $providerComposer = $c }
            Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
        }
        
        $match = (
            $spotify.disc_number -eq $audio.DiscNumber -and
            $spotify.track_number -eq $audio.TrackNumber -and
            $spotify.name -eq $audio.Name
        )

        $color = if ($match) { 'Green' } else { 'Yellow' }

        # Prepare audio strings for comparison
        $audioArtist = $audio.TagFile.Tag.Performers -join ', '
        $audioGenres = if ($audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres -join ', ' } else { '' }
        $audioComposer = $audio.TagFile.Tag.Composers -join ', '

        # Determine colors for each field based on match
        $artistColor = if ($artistDisplay -eq $audioArtist) { 'Green' } else { 'Yellow' }
        $genresColor = if ($providerGenres -eq $audioGenres) { 'Green' } else { 'Yellow' }
        $composerColor = if ($providerComposer -eq $audioComposer) { 'Green' } else { 'Yellow' }


        Write-Host ("_`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
        Write-Host ("`t`tartist: {0}" -f ($audioArtist)) -ForegroundColor $artistColor
        #write the genres if present
        if ($audioGenres) {
            Write-Host ("`t`tgenres: {0}" -f ($audioGenres)) -ForegroundColor $genresColor
        }
        Write-Host ("`t`tcomposer: {0}" -f ($audioComposer)) -ForegroundColor $composerColor
        Write-Host "filename: $($audio.Name)"
    }
}