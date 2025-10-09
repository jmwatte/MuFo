function Get-SpotifyArtist-Enhanced {
<#
.SYNOPSIS
    Enhanced Spotify artist search that tries multiple variations of the artist name.

.DESCRIPTION
    This function searches for artists on Spotify using multiple search strategies:
    1. Exact artist name
    2. Artist name before common separators (and, &, featuring, feat, with)
    3. Artist name after common separators
    4. Cleaned versions removing special characters

.PARAMETER ArtistName
    The name of the artist to search for.

.PARAMETER MatchThreshold
    The minimum similarity score (0-1) for a match. Default is 0.7 (lower for enhanced search).

.EXAMPLE
    Get-SpotifyArtist-Enhanced -ArtistName "Afrika Bambaataa and the Soul Sonic Force"
    # Will try: "Afrika Bambaataa and the Soul Sonic Force", "Afrika Bambaataa", "the Soul Sonic Force"
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ArtistName,

        [Parameter(Mandatory = $false)]
        [double]$MatchThreshold = 0.7
    )

    # Define common separators that indicate multiple artists or groups
    $separators = @(
        ' and ',
        ' & ',
        ' featuring ',
        ' feat ',
        ' feat. ',
        ' ft ',
        ' ft. ',
        ' with ',
        ' vs ',
        ' vs. ',
        ' versus '
    )

    # Generate search variations
    $searchVariations = @()
    
    # 1. Original name
    $searchVariations += $ArtistName.Trim()
    
    # 2. Try parts before and after separators
    foreach ($sep in $separators) {
        if ($ArtistName -match [regex]::Escape($sep)) {
            $parts = $ArtistName -split [regex]::Escape($sep), 2
            if ($parts.Count -eq 2) {
                $before = $parts[0].Trim()
                $after = $parts[1].Trim()
                
                # Add the part before the separator (usually the main artist)
                if ($before -and $before.Length -gt 2) {
                    $searchVariations += $before
                }
                
                # Add the part after the separator (might be another artist)
                if ($after -and $after.Length -gt 2) {
                    $searchVariations += $after
                }
            }
            break # Only split on the first separator found
        }
    }
    
    # 3. Clean version (remove special characters, extra spaces)
    $cleaned = $ArtistName -replace '[^\w\s]', ' ' -replace '\s+', ' '
    if ($cleaned -ne $ArtistName -and $cleaned.Trim()) {
        $searchVariations += $cleaned.Trim()
    }
    
    # Remove duplicates and empty strings
    $searchVariations = $searchVariations | Where-Object { $_ -and $_.Trim() } | Select-Object -Unique
    
    Write-Verbose "Enhanced search for '$ArtistName' will try $($searchVariations.Count) variations:"
    foreach ($variation in $searchVariations) {
        Write-Verbose "  - '$variation'"
    }
    
    $allResults = @()
    $foundIds = @()
    
    # Try each variation and collect unique results
    foreach ($searchTerm in $searchVariations) {
        Write-Verbose "Trying search variation: '$searchTerm'"
        
        try {
            $results = Get-SpotifyArtist -ArtistName $searchTerm -MatchThreshold 0.1 # Lower threshold for collecting candidates
            
            if ($results -and $results.Count -gt 0) {
                foreach ($result in $results) {
                    $artistId = if ($result.Artist -and $result.Artist.Id) { $result.Artist.Id } else { $null }
                    
                    # Only add if we haven't seen this artist ID yet
                    if ($artistId -and $artistId -notin $foundIds) {
                        $foundIds += $artistId
                        
                        # Recalculate score against original artist name
                        $artistName = if ($result.Artist -and $result.Artist.Name) { $result.Artist.Name } else { "Unknown" }
                        $originalScore = Get-StringSimilarity -String1 $ArtistName -String2 $artistName
                        
                        $allResults += [PSCustomObject]@{
                            Artist = $result.Artist
                            Score = $originalScore
                            SearchVariation = $searchTerm
                        }
                        
                        Write-Verbose "  Found: '$artistName' (Score: $([math]::Round($originalScore, 2)), ID: $artistId)"
                    }
                }
            }
        } catch {
            Write-Verbose "Search variation '$searchTerm' failed: $_"
        }
    }
    
    if ($allResults.Count -gt 0) {
        # Sort by score and return top matches
        $sortedResults = $allResults | Sort-Object -Property Score -Descending
        
        # Apply the threshold and return top 5
        $finalResults = $sortedResults | Where-Object { $_.Score -ge $MatchThreshold } | Select-Object -First 5
        
        if ($finalResults.Count -eq 0 -and $sortedResults.Count -gt 0) {
            # If no results meet threshold, return the best result anyway
            $finalResults = $sortedResults | Select-Object -First 1
            Write-Verbose "No results met threshold $MatchThreshold, returning best match with score $($finalResults[0].Score)"
        }
        
        Write-Verbose "Enhanced search returning $($finalResults.Count) results"
        return $finalResults
    } else {
        Write-Verbose "Enhanced search found no results for '$ArtistName'"
        return $null
    }
}