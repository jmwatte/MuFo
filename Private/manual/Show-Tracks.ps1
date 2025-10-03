function Show-Tracks {
    param (
        [array]$PairedTracks,
        [string]$AlbumName,
        [PSCustomObject]$SpotifyArtist,
        #add a parameter reverse so we can flip certain things
        [switch]$Reverse
    )

    $pageSize = 10  # Number of tracks per page; adjust as needed
    $page = 0
    $totalPages = [math]::Ceiling($PairedTracks.Count / $pageSize)

    while ($true) {
        Clear-Host
        Write-Host "Tracks for album $($AlbumName): (Page $($page + 1) of $totalPages)`n"

        $start = $page * $pageSize
        $end = [math]::Min($start + $pageSize - 1, $PairedTracks.Count - 1)

        for ($i = $start; $i -le $end; $i++) {
            $pair = $PairedTracks[$i]
            $num = $i + 1

            $spotify = $pair.SpotifyTrack
            $audio = $pair.AudioFile

            Write-Host "[$num]"

            if ($spotify) {
                $disc = if ($value = Get-IfExists $spotify 'disc_number') { $value } else { 1 }
                $track = if ($value = Get-IfExists  $spotify  'track_number') { $value } else { 0 }
                Write-Host ("↓`t{0:D2}.{1:D2}: {2}" -f $disc, $track, $spotify.name)

                # Artist display
                $a = $spotify.artists
                if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) {
                    $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', '
                }
                else {
                    $artistDisplay = $a
                }
                Write-Host ("`t`tartist: {0}" -f $artistDisplay)

                # Genres from SpotifyArtist (if available)
                if ($value = Get-IfExists  $SpotifyArtist  'genres') {
                    $providerGenres = $value -join ', '
                    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                }
                elseif ($value = Get-IfExists  $spotify  'genres') {
                    $providerGenres = $value -join ', '
                    Write-Host ("`t`tgenres: {0}" -f $providerGenres)
                }

                # Composer (if available)
                if ($value = Get-IfExists  $spotify 'composer') {
                    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                        $providerComposer = $value -join ', '
                    }
                    else {
                        $providerComposer = $value
                    }
                    Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
                }
                # if ($spotify.PSObject.Properties.Match('composer') -and $spotify.composer) {
                #     $providerComposer = $spotify.composer -join ', '
                #     Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
                # }
            }
            else {
                Write-Host "↓ No Spotify track data available"
            }

            if ($audio) {
                $s=if($Reverse){'↑'}else{'_'}
                $color = if ($spotify -and $audio.Title -eq $spotify.name) { 'Green' } else { 'Yellow' }
                Write-Host ("$($s)`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color

                $audioArtist = if ($value = Get-IfExists  $audio  'Artist') { $value } else { 'Unknown' }
                $artistColor = if ($spotify -and $audioArtist -eq $artistDisplay) { 'Green' } else { 'Yellow' }
                Write-Host ("`t`tartist: {0}" -f $audioArtist) -ForegroundColor $artistColor
                $audioGenres = if ($value = Get-IfExists  $audio.TagFile.tag  'Genres') { $value -join ', ' } else { 'Unknown' }
                $genresColor = if ($value = Get-IfExists $SpotifyArtist 'genres' -and ($audioGenres -eq ($value -join ', '))) { 'Green' } else { 'Yellow' }
                Write-Host ("`t`tgenres: {0}" -f $audioGenres) -ForegroundColor $genresColor

                $audioComposer = if ($value = Get-IfExists  $audio  'Composer' -and $value) { $value -join ', ' } else { 'Unknown' }
                $composerColor = if ($value = Get-IfExists  $spotify 'Composer' -and ($audioComposer -eq ($value -join ', '))) { 'Green' } else { 'Yellow' }
                #$composerColor = if ($spotify -and $spotify.composer -and ($audioComposer -eq ($spotify.composer -join ', '))) { 'Green' } else { 'Yellow' }
                Write-Host ("`t`tcomposer: {0}" -f $audioComposer) -ForegroundColor $composerColor

                Write-Host "filename: $($audio.Name)"
            }
            else {
                Write-Host "_ No matching audio file" -ForegroundColor Red
            }

            Write-Host ""  # Add spacing between tracks
        }

        Write-Host "`nPage $($page + 1) of $totalPages (Tracks $($start + 1) to $($end + 1) of $($PairedTracks.Count))"
        $inputH = Read-Host "Press Enter for next page, 'p' for previous, 'q' to quit viewing"

        switch ($inputH) {
            'q' { return }
            'p' { if ($page -gt 0) { $page-- } }
            '' { 
                $page++
                if ($page -ge $totalPages) { $page = $totalPages - 1 }
            }
            'n' {
                $page++
                if ($page -ge $totalPages) { $page = $totalPages - 1 }
            }
            default {
                Write-Host "Unrecognized input: '$inputH'. Please press Enter, 'p', or 'q'."
                Start-Sleep -Seconds 1
            }
        }

        #if ($page * $pageSize -ge $($PairedTracks.Count)) { $page-- }  # Don't go beyond last page
    }
}



# function Show-Tracks {
#     param (
#         [array]$PairedTracks,
#         [string]$AlbumName,
#         [object]$SpotifyArtist
#     )

#     #Clear-Host
#     Write-Host "Tracks for album $($AlbumName):`n"

#     for ($i = 0; $i -lt $PairedTracks.Count; $i++) {
#         $num = $i + 1
#         $pair = $PairedTracks[$i]
#         $spotify = $pair.SpotifyTrack
#         $audio = $pair.AudioFile

#         Write-Host "[$num]"

#         # Display Spotify track info
#         if ($null -ne $spotify) {
#             Write-Host ("↓`t{0:D2}.{1:D2}: {2}" -f $spotify.disc_number, $spotify.track_number, $spotify.name)
            
#             # Artist: support multiple shapes (string, array of strings, array of objects with .name)
#             $artistDisplay = ''
#             if ($spotify.PSObject.Properties['artists']) {
#                 $a = $spotify.artists
#                 if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) { 
#                     $artistDisplay = ($a | ForEach-Object { if ($_.PSObject.Properties.Match('name')) { $_.name } else { $_ } }) -join ', ' 
#                 } else { 
#                     $artistDisplay = $a 
#                 }
#             }
#             Write-Host ("`t`tartist: {0}" -f $artistDisplay)

#             # Write genres if present on SpotifyArtist object (defensive)
#             $providerGenres = ''
#             if ($null -ne $SpotifyArtist -and $SpotifyArtist.PSObject.Properties['genres'] -and $SpotifyArtist.genres -and $SpotifyArtist.genres.Count -gt 0) {
#                 $providerGenres = $SpotifyArtist.genres -join ', '
#                 Write-Host ("`t`tgenres: {0}" -f $providerGenres)
#             }
#             elseif ($spotify.PSObject.Properties['genres'] -and $spotify.genres) {
#                 $providerGenres = $spotify.genres -join ', '
#                 Write-Host ("`t`tgenres: {0}" -f $providerGenres)
#             }

#             # Write composer if present (handle single string or array)
#             $providerComposer = ''        
#             if ($spotify.PSObject.Properties['composer'] -and $spotify.Composer) {
#                 $c = $spotify.Composer
#                 if ($c -is [System.Collections.IEnumerable] -and -not ($c -is [string])) { 
#                     $providerComposer = ($c -join ', ') 
#                 } else { 
#                     $providerComposer = $c 
#                 }
#                 Write-Host ("`t`tcomposer: {0}" -f $providerComposer)
#             }
#         } else {
#             Write-Host "↓ No Spotify track data available"
#         }

#         # Display AudioFile info
#         if ($null -ne $audio) {
#             $match = $false
#             if ($null -ne $spotify) {
#                 $match = (
#                     $spotify.disc_number -eq $audio.DiscNumber -and
#                     $spotify.track_number -eq $audio.TrackNumber -and
#                     $spotify.name -eq $audio.Name
#                 )
#             }

#             $color = if ($match) { 'Green' } else { 'Yellow' }

#             # Prepare audio strings for comparison
#             $audioArtist = $audio.TagFile.Tag.Performers -join ', '
#             $audioGenres = if ($audio.TagFile.Tag.Genres) { $audio.TagFile.Tag.Genres -join ', ' } else { '' }
#             $audioComposer = $audio.TagFile.Tag.Composers -join ', '

#             # Determine colors for each field based on match (only if Spotify data exists)
#             if ($null -ne $spotify) {
#                 $artistColor = if ($artistDisplay -eq $audioArtist) { 'Green' } else { 'Yellow' }
#                 $genresColor = if ($providerGenres -eq $audioGenres) { 'Green' } else { 'Yellow' }
#                 $composerColor = if ($providerComposer -eq $audioComposer) { 'Green' } else { 'Yellow' }
#             } else {
#                 $artistColor = 'Gray'
#                 $genresColor = 'Gray'
#                 $composerColor = 'Gray'
#             }

#             Write-Host ("_`t{0:D2}.{1:D2}: {2}" -f $audio.DiscNumber, $audio.TrackNumber, $audio.Title) -ForegroundColor $color
#             Write-Host ("`t`tartist: {0}" -f ($audioArtist)) -ForegroundColor $artistColor
#             # Write the genres if present
#             if ($audioGenres) {
#                 Write-Host ("`t`tgenres: {0}" -f ($audioGenres)) -ForegroundColor $genresColor
#             }
#             Write-Host ("`t`tcomposer: {0}" -f ($audioComposer)) -ForegroundColor $composerColor
#             Write-Host "filename: $($audio.Name)"
#         } else {
#             Write-Host "_ No matching audio file" -ForegroundColor Red
#         }

#         Write-Host ""  # Add spacing between tracks
#     }
# }








<# function Show-Tracks {
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
} #>