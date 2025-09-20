function Get-SpotifyArtist {
<#
.SYNOPSIS
    Searches for an artist on Spotify and finds the best match.

.DESCRIPTION
    This function searches for artists on Spotify and uses fuzzy matching to find the best match based on the provided artist name.

.PARAMETER ArtistName
    The name of the artist to search for.

.PARAMETER MatchThreshold
    The minimum similarity score (0-1) for a match. Default is 0.8.

.EXAMPLE
    Get-SpotifyArtist -ArtistName "The Beatles" -MatchThreshold 0.9
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ArtistName,

        [Parameter(Mandatory = $false)]
        [double]$MatchThreshold = 0.8
    )

    try {
        # Use Spotishell to search for the artist
        $results = Search-SpotifyArtist -Query $ArtistName
        Write-Verbose "Found $($results.Count) artist results for '$ArtistName'"

        if ($results) {
            # Find the best match using fuzzy string comparison
            $bestMatch = $null
            $bestScore = 0

            foreach ($result in $results) {
                $score = Get-StringSimilarity -String1 $ArtistName -String2 $result.Name
                if ($score -gt $bestScore) {
                    $bestScore = $score
                    $bestMatch = $result
                }
            }

            if ($bestScore -ge $MatchThreshold) {
                Write-Verbose "Best match: $($bestMatch.Name) with score $bestScore"
                return $bestMatch
            } else {
                Write-Warning "No match found above threshold $MatchThreshold"
                return $null
            }
        } else {
            return $null
        }
    } catch {
        Write-Warning "Failed to search Spotify for artist '$ArtistName': $_"
        return $null
    }
}