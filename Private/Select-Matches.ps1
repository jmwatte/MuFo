function Select-matches {
    #given the $audioFiles and $SpotifyTracks it should output the $audioFiles sorted in a manual way to match the spotifyTracks
    param(
        [array]$AudioFiles,
        [array]$SpotifyTracks
    )

    # creat an array to hold the manual matches
    $manualMatches = @()

    # Loop through each Spotify track and prompt for a matching audio file
    foreach ($spotifyTrack in $SpotifyTracks) {
        $matchingAudioFile = $null

        # Prompt the user to select a matching audio file
        while (-not $matchingAudioFile) {
            $audioFile = $AudioFiles | Out-GridView -Title "Select matching audio file for '$($spotifyTrack.Title)'" -PassThru

            if ($audioFile) {
                $manualMatches += $audioFile
                #collect the selected audio file and remove it from the list to avoid duplicate matches
                $AudioFiles = $AudioFiles | Where-Object { $_ -ne $audioFile }
                $matchingAudioFile = $audioFile
            }
        }
    }

    # Output the manual matches
    $manualMatches
}