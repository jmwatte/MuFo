function Get-SpotifyArtist {
<#
.SYNOPSIS
    Searches for an artist on Spotify using Spotishell.

.DESCRIPTION
    This function uses the Spotishell module to search for artists on Spotify.
    It returns the search results for further processing.

.PARAMETER ArtistName
    The name of the artist to search for.

.EXAMPLE
    Get-SpotifyArtist -ArtistName "The Beatles"
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ArtistName
    )

    try {
        # Use Spotishell to search for the artist
        $results = Search-SpotifyArtist -Query $ArtistName
        Write-Verbose "Found $($results.Count) artist results for '$ArtistName'"
        return $results
    } catch {
        Write-Warning "Failed to search Spotify for artist '$ArtistName': $_"
        return $null
    }
}