function Get-SpotifyAlbumMatches-Fast {
<#
.SYNOPSIS
    Fast and efficient Spotify album search with multiple query strategies.
    Optimized to avoid downloading entire artist discographies.

.PARAMETER Query
    The base search query string to send to Spotify.

.PARAMETER AlbumName
    The album name to search for. Used for scoring similarity.

.PARAMETER ArtistName
    The artist name for additional search variations.

.PARAMETER Year
    Optional year for year-specific matching.

.PARAMETER Top
    Number of top matches to return (default 5).

.PARAMETER MinScore
    Minimum similarity score to consider (default 0.6).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][string]$AlbumName,
        [string]$ArtistName,
        [string]$Year,
        [int]$Top = 5,
        [double]$MinScore = 0.6
    )

    Write-Verbose "Fast search for: '$AlbumName' by '$ArtistName'"
    
    # Multiple search strategies, ordered by likelihood of success
    $searchQueries = @()
    
    # Start with the provided query
    $searchQueries += $Query
    
    # Add variations if we have artist name
    if ($ArtistName) {
        # Try without strict quoting
        $cleanAlbum = $AlbumName -replace '[^\w\s]', '' -replace '\s+', ' '
        $cleanArtist = $ArtistName -replace '[^\w\s]', '' -replace '\s+', ' '
        
        $searchQueries += "$cleanAlbum $cleanArtist"
        
        # Try with just album and artist (no album: prefix)
        $searchQueries += "`"$AlbumName`" `"$ArtistName`""
        
        # Try shortened album name (common in classical music)
        $shortAlbum = $AlbumName -replace '\s+(featuring|feat\.?|with|performed by|orchestra|symphony|philharmonic|choir|ensemble).*$', '' -replace '\s+$', ''
        if ($shortAlbum -ne $AlbumName -and $shortAlbum.Length -gt 3) {
            $searchQueries += "`"$shortAlbum`" `"$ArtistName`""
        }
        
        # Try first significant word(s) for classical compositions
        $firstWords = ($AlbumName -split '\s+')[0..1] -join ' '
        if ($firstWords.Length -gt 3 -and $firstWords -ne $shortAlbum) {
            $searchQueries += "$firstWords $ArtistName"
        }
    }
    
    $allResults = @()
    $queryCount = 0
    
    foreach ($searchQuery in $searchQueries) {
        $queryCount++
        Write-Verbose "  Query $queryCount`: $searchQuery"
        
        try {
            $result = Search-Item -Type Album -Query $searchQuery -ErrorAction Stop
            $items = @()
            
            # Parse results (same logic as original)
            if ($null -eq $result) { continue }
            if ($result -is [System.Array]) {
                foreach ($page in $result) {
                    if ($page.PSObject.Properties.Match('Albums').Count -gt 0 -and $page.Albums -and $page.Albums.Items) { 
                        $items += $page.Albums.Items 
                    }
                    elseif ($page.PSObject.Properties.Match('Items').Count -gt 0 -and $page.Items) { 
                        $items += $page.Items 
                    }
                }
            } else {
                if ($result.PSObject.Properties.Match('Albums').Count -gt 0 -and $result.Albums -and $result.Albums.Items) { 
                    $items = $result.Albums.Items 
                }
                elseif ($result.PSObject.Properties.Match('Items').Count -gt 0 -and $result.Items) { 
                    $items = $result.Items 
                }
            }
            
            Write-Verbose "    Found $($items.Count) items"
            
            foreach ($item in $items) {
                try {
                    $name = if ($item.PSObject.Properties.Match('Name').Count) { [string]$item.Name } else { $null }
                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                    
                    # Calculate album similarity
                    $albumScore = Get-StringSimilarity -String1 $AlbumName -String2 $name
                    
                    # Check artist similarity if we have artist name
                    $artistMatch = $true
                    $bestArtistScore = 0
                    
                    if ($ArtistName -and $item.PSObject.Properties.Match('Artists').Count -gt 0 -and $item.Artists) {
                        $artistMatch = $false
                        foreach ($artist in $item.Artists) {
                            $artistName = if ($artist.PSObject.Properties.Match('Name').Count) { [string]$artist.Name } else { $null }
                            if ($artistName) {
                                $artistScore = Get-StringSimilarity -String1 $ArtistName -String2 $artistName
                                $bestArtistScore = [Math]::Max($bestArtistScore, $artistScore)
                                if ($artistScore -ge 0.7) {
                                    $artistMatch = $true
                                    break
                                }
                            }
                        }
                    }
                    
                    # Only consider if artist matches reasonably well
                    if (-not $artistMatch) { continue }
                    
                    # Boost score for year matches
                    $yearBoost = 0
                    if ($Year -and $item.PSObject.Properties.Match('ReleaseDate').Count) {
                        $releaseDate = [string]$item.ReleaseDate
                        if ($releaseDate) {
                            $albumYear = [regex]::Match($releaseDate, '^\d{4}').Value
                            if ($albumYear -eq $Year) {
                                $yearBoost = 0.2
                                Write-Verbose "      Year match bonus for: $name"
                            }
                        }
                    }
                    
                    $finalScore = $albumScore + $yearBoost
                    
                    # Only include if it meets minimum score
                    if ($finalScore -ge $MinScore) {
                        # Parse artists
                        $artists = @()
                        if ($item.PSObject.Properties.Match('Artists').Count -gt 0 -and $item.Artists) {
                            foreach ($a in $item.Artists) {
                                $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } else { $null }
                                $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } else { $null }
                                if ($an) { $artists += [PSCustomObject]@{ Name=$an; Id=$aid } }
                            }
                        }
                        
                        $releaseDate = if ($item.PSObject.Properties.Match('ReleaseDate').Count) { [string]$item.ReleaseDate } else { $null }
                        $albumType = if ($item.PSObject.Properties.Match('AlbumType').Count) { [string]$item.AlbumType } else { $null }

                        $allResults += [PSCustomObject]@{ 
                            AlbumName   = $name
                            Score       = [double]$finalScore
                            Artists     = $artists
                            ReleaseDate = $releaseDate
                            AlbumType   = $albumType
                            Item        = $item
                            Query       = $searchQuery
                        }
                    }
                } catch {
                    Write-Verbose "      Error processing item: $($_.Exception.Message)"
                }
            }
            
            # Early termination: if we found good matches, don't try more complex queries
            $goodMatches = $allResults | Where-Object { $_.Score -ge ($MinScore + 0.2) }
            if ($goodMatches.Count -ge 2) {
                Write-Verbose "    Found $($goodMatches.Count) good matches, stopping search"
                break
            }
            
        } catch {
            Write-Verbose "    Query failed: $($_.Exception.Message)"
        }
    }
    
    # Return best matches
    $topResults = $allResults | Sort-Object -Property Score -Descending | Select-Object -First $Top
    Write-Verbose "  Returning $($topResults.Count) matches from $queryCount queries"
    
    if ($topResults.Count -gt 0) {
        Write-Verbose "  Best match: '$($topResults[0].AlbumName)' (Score: $([math]::Round($topResults[0].Score, 2)))"
    }
    
    return $topResults
}