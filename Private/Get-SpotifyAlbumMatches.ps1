function Get-SpotifyAlbumMatches {
<#
.SYNOPSIS
    Searches Spotify for albums using a specified query and returns top matches with artists and a similarity score.

.PARAMETER Query
    The raw search query string to send to Spotify.

.PARAMETER AlbumName
    The album name to search for. Used for scoring similarity.

.PARAMETER ArtistName
    The artist name for additional search variations.

.PARAMETER Year
    The release year for additional search variations.

.PARAMETER Top
    Number of top matches to return (default 5).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][string]$AlbumName,
        [string]$ArtistName,
        [string]$Year,
        [int]$Top = 5
    )

    # Multiple search strategies - try different approaches
    $searchQueries = @($Query)
    
    # Add fallback strategies if we have artist name
    if ($ArtistName) {
        # Strategy 2: Direct album name search (like manual Spotify search)
        $searchQueries += "`"$AlbumName`""
        
        # Strategy 3: Simple artist + album without prefixes
        $searchQueries += "$ArtistName $AlbumName"
        
        # Strategy 4: Your successful pattern - artist + year + full album name
        if ($Year) {
            $searchQueries += "$ArtistName $Year - $AlbumName"
        }
        
        # Strategy 5: Just the album name without quotes for broader matching
        $searchQueries += $AlbumName
    }

    $allResults = @()
    
    foreach ($searchQuery in $searchQueries) {
        # Try both Album and All search types
        foreach ($searchType in @('Album', 'All')) {
            try {
                Write-Verbose ("Search-Item $searchType query: '{0}'" -f $searchQuery)
                $result = Search-Item -Type $searchType -Query $searchQuery -ErrorAction Stop
                $items = @()
                if ($null -eq $result) { continue }
                
                # Extract album items based on search type
                if ($searchType -eq 'Album') {
                    if ($result -is [System.Array]) {
                        foreach ($page in $result) {
                            if ($page.PSObject.Properties.Match('Albums').Count -gt 0 -and $page.Albums -and $page.Albums.Items) { $items += $page.Albums.Items }
                            elseif ($page.PSObject.Properties.Match('Items').Count -gt 0 -and $page.Items) { $items += $page.Items }
                        }
                    } else {
                        if ($result.PSObject.Properties.Match('Albums').Count -gt 0 -and $result.Albums -and $result.Albums.Items) { $items = $result.Albums.Items }
                        elseif ($result.PSObject.Properties.Match('Items').Count -gt 0 -and $result.Items) { $items = $result.Items }
                    }
                } else {
                    # For 'All' search type, extract albums
                    if ($result.PSObject.Properties.Match('Albums').Count -gt 0 -and $result.Albums -and $result.Albums.Items) {
                        $items = $result.Albums.Items
                    }
                }
            
            foreach ($i in $items) {
                try {
                    $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                    
                    # Check if this is an Arvo Pärt album (for direct searches that return many results)
                    $isArvoPart = $false
                    if ($ArtistName -and $i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                        foreach ($artist in $i.Artists) {
                            $artistName = if ($artist.PSObject.Properties.Match('Name').Count) { [string]$artist.Name } else { $null }
                            if ($artistName -and ($artistName -like "*Arvo*" -or $artistName -like "*Pärt*" -or $artistName -like "*Part*")) {
                                $isArvoPart = $true
                                break
                            }
                        }
                        # Skip non-Arvo Pärt results for direct searches
                        if ($searchQuery -eq "`"$AlbumName`"" -or $searchQuery -eq $AlbumName) {
                            if (-not $isArvoPart) { continue }
                        }
                    }
                    
                    # Normalize album name by removing common artist prefixes for better matching
                    $normalizedSpotifyName = $name
                    # Remove "Artist: " or "Artist - " prefixes
                    $normalizedSpotifyName = $normalizedSpotifyName -replace '^[^:]+:\s*', '' -replace '^[^-]+\s*-\s*', ''
                    # Remove common classical music prefixes like "Pärt: "
                    $normalizedSpotifyName = $normalizedSpotifyName -replace '^(Pärt|Part|Arvo Pärt|Arvo Part):\s*', ''
                    
                    $score = Get-StringSimilarity -String1 $AlbumName -String2 $normalizedSpotifyName
                    
                    # Boost score for conductor/performer matches in classical music
                    if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                        $conductorBoost = 0
                        foreach ($artist in $i.Artists) {
                            $artistName = if ($artist.PSObject.Properties.Match('Name').Count) { [string]$artist.Name } else { $null }
                            if ($artistName) {
                                # Check if any part of the album name matches the performer/conductor
                                $albumWords = $AlbumName -split '\s+' | Where-Object { $_.Length -gt 3 }
                                foreach ($word in $albumWords) {
                                    if ($artistName -like "*$word*") {
                                        $conductorBoost += 0.3  # Significant boost for performer match
                                        Write-Verbose "Conductor/performer match: '$word' found in '$artistName'"
                                        break
                                    }
                                }
                            }
                        }
                        $score += $conductorBoost
                    }
                    
                    $artists = @()
                    if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                        foreach ($a in $i.Artists) {
                            $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                            $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                            if ($an) { $artists += [PSCustomObject]@{ Name=$an; Id=$aid } }
                        }
                    }
                    $releaseDate = if ($i.PSObject.Properties.Match('ReleaseDate').Count) { [string]$i.ReleaseDate } else { $null }
                    $albumType = if ($i.PSObject.Properties.Match('AlbumType').Count) { [string]$i.AlbumType } else { $null }

                    $albumResult = [PSCustomObject]@{ 
                        AlbumName   = $name
                        Score       = [double]$score
                        Artists     = $artists
                        ReleaseDate = $releaseDate
                        AlbumType   = $albumType
                        Item        = $i # Keep original item for track fetching later
                        SearchQuery = $searchQuery
                    }
                    
                    # Avoid duplicates by checking if we already have this album
                    $existing = $allResults | Where-Object { $_.Item.Id -eq $i.Id }
                    if (-not $existing) {
                        $allResults += $albumResult
                    } elseif ($albumResult.Score -gt $existing.Score) {
                        # Replace with better score
                        $allResults = $allResults | Where-Object { $_.Item.Id -ne $i.Id }
                        $allResults += $albumResult
                    }
                } catch { }
            }
            
            # Early termination if we found good results
            $goodResults = $allResults | Where-Object { $_.Score -ge 0.8 }
            if ($goodResults.Count -ge $Top) {
                Write-Verbose "Found enough good results, stopping search"
                break
            }
            
            } catch {
                Write-Verbose ("Album search failed for query '{0}' type '{1}': {2}" -f $searchQuery, $searchType, $_.Exception.Message)
            }
        }
        
        # If we found good results with this query, don't try more complex queries
        $goodResults = $allResults | Where-Object { $_.Score -ge 0.8 }
        if ($goodResults.Count -ge $Top) {
            Write-Verbose "Found enough good results, stopping search"
            break
        }
    }
    
    return ($allResults | Sort-Object -Property Score -Descending | Select-Object -First $Top)
}
