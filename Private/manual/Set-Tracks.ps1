
function Set-Tracks {
    param (
        [string]$SortMethod,
        [array]$AudioFiles,
        [array]$SpotifyTracks
    )

    $pairedTracks = @()

    switch ($SortMethod) {
        "byName" {
            # Sort Spotify tracks by name
            $SpotifyTracks = $SpotifyTracks | Sort-Object name
            
            foreach ($spotify in $SpotifyTracks) {
                # Find best matching audio file by title similarity
                $bestMatch = $null
                $bestSimilarity = 0
                foreach ($audio in $AudioFiles) {
                    $similarity = Get-StringSimilarity-Jaccard -String1 $spotify.name -String2 $audio.Title
                    if ($similarity -gt $bestSimilarity) {
                        $bestSimilarity = $similarity
                        $bestMatch = $audio
                    }
                }
                # Only pair if similarity is high enough (adjust threshold as needed)
                $audioFile = if ($bestSimilarity -ge 0.8) { $bestMatch } else { $null }
                
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $spotify
                    AudioFile    = $audioFile
                }
            }
        }
        "byTrackNumber" {
            # Sort Spotify tracks by disc and track number
            $SpotifyTracks = $SpotifyTracks | Sort-Object disc_number, track_number
            
            foreach ($spotify in $SpotifyTracks) {
                # Find exact match by disc and track number
                $audioFile = $AudioFiles | Where-Object { 
                    $_.DiscNumber -eq $spotify.disc_number -and $_.TrackNumber -eq $spotify.track_number 
                } | Select-Object -First 1
                
                $pairedTracks += [PSCustomObject]@{
                    SpotifyTrack = $spotify
                    AudioFile    = $audioFile
                }
            }
        }
        "byDuration" {
            # Sort Spotify tracks by duration
            $SpotifyTracks = $SpotifyTracks | Sort-Object duration_ms
            
            foreach ($spotify in $SpotifyTracks) {
                # Find closest duration match (within 10% tolerance)
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
        "manual" {
            # Use Select-matches for interactive pairing
            $pairedTracks = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks
        }
    }

    return $pairedTracks
}







<# function Set-Tracks {
    param (
        [string]$SortMethod,
        [array]$AudioFiles,
        [array]$SpotifyTracks
    )

    switch ($SortMethod) {
        "byName" {
            $AudioFiles = $AudioFiles | Sort-Object Title
            $SpotifyTracks = $SpotifyTracks | Sort-Object name

        }
        "byTrackNumber" {
            $AudioFiles = $AudioFiles | Sort-Object DiscNumber, TrackNumber
            $SpotifyTracks = $SpotifyTracks | Sort-Object disc_number, track_number
        }
        "byDuration" {
            $AudioFiles = $AudioFiles | Sort-Object Duration
            $SpotifyTracks = $SpotifyTracks | Sort-Object duration_ms
        }
        "manual" {
            #this should call a function that accepts $AudioFiles and $SpotifyTracks and lets the user manually match them
            #function Select-matches($AudioFiles, $SpotifyTracks) { ... }
            $AudioFiles = Select-matches -AudioFiles $AudioFiles -SpotifyTracks $SpotifyTracks
            # no sorting
        }
    }

    return @{ Audio = $AudioFiles; Spotify = $SpotifyTracks }
} #>