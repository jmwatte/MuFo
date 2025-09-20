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
        $searchResult = Search-Item -Type Artist -Query $ArtistName -ErrorAction Stop
        # Spotishell may return an array of result pages or a single object; normalize
        $resultItems = @()
        if ($null -ne $searchResult) {
            Write-Verbose ("Search-Item returned type: {0}; count: {1}" -f $searchResult.GetType().FullName, ($searchResult | Measure-Object).Count)
            if ($searchResult -is [System.Array]) {
                foreach ($page in $searchResult) {
                    Write-Verbose ("Page type: {0}" -f ($page.GetType().FullName))
                    if ($page.Artists -and $page.Artists.Items) { $resultItems += $page.Artists.Items }
                }
            } else {
                Write-Verbose ("Single result has properties: {0}" -f (($searchResult | Get-Member -MemberType NoteProperty,Property).Name -join ', '))
                if ($searchResult.Artists -and $searchResult.Artists.Items) { $resultItems = $searchResult.Artists.Items }
            }
    }
    Write-Verbose ("Artist items collected: {0}" -f ($resultItems | Measure-Object).Count)
    Write-Verbose "Found $((($resultItems | Measure-Object).Count)) artist results for '$ArtistName'"

        if ($resultItems -and $resultItems.Count -gt 0) {
            # Sort results by similarity score
            $scoredResults = $resultItems | ForEach-Object {
                $item = $_
                try {
                    if (-not $item.Name) { return }
                    $name = if ($item.Name -is [array]) { ($item.Name -join ' ') } else { [string]$item.Name }
                    $score = Get-StringSimilarity -String1 $ArtistName -String2 $name
                    [PSCustomObject]@{
                        Artist = $item
                        Score = $score
                    }
                } catch {
                    Write-Verbose ("Skipped item due to scoring error: {0}. Using fallback similarity." -f $_.Exception.Message)
                    try {
                        $n1 = ([string]$ArtistName).ToLowerInvariant().Trim()
                        if ($item.Name -is [array]) { $n2 = ($item.Name -join ' ') } else { $n2 = [string]$item.Name }
                        $n2 = $n2.ToLowerInvariant().Trim()
                        if ([string]::IsNullOrWhiteSpace($n1) -or [string]::IsNullOrWhiteSpace($n2)) { return }
                        if ($n1 -eq $n2) { $fallback = 1 }
                        else {
                            $l1 = $n1.Length; $l2 = $n2.Length
                            $max = [Math]::Max($l1, $l2); if ($max -eq 0) { return }
                            $fallback = ([Math]::Min($l1, $l2) / $max)
                        }
                        [PSCustomObject]@{
                            Artist = $item
                            Score  = [double]$fallback
                        }
                    } catch {
                        Write-Verbose ("Fallback similarity also failed: {0}" -f $_.Exception.Message)
                    }
                }
            } | Where-Object { $_ } | Sort-Object -Property Score -Descending

            # Return top matches above threshold
            $topMatches = $scoredResults | Where-Object { $_.Score -ge $MatchThreshold } | Select-Object -First 5
            if (-not $topMatches -or $topMatches.Count -eq 0) {
                Write-Verbose ("No matches >= threshold {0}. Falling back to top 5 by score." -f $MatchThreshold)
                $topMatches = $scoredResults | Select-Object -First 5
            }
            Write-Verbose ("Top matches: {0}" -f ($topMatches | Measure-Object).Count)
            foreach ($m in $topMatches) { Write-Verbose (" - {0} [{1}]" -f $m.Artist.Name, ([math]::Round($m.Score,2))) }
            return $topMatches
        } else {
            return $null
        }
    } catch {
        Write-Warning "Failed to search Spotify for artist '$ArtistName': $_"
        return $null
    }
}