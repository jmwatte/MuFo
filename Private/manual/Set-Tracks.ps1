function Set-Tracks {
    param (
        [string]$SortMethod,
        [array]$AudioFiles,
        [array]$SpotifyTracks,
        [switch]$Reverse  # If set, iterate over audio files and match to Spotify tracks
    )

    #Write-Host "DEBUG Set-Tracks: Entered with SortMethod=$SortMethod, Reverse=$Reverse, AudioFiles count=$($AudioFiles.Count), SpotifyTracks count=$($SpotifyTracks.Count)"

    $pairedTracks = @()
    #Write-Host "DEBUG: Starting Set-Tracks with Reverse=$Reverse"
    switch ($SortMethod) {
        "byName" {
            if ($Reverse) {
                Write-Host "DEBUG: Using Reverse mode for byName"
                # Iterate over audio files, match to Spotify by filename similarity
                foreach ($audio in $AudioFiles) {
                    $filename = [System.IO.Path]::GetFileNameWithoutExtension($audio.FilePath)
                    $bestMatch = $null
                    $bestSimilarity = 0
                    foreach ($spotify in $SpotifyTracks) {
                        $similarity = Get-StringSimilarity-Jaccard -String1 $filename -String2 $spotify.name
                        if ($similarity -gt $bestSimilarity) {
                            $bestSimilarity = $similarity
                            $bestMatch = $spotify
                        }
                    }
                    $spotifyTrack = if ($bestSimilarity -ge 0.8) { $bestMatch } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original: Iterate over Spotify tracks
                $SpotifyTracks = $SpotifyTracks | Sort-Object name
                foreach ($spotify in $SpotifyTracks) {
                    $bestMatch = $null
                    $bestSimilarity = 0
                    foreach ($audio in $AudioFiles) {
                        $filename = [System.IO.Path]::GetFileNameWithoutExtension($audio.FilePath)
                        $similarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $filename
                        if ($similarity -gt $bestSimilarity) {
                            $bestSimilarity = $similarity
                            $bestMatch = $audio
                        }
                    }
                    $audioFile = if ($bestSimilarity -ge 0.8) { $bestMatch } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                    }
                }
            }
        }
        "byTitle" {
            if ($Reverse) {
                # Iterate over audio files, match to Spotify by title similarity
                foreach ($audio in $AudioFiles) {
                    $bestMatch = $null
                    $bestSimilarity = 0
                    foreach ($spotify in $SpotifyTracks) {
                        $similarity = Get-StringSimilarity-Jaccard -String1 $audio.Title -String2 $spotify.name
                        if ($similarity -gt $bestSimilarity) {
                            $bestSimilarity = $similarity
                            $bestMatch = $spotify
                        }
                    }
                    $spotifyTrack = if ($bestSimilarity -ge 0.8) { $bestMatch } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original: Iterate over Spotify tracks
                $SpotifyTracks = $SpotifyTracks | Sort-Object name
                foreach ($spotify in $SpotifyTracks) {
                    $bestMatch = $null
                    $bestSimilarity = 0
                    foreach ($audio in $AudioFiles) {
                        $similarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                        if ($similarity -gt $bestSimilarity) {
                            $bestSimilarity = $similarity
                            $bestMatch = $audio
                        }
                    }
                    $audioFile = if ($bestSimilarity -ge 0.8) { $bestMatch } else { $null }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                    }
                }
            }
        }
        "byTrackNumber" {
            if ($Reverse) {
                Write-Host "DEBUG: Using Reverse mode for byTrackNumber"
                # Iterate over audio files, match to Spotify by disc/track
                foreach ($audio in $AudioFiles) {
                    $spotifyTrack = $SpotifyTracks | Where-Object { 
                        $_.disc_number -eq $audio.DiscNumber -and $_.track_number -eq $audio.TrackNumber 
                    } | Select-Object -First 1
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                Write-Host "DEBUG: Using Normal mode for byTrackNumber"
                # Original: Iterate over Spotify tracks
                $SpotifyTracks = $SpotifyTracks | Sort-Object disc_number, track_number
                foreach ($spotify in $SpotifyTracks) {
                    $audioFile = $AudioFiles | Where-Object { 
                        $_.DiscNumber -eq $spotify.disc_number -and $_.TrackNumber -eq $spotify.track_number 
                    } | Select-Object -First 1
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                    }
                }
            }
        }
        "byDuration" {
            if ($Reverse) {
                # Iterate over audio files, match to Spotify by duration
                foreach ($audio in $AudioFiles) {
                    $spotifyTrack = $null
                    $minDiff = [double]::MaxValue
                    foreach ($spotify in $SpotifyTracks) {
                        $diff = [Math]::Abs($audio.Duration - $spotify.duration_ms)
                        $tolerance = $audio.Duration * 0.1  # 10% tolerance
                        if ($diff -le $tolerance -and $diff -lt $minDiff) {
                            $minDiff = $diff
                            $spotifyTrack = $spotify
                        }
                    }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotifyTrack
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original: Iterate over Spotify tracks
                $SpotifyTracks = $SpotifyTracks | Sort-Object duration_ms
                foreach ($spotify in $SpotifyTracks) {
                    $audioFile = $null
                    $minDiff = [double]::MaxValue
                    foreach ($audio in $AudioFiles) {
                        $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                        $tolerance = $spotify.duration_ms * 0.1  # 10% tolerance
                        if ($diff -le $tolerance -and $diff -lt $minDiff) {
                            $minDiff = $diff
                            $audioFile = $audio
                        }
                    }
                    
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $audioFile
                    }
                }
            }
        }
        "hybrid" {
            if ($Reverse) {
                # Hybrid: Iterate over audio files, score against Spotify tracks
                $discTrackWeight = 50
                $titleWeight = 30
                $durationWeight = 20
                
                $matchesR = @()
                foreach ($audio in $AudioFiles) {
                    foreach ($spotify in $SpotifyTracks) {
                        $score = 0
                        
                        # Disc/Track match
                        if ($spotify.disc_number -eq $audio.DiscNumber -and $spotify.track_number -eq $audio.TrackNumber) {
                            $score += $discTrackWeight
                        }
                        
                        # Title similarity
                        $similarity = Get-StringSimilarity-Jaccard -String1 $audio.Title -String2 $spotify.name
                        $score += $similarity * $titleWeight
                        
                        # Duration closeness
                        $diff = [Math]::Abs($audio.Duration - $spotify.duration_ms)
                        $tolerance = $audio.Duration * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        $score += $durationScore * $durationWeight
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
                
                # Greedy assignment
                $matchesR = $matchesR | Sort-Object Score -Descending
                $usedSpotify = @{}
                foreach ($match in $matchesR) {
                    if (-not $usedSpotify.ContainsKey($match.Spotify.id) -and $match.Score -ge 20) {
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $match.Spotify
                            AudioFile    = $match.Audio
                        }
                        $usedSpotify[$match.Spotify.id] = $true
                    }
                }
                
                # Add unpaired audio files
                $pairedAudio = $pairedTracks | ForEach-Object { $_.AudioFile }
                $unpairedAudio = $AudioFiles | Where-Object { $_ -notin $pairedAudio }
                foreach ($audio in $unpairedAudio) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $null
                        AudioFile    = $audio
                    }
                }
            }
            else {
                # Original hybrid logic
                $discTrackWeight = 50
                $titleWeight = 30
                $durationWeight = 20
                
                $matchesR = @()
                foreach ($spotify in $SpotifyTracks) {
                    foreach ($audio in $AudioFiles) {
                        $score = 0
                        
                        if ($audio.DiscNumber -eq $spotify.disc_number -and $audio.TrackNumber -eq $spotify.track_number) {
                            $score += $discTrackWeight
                        }
                        
                        $similarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                        $score += $similarity * $titleWeight
                        
                        $diff = [Math]::Abs($spotify.duration_ms - $audio.Duration)
                        $tolerance = $spotify.duration_ms * 0.1
                        $durationScore = if ($diff -le $tolerance) { 1 - ($diff / $tolerance) } else { 0 }
                        $score += $durationScore * $durationWeight
                        
                        $matchesR += [PSCustomObject]@{
                            Spotify = $spotify
                            Audio   = $audio
                            Score   = $score
                        }
                    }
                }
                
                $matchesR = $matchesR | Sort-Object Score -Descending
                $usedAudio = @{}
                foreach ($match in $matchesR) {
                    if (-not $usedAudio.ContainsKey($match.Audio.FilePath) -and $match.Score -ge 20) {
                        $pairedTracks += [PSCustomObject]@{
                            SpotifyTrack = $match.Spotify
                            AudioFile    = $match.Audio
                        }
                        $usedAudio[$match.Audio.FilePath] = $true
                    }
                }
                
                $pairedSpotify = $pairedTracks | ForEach-Object { $_.SpotifyTrack }
                $unpairedSpotify = $SpotifyTracks | Where-Object { $_ -notin $pairedSpotify }
                foreach ($spotify in $unpairedSpotify) {
                    $pairedTracks += [PSCustomObject]@{
                        SpotifyTrack = $spotify
                        AudioFile    = $null
                    }
                }
            }
        }
        "manual" {
            # Manual remains the same (interactive)
            $pairedTracks = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks
        }
    }

    return $pairedTracks
}