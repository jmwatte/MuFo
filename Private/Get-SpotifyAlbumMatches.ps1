function Get-PartialTokenSetSimilarity {
    param([string]$a, [string]$b)
    $setA = ($a -replace '[^\w\s]', '').ToLower().Split(' ') | Where-Object { $_ }
    $setB = ($b -replace '[^\w\s]', '').ToLower().Split(' ') | Where-Object { $_ }
    $allAinB = ($setA | Where-Object { $setB -notcontains $_ }).Count -eq 0
    if ($allAinB) { return 1.0 }
    # fallback to normal token set ratio
    $intersection = $setA | Where-Object { $setB -contains $_ }
    $union = $setA + ($setB | Where-Object { $setA -notcontains $_ })
    if ($union.Count -eq 0) { return 0 }
    return ($intersection.Count / $union.Count)
}
function Get-TokenSetSimilarity {
    param([string]$a, [string]$b)
    $setA = ($a -replace '[^\w\s]', '').ToLower().Split(' ') | Where-Object { $_ }
    $setB = ($b -replace '[^\w\s]', '').ToLower().Split(' ') | Where-Object { $_ }
    $intersection = $setA | Where-Object { $setB -contains $_ }
    $union = $setA + ($setB | Where-Object { $setA -notcontains $_ })
    if ($union.Count -eq 0) { return 0 }
    return ($intersection.Count / $union.Count)
}
function Remove-EditionSuffix {
    param(
        [string]$albumName,
        [string]$searchTerm
    )
    # Only strip if searchTerm does not contain a parenthetical or bracketed suffix
    if ($searchTerm -notmatch '\([^)]+\)|\[[^\]]+\]' -and $albumName -match '\s*[\(\[][^)\]]+[\)\]]\s*$') {
        return ($albumName -replace '\s*[\(\[][^)\]]+[\)\]]\s*$', '')
    }
    return $albumName
}

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

.PARAMETER AlbumWeight
    Weight applied to album-name similarity when computing the combined score (default 0.7).

.PARAMETER ArtistWeight
    Weight applied to artist-name similarity when computing the combined score (default 0.3).

.PARAMETER ArtistPriorityThreshold
    If artist similarity >= this, compute album similarity and short-circuit if album >= AlbumAcceptThreshold (default 0.90).

.PARAMETER AlbumAcceptThreshold
    If album similarity >= this while artist >= ArtistPriorityThreshold, accept result immediately (default 0.90).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][string]$AlbumName,
        [string]$ArtistName,
        [string]$Year,
        [int]$Top = 2,
        [double]$AlbumWeight = 0.7,
        [double]$ArtistWeight = 0.3,
        [double]$ArtistPriorityThreshold = 0.90,
        [double]$AlbumAcceptThreshold = 0.90
    )

    # Validate weights
    if ($AlbumWeight -lt 0 -or $ArtistWeight -lt 0) { throw "Weights must be non-negative" }

    # Build search query variations
    $searchQueries = @($Query)
    if ($ArtistName) {
        $searchQueries += "$ArtistName $AlbumName"
        $searchQueries += "`"$AlbumName`""
        if ($Year) { $searchQueries += "$ArtistName $Year - $AlbumName" }
        $searchQueries += $AlbumName
    }

    $allResults = @()

    foreach ($searchQuery in $searchQueries) {
        foreach ($searchType in @('Album', 'All')) {
            try {
                Write-Verbose ("Search-Item {0} query: '{1}'" -f $searchType, $searchQuery)
                $result = Search-Item -Type $searchType -Query $searchQuery -ErrorAction Stop
                if ($null -eq $result) { continue }

                # Extract album items robustly (handle paging and different shapes)
                $items = @()
                if ($result -is [System.Array]) {
                    foreach ($page in $result) {
                        if ($page.PSObject.Properties.Match('Albums').Count -gt 0 -and $page.Albums -and $page.Albums.Items) { $items += $page.Albums.Items }
                        elseif ($page.PSObject.Properties.Match('Items').Count -gt 0 -and $page.Items) { $items += $page.Items }
                    }
                }
                else {
                    if ($result.PSObject.Properties.Match('Albums').Count -gt 0 -and $result.Albums -and $result.Albums.Items) { $items = $result.Albums.Items }
                    elseif ($result.PSObject.Properties.Match('Items').Count -gt 0 -and $result.Items) { $items = $result.Items }
                }
                #filter $items so we only get albums
                if ($searchType -eq 'All' -or $searchType -eq 'Album') {
                    $items = $items | Where-Object { 
                        ($_ -and $_.PSObject.Properties.Match('AlbumType').Count -gt 0 -and ($_.AlbumType -eq 'album') -or
                        ($_ -and $_.PSObject.Properties.Match('album_type').Count -gt 0 -and ($_.album_type -eq 'album')))
                    }
                }
                # Keep inner-result scanning isolated so we can return immediately on high-confidence match
                foreach ($i in $items) {

                    try {
                        # Album name (robust to Name/name)
                        $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name }
                        elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name }
                        else { $null }
                        if ([string]::IsNullOrWhiteSpace($name)) { continue }

                        # Normalize Spotify album name minimally (keep for similarity)
                        $normalizedSpotifyName = Remove-EditionSuffix $name $AlbumName

                        # Build artists array robustly (handles single artist or array of objects)
                        $artists = @()
                        if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                            foreach ($a in @($i.Artists)) {
                                if ($null -eq $a) { continue }
                                $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name }
                                elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name }
                                else { $null }
                                $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id }
                                elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id }
                                else { $null }
                                if ($an) { $artists += [PSCustomObject]@{ Name = $an; Id = $aid } }
                            }
                        }

                        # Build a clean single artist string for similarity comparisons
                        $artistString = ($artists | ForEach-Object { $_.Name }) -join ' & '
                        if ($artistString) {
                            # remove stray straight and smart quotes and normalize whitespace
                            $artistString = ($artistString -replace '[\"“”''‘’]', '') -replace '\s+', ' '
                            $artistString = $artistString.Trim()
                        }

                        # Compute artist similarity first (if caller supplied ArtistName)
                        $artistScore = 0.0
                        if ($ArtistName -and -not [string]::IsNullOrWhiteSpace($artistString)) {
                            $normalizedArtistQuery = ($ArtistName -replace '[\"“”''‘’]', '') -replace '\s+', ' '
                            $normalizedArtistQuery = $normalizedArtistQuery.Trim()
                            try {
                                $artistScore = Get-StringSimilarity -String1 $normalizedArtistQuery -String2 $artistString
                            }
                            catch {
                                Write-Verbose "Get-StringSimilarity failed for artist: $_"
                                $artistScore = 0.0
                            }
                        }

                        # If artist strongly matches, compute album similarity and possibly short-circuit
                        if ($artistScore -ge $ArtistPriorityThreshold) {
                            try {
                                $albumScore = Get-StringSimilarity -String1 $AlbumName -String2 $normalizedSpotifyName
                            }
                            catch {
                                Write-Verbose "Get-StringSimilarity failed for album: $_"
                                $albumScore = 0.0
                            }

                            if ($albumScore -ge $AlbumAcceptThreshold) {
                                # small conductor/perfomer boost retained
                                $conductorBoost = 0.0
                                $albumWords = $AlbumName -split '\s+' | Where-Object { $_.Length -gt 3 }
                                foreach ($artistObj in $artists) {
                                    $aName = $artistObj.Name
                                    foreach ($w in $albumWords) {
                                        if ($aName -like "*$w*") {
                                            $conductorBoost += 0.3
                                            break
                                        }
                                    }
                                }

                                $combinedScore = [double](($albumScore * $AlbumWeight) + ($artistScore * $ArtistWeight) + $conductorBoost)
                                if ($combinedScore -gt 1.0) { $combinedScore = 1.0 }

                                $releaseDate = if ($i.PSObject.Properties.Match('ReleaseDate').Count) {
                                    [string]$i.ReleaseDate
                                }
                                elseif ($i.PSObject.Properties.Match('release_date').Count) {
                                    [string]$i.release_date
                                }
                                else {
                                    $null
                                }

                                $albumType = if ($i.PSObject.Properties.Match('AlbumType').Count) {
                                    [string]$i.AlbumType
                                }
                                elseif ($i.PSObject.Properties.Match('album_type').Count) {
                                    [string]$i.album_type
                                }
                                else {
                                    $null
                                }

                                $albumResult = [PSCustomObject]@{
                                    AlbumName      = $name
                                    AlbumScore     = [double]$albumScore
                                    ArtistScore    = [double]$artistScore
                                    ConductorBoost = [double]$conductorBoost
                                    Score          = [double]$combinedScore
                                    Artists        = $artists
                                    ReleaseDate    = $releaseDate
                                    AlbumType      = $albumType
                                    Item           = $i
                                    SearchQuery    = $searchQuery
                                }

                                # Return immediately with this high-confidence result (respect Top by returning at most $Top)
                                return (, $albumResult | Sort-Object -Property Score -Descending | Select-Object -First $Top)
                            }
                            # else: fall through to combined scoring below
                        }

                        # Use partial token set similarity for album name
                        $albumScore = Get-PartialTokenSetSimilarity $AlbumName $normalizedSpotifyName
                        # Also compute token set similarity for diagnostics
                        $tokenSetScore = Get-TokenSetSimilarity $AlbumName $normalizedSpotifyName


                        # Only apply conductor/performer boost if artistScore is strong
                        $conductorBoost = 0.0
                        if ($artistScore -ge 0.7) {
                            $albumWords = $AlbumName -split '\s+' | Where-Object { $_.Length -gt 3 }
                            foreach ($artistObj in $artists) {
                                $aName = $artistObj.Name
                                foreach ($w in $albumWords) {
                                    if ($aName -like "*$w*") {
                                        $conductorBoost += 0.3
                                        break
                                    }
                                }
                            }
                        }


                        # Query specificity boost: if the query contains both artist and album, and both match strongly, add a bigger boost
                        $hasArtistInQuery = $false
                        $hasAlbumInQuery = $false
                        if ($ArtistName) {
                            try {
                                $hasArtistInQuery = $searchQuery -match [regex]::Escape($ArtistName)
                            } catch {}
                        }
                        if ($AlbumName) {
                            try {
                                $hasAlbumInQuery = $searchQuery -match [regex]::Escape($AlbumName)
                            } catch {}
                        }

                        $combinedScore = [double](($albumScore * $AlbumWeight) + ($artistScore * $ArtistWeight) + $conductorBoost)

                        # Stronger boost for highly specific query and strong match
                        if ($hasArtistInQuery -and $hasAlbumInQuery -and $artistScore -ge 0.9 -and $albumScore -ge 0.9) {
                            $combinedScore += 0.6
                        }
                        # Penalize if query is for both but artist match is weak
                        if ($hasArtistInQuery -and $hasAlbumInQuery -and $artistScore -lt 0.5) {
                            $combinedScore -= 0.2
                        }
                        # Penalize weak album matches for specific queries
                        if ($hasArtistInQuery -and $hasAlbumInQuery -and $albumScore -lt 0.7) {
                            $combinedScore -= 0.3
                        }
                        # Clamp
                        if ($combinedScore -gt 1.0) { $combinedScore = 1.0 }
                        if ($combinedScore -lt 0) { $combinedScore = 0 }

                        $ReleaseDate = if ($i.PSObject.Properties.Match('ReleaseDate').Count) { [string]$i.ReleaseDate }
                        elseif ($i.PSObject.Properties.Match('release_date').Count) { [string]$i.release_date }
                        else { $null }
                        $AlbumType = if ($i.PSObject.Properties.Match('AlbumType').Count) { [string]$i.AlbumType }
                        elseif ($i.PSObject.Properties.Match('album_type').Count) { [string]$i.album_type }
                        else { $null }


                        # Construct result object
                        $albumResult = [PSCustomObject]@{
                            AlbumName      = $name
                            AlbumScore     = [double]$albumScore
                            TokenSetScore  = [double]$tokenSetScore
                            ArtistScore    = [double]$artistScore
                            ConductorBoost = [double]$conductorBoost
                            Score          = [double]$combinedScore
                            Artists        = $artists
                            ReleaseDate    = $ReleaseDate
                            AlbumType      = $AlbumType
                            Item           = $i
                            SearchQuery    = $searchQuery
                        }

                        # Avoid duplicates (match by Id or fallback to name+artists)
                        $itemId = if ($i.PSObject.Properties.Match('Id').Count) { [string]$i.Id }
                        elseif ($i.PSObject.Properties.Match('id').Count) { [string]$i.id }
                        else { $null }

                        $existing = if ($itemId) { $allResults | Where-Object { $_.Item -and ($_.Item.PSObject.Properties.Match('Id').Count -and ($_.Item.Id -eq $itemId) -or $_.Item.PSObject.Properties.Match('id').Count -and ($_.Item.id -eq $itemId)) } }
                        else { $allResults | Where-Object { $_.AlbumName -eq $name -and ( ($_.Artists | ForEach-Object { $_.Name }) -join ' & ' ) -eq $artistString } }

                        if (-not $existing) {
                            $queryScore= Get-StringSimilarity -String1 $searchQuery -String2 $( $artistString+" "+$name)
                            $allResults += $albumResult
                        }
                        else {
                            # If we already have it but this score is better, replace
                            if ($albumResult.Score -gt ($existing | Select-Object -First 1).Score) {
                                $allResults = $allResults | Where-Object { -not ( ($_.Item.PSObject.Properties.Match('Id').Count -gt 0 -and $itemId -and ($_.Item.Id -eq $itemId)) -or ($_.AlbumName -eq $name) ) }
                                $allResults += $albumResult
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Error processing item: $_"
                    }
                }

                # After processing items, check if we already have enough good results to stop
                $goodResults = $allResults | Where-Object { $_.Score -ge 0.7 }
                if ($goodResults.Count -ge $Top) {
                    Write-Verbose "Found enough good results, stopping search"
                    break
                }
            }
            catch {
                Write-Verbose ("Album search failed for query '{0}' type '{1}': {2}" -f $searchQuery, $searchType, $_.Exception.Message)
            }
        }

        # Stop further search queries if we already have enough high-confidence results
        $goodResults = $allResults | Where-Object { $_.Score -ge 0.8 }
        if ($goodResults.Count -ge $Top) {
            Write-Verbose "Found enough good results across queries, stopping"
            break
        }
    }

    # Final sort and return top N
    return ($allResults | Sort-Object -Property Score -Descending | Select-Object -First $Top)
}