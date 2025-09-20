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
        $results = Get-SpotifyArtist -Query $ArtistName
        Write-Verbose "Found $($results.Count) artist results for '$ArtistName'"

        if ($results) {
            # Sort results by similarity score
            $scoredResults = $results | ForEach-Object {
                $score = Get-StringSimilarity -String1 $ArtistName -String2 $_.Name
                [PSCustomObject]@{
                    Artist = $_
                    Score = $score
                }
            } | Sort-Object -Property Score -Descending

            # Return top matches above threshold
            $topMatches = $scoredResults | Where-Object { $_.Score -ge $MatchThreshold } | Select-Object -First 5
            Write-Verbose "Top matches: $($topMatches.Count)"
            return $topMatches
        } else {
            return $null
        }
    } catch {
        Write-Warning "Failed to search Spotify for artist '$ArtistName': $_"
        return $null
    }
}