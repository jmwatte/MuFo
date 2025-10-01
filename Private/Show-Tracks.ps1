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
        if ($null -ne$spotify -and $spotify.PSObject.Properties['artists']) {
            $a = $spotify.artists
            if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', ' } else { $artistDisplay = $a }
        }
        Write-Host ("`t`tartist: {0}" -f $artistDisplay)

        # write genres if present on SpotifyArtist object (defensive)
        if ($null -ne $SpotifyArtist -and $SpotifyArtist.PSObject.Properties['genres'] -and $SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
            Write-Host ("`t`tgenres: {0}" -f ($SpotifyArtist.genres -join ', '))
        }
        if ( $null -ne $spotify -and $spotify.PSObject.Properties['genres'] -and $spotify.genres) {
            Write-Host ("`t`tgenres: {0}" -f ($spotify.genres -join ', '))
        }
        # if ($null -ne $spotify -and $spotify.artists -and $spotify.artists.Count -gt 0) {
        #     Write-Host ("`t`tartist: {0}" -f ($spotify.artists -join ', '))
        # }
        # write composer if present (handle single string or array)
        if ($null -ne $spotify -and $spotify.PSObject.Properties['composer'] -and $spotify.Composer) {
            $composerDisplay = ''
            $c = $spotify.Composer
            if ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) { $composerDisplay = ($c -join ', ') } else { $composerDisplay = $c }
            Write-Host ("`t`tcomposer: {0}" -f $composerDisplay)
        }
        
        $match = (
            $spotify.disc_number -eq $audio.DiscNumber -and
            $spotify.track_number -eq $audio.TrackNumber -and
            $spotify.name -eq $audio.Name
        )

        $color = if ($match) { 'Green' } else { 'Yellow' }

        Write-Host ("_`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
        Write-Host ("`t`tartist: {0}" -f ($audio.TagFile.Tag.Performers -join ', ')) -ForegroundColor $color
        #write the genres if present
        if ($audio.TagFile.Tag.Genres -and $audio.TagFile.Tag.Genres.Count -gt 0) {
            Write-Host ("`t`tgenres: {0}" -f ($audio.TagFile.Tag.Genres -join ', '))
        }
        Write-Host ("`t`tcomposer: {0}" -f ($audio.TagFile.Tag.Composers -join ', ')) -ForegroundColor $color
        Write-Host "filename: $($audio.Name)"
    }
}