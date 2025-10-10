function Get-ClassicalAlbumArtist {
    <#
    .SYNOPSIS
        Intelligently determines album artist for classical music releases.
    
    .DESCRIPTION
        For classical music, the "album artist" should typically be the performers
        (conductor, orchestra, ensemble) rather than the composer. This function
        analyzes track data to extract the primary performers.
    
    .PARAMETER Tracks
        Array of track objects with artist/conductor information.
    
    .PARAMETER FallbackArtist
        Default artist to use if no performers are found.
    
    .EXAMPLE
        $albumArtist = Get-ClassicalAlbumArtist -Tracks $tracks -FallbackArtist "Ludwig van Beethoven"
    
    .NOTES
        For Discogs tracks, looks for:
        - Conductor property
        - Artists array excluding composers
        For Spotify/Qobuz tracks, uses first non-composer artist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Tracks,
        
        [Parameter(Mandatory = $false)]
        [string]$FallbackArtist
    )

    if (-not $Tracks -or $Tracks.Count -eq 0) {
        Write-Verbose "No tracks provided, using fallback artist: $FallbackArtist"
        return $FallbackArtist
    }

    # Strategy: Find the most common conductor + orchestra/ensemble combination
    # across all tracks, as they're typically consistent for classical albums

    $conductors = @{}
    $ensembles = @{}
    
    foreach ($track in $Tracks) {
        # Extract conductor if available (Discogs provides this)
        if ($track.PSObject.Properties['Conductor'] -and $track.Conductor) {
            $conductor = $track.Conductor
            if ($conductors.ContainsKey($conductor)) {
                $conductors[$conductor]++
            } else {
                $conductors[$conductor] = 1
            }
        }
        
        # Extract ensemble/orchestra from artists array
        # Look for artists with roles like "orchestra", "ensemble", "choir"
        if ($track.PSObject.Properties['artists'] -and $track.artists) {
            foreach ($artist in $track.artists) {
                $name = $artist.name
                if (-not $name) { continue }
                
                # Skip if this looks like a composer (check against common composer indicators)
                # Composers are typically single person names without ensemble/orchestra indicators
                if ($name -match '(?i)(orchestra|ensemble|philharmonic|symphony|choir|chorus|quartet|trio)') {
                    if ($ensembles.ContainsKey($name)) {
                        $ensembles[$name]++
                    } else {
                        $ensembles[$name] = 1
                    }
                }
            }
        }
    }

    # Build album artist from most common conductor + ensemble
    $parts = @()
    
    if ($conductors.Count -gt 0) {
        $topConductor = ($conductors.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Key
        $parts += $topConductor
        Write-Verbose "Found conductor: $topConductor"
    }
    
    if ($ensembles.Count -gt 0) {
        $topEnsemble = ($ensembles.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Key
        $parts += $topEnsemble
        Write-Verbose "Found ensemble: $topEnsemble"
    }

    if ($parts.Count -gt 0) {
        $result = $parts -join ', '
        Write-Verbose "Classical album artist determined: $result"
        return $result
    }

    # Fallback: Use first artist from first track if available
    if ($Tracks[0].PSObject.Properties['artists'] -and $Tracks[0].artists -and $Tracks[0].artists.Count -gt 0) {
        $result = $Tracks[0].artists[0].name
        Write-Verbose "Using first track artist as fallback: $result"
        return $result
    }

    Write-Verbose "No performers found, using fallback artist: $FallbackArtist"
    return $FallbackArtist
}
