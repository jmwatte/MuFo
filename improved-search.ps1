# Improved album search algorithm for MuFo
# This replaces the inefficient 4-tier system with a smarter approach

function Get-SpotifyAlbumMatches-Improved {
    param(
        [string]$ArtistName,
        [string]$ArtistId,
        [string]$AlbumName,
        [string]$Year,
        [double]$MinScore = 0.6
    )
    
    Write-Verbose "Improved search for: '$AlbumName' by '$ArtistName' ($Year)"
    
    # Strategy 1: Direct album search with artist constraint (most efficient)
    $queries = @()
    
    if ($Year) {
        $queries += "album:`"$AlbumName`" artist:`"$ArtistName`" year:$Year"
        $queries += "`"$AlbumName`" `"$ArtistName`" $Year"
    }
    
    $queries += "album:`"$AlbumName`" artist:`"$ArtistName`""
    $queries += "`"$AlbumName`" `"$ArtistName`""
    
    # Try shortened album name (remove common classical music descriptors)
    $shortAlbum = $AlbumName -replace '\s+(featuring|feat\.?|with|performed by|orchestra|symphony|philharmonic).*$', '' -replace '\s+$', ''
    if ($shortAlbum -ne $AlbumName -and $shortAlbum.Length -gt 3) {
        $queries += "album:`"$shortAlbum`" artist:`"$ArtistName`""
        $queries += "`"$shortAlbum`" `"$ArtistName`""
    }
    
    # Try first word(s) of album for classical works
    $firstWords = ($AlbumName -split '\s+')[0..1] -join ' '
    if ($firstWords.Length -gt 3 -and $firstWords -ne $shortAlbum) {
        $queries += "album:`"$firstWords`" artist:`"$ArtistName`""
    }
    
    $allResults = @()
    
    foreach ($query in $queries) {
        Write-Verbose "  Trying query: $query"
        try {
            $searchResults = Search-Item -Type Album -Query $query -ErrorAction Stop
            if ($searchResults -and $searchResults.Albums -and $searchResults.Albums.Items) {
                $albums = $searchResults.Albums.Items
                Write-Verbose "    Found $($albums.Count) results"
                
                foreach ($album in $albums) {
                    # Quick artist name check to avoid irrelevant results
                    $hasCorrectArtist = $false
                    if ($album.Artists) {
                        foreach ($artist in $album.Artists) {
                            $similarity = Get-StringSimilarity -String1 $ArtistName -String2 $artist.Name
                            if ($similarity -ge 0.7) {
                                $hasCorrectArtist = $true
                                break
                            }
                        }
                    }
                    
                    if ($hasCorrectArtist) {
                        # Calculate album name similarity
                        $albumSimilarity = Get-StringSimilarity -String1 $AlbumName -String2 $album.Name
                        
                        # Boost score for year matches
                        $yearBoost = 0
                        if ($Year -and $album.ReleaseDate) {
                            $albumYear = [regex]::Match($album.ReleaseDate, '^\d{4}').Value
                            if ($albumYear -eq $Year) {
                                $yearBoost = 0.3
                                Write-Verbose "    Year match bonus for: $($album.Name)"
                            }
                        }
                        
                        $finalScore = $albumSimilarity + $yearBoost
                        
                        if ($finalScore -ge $MinScore) {
                            $allResults += [PSCustomObject]@{
                                Name = $album.Name
                                Score = $finalScore
                                ReleaseDate = $album.ReleaseDate
                                AlbumType = $album.AlbumType
                                Artists = $album.Artists
                                Item = $album
                                Query = $query
                            }
                        }
                    }
                }
                
                # If we found good results, don't try more complex queries
                if ($allResults.Count -gt 0) {
                    break
                }
            }
        } catch {
            Write-Verbose "    Query failed: $($_.Exception.Message)"
        }
    }
    
    # Strategy 2: Only if no results, try a limited artist discography search
    if ($allResults.Count -eq 0 -and $ArtistId) {
        Write-Verbose "  No direct matches, trying limited artist discography..."
        try {
            # Get only albums (not singles/compilations) to reduce volume
            $artistAlbums = Get-SpotifyArtistAlbums -ArtistId $ArtistId -IncludeSingles:$false -IncludeCompilations:$false -ErrorAction Stop
            Write-Verbose "    Got $($artistAlbums.Count) artist albums (filtered)"
            
            # Only check albums that might match
            foreach ($album in $artistAlbums) {
                $albumSimilarity = Get-StringSimilarity -String1 $AlbumName -String2 $album.Name
                
                # More lenient scoring for artist discography search
                if ($albumSimilarity -ge ($MinScore - 0.2)) {
                    $yearBoost = 0
                    if ($Year -and $album.ReleaseDate) {
                        $albumYear = [regex]::Match($album.ReleaseDate, '^\d{4}').Value
                        if ($albumYear -eq $Year) {
                            $yearBoost = 0.3
                        }
                    }
                    
                    $finalScore = $albumSimilarity + $yearBoost
                    
                    $allResults += [PSCustomObject]@{
                        Name = $album.Name
                        Score = $finalScore
                        ReleaseDate = $album.ReleaseDate
                        AlbumType = $album.AlbumType
                        Artists = @([PSCustomObject]@{ Name = $ArtistName; Id = $ArtistId })
                        Item = $album
                        Query = "artist_discography"
                    }
                }
            }
        } catch {
            Write-Verbose "    Artist discography search failed: $($_.Exception.Message)"
        }
    }
    
    # Return best matches, sorted by score
    $topResults = $allResults | Sort-Object Score -Descending | Select-Object -First 5
    Write-Verbose "  Returning $($topResults.Count) matches, best score: $($topResults[0].Score | ForEach-Object { [math]::Round($_, 2) })"
    
    return $topResults
}

# Test the improved algorithm
$ArtistName = "Arvo Pärt"
$ArtistId = "ARTAP"  # This would come from the artist search

Write-Host "=== Testing Improved Algorithm ===" -ForegroundColor Cyan

$testAlbums = @(
    @{ Name = "Tabula Rasa"; Year = "1984" },
    @{ Name = "Passio"; Year = "1988" },
    @{ Name = "Te Deum"; Year = "1993" },
    @{ Name = "Fratres"; Year = "1995" },
    @{ Name = "Kanon Pokajanen"; Year = "1998" }
)

foreach ($test in $testAlbums) {
    Write-Host "`nTesting: $($test.Name) ($($test.Year))" -ForegroundColor Yellow
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $results = Get-SpotifyAlbumMatches-Improved -ArtistName $ArtistName -ArtistId $ArtistId -AlbumName $test.Name -Year $test.Year -MinScore 0.5
    $stopwatch.Stop()
    
    Write-Host "  Time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
    Write-Host "  Results: $($results.Count)" -ForegroundColor Green
    
    if ($results) {
        foreach ($result in $results | Select-Object -First 3) {
            Write-Host "    - $($result.Name) (Score: $([math]::Round($result.Score, 2)), Query: $($result.Query))" -ForegroundColor White
        }
    } else {
        Write-Host "    No matches found" -ForegroundColor Red
    }
}