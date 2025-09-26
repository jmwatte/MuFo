# Album Processing Functions for Invoke-MuFo
# These functions handle album matching, comparison, and scoring logic

function Get-AlbumComparisons {
    <#
    .SYNOPSIS
    Processes local album directories and finds best Spotify matches.
    
    .DESCRIPTION
    Analyzes local album folder names, searches Spotify for matches using multiple
    search strategies, and scores the results to find the best matches.
    
    .PARAMETER CurrentPath
    Path to the current artist directory containing album folders.
    
    .PARAMETER SelectedArtist
    The selected Spotify artist object with Name and Id properties.
    
    .PARAMETER EffectiveExclusions
    Array of folder exclusion patterns.
    
    .OUTPUTS
    Array of album comparison objects with match scores and proposed names.
    
    .NOTES
    Uses tiered search strategy for best results:
    1. Precise filtered search (artist, album, year)
    2. Year-influenced search  
    3. Broad fallback search
    4. Limited fallback for short names
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        
        [Parameter(Mandatory)]
        $SelectedArtist,
        
        [Parameter(Mandatory)]
        [array]$EffectiveExclusions,

        [Parameter(Mandatory = $false)]
        $ForcedAlbum
    )
    
    # Get local album directories
    $localAlbumDirs = Get-ChildItem -LiteralPath $CurrentPath -Directory -ErrorAction SilentlyContinue
    Write-Verbose "Found album directories before exclusion filtering: $($localAlbumDirs.Name -join ', ')"
    $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $EffectiveExclusions) }
    Write-Verbose "Album directories after exclusion filtering: $($localAlbumDirs.Name -join ', ')"
    
    # Check if any of the remaining directories contain format-separated subfolders
    # If so, treat the parent directory as an album instead of the format subfolders
    $processedAlbumDirs = @()
    foreach ($dir in $localAlbumDirs) {
        $subDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -ErrorAction SilentlyContinue
        $formatDirs = $subDirs | Where-Object {
            $_.Name -in @('FLAC', 'APE', 'MP3', 'M4A', 'OGG', 'WAV', 'WMA') -or
            $_.Name -match '^(FLAC|APE|MP3|M4A|OGG|WAV|WMA)$'
        }
        
        if ($formatDirs) {
            # This directory contains format subfolders - treat it as an album
            Write-Verbose "Directory '$($dir.Name)' contains format-separated subfolders: $($formatDirs.Name -join ', ')"
            $processedAlbumDirs += $dir
        } else {
            # Normal album directory
            $processedAlbumDirs += $dir
        }
    }
    
    $localAlbumDirs = $processedAlbumDirs
    Write-Verbose ("Local album folders found: {0}" -f (($localAlbumDirs | Measure-Object).Count))

    $albumComparisons = @()
    foreach ($dir in $localAlbumDirs) {
    $comparison = Get-SingleAlbumComparison -Directory $dir -SelectedArtist $SelectedArtist -ForcedAlbum $ForcedAlbum
        $albumComparisons += $comparison
    }
    
    return $albumComparisons
}

function Get-SingleAlbumComparison {
    <#
    .SYNOPSIS
    Processes a single album directory to find the best Spotify match.
    
    .DESCRIPTION
    Analyzes a single local album folder, searches Spotify using multiple
    strategies, and returns the best match with scoring information.
    #>
    param(
        [Parameter(Mandatory)]
        $Directory,
        
        [Parameter(Mandatory)]
        $SelectedArtist,

        [Parameter(Mandatory = $false)]
        $ForcedAlbum
    )
    
    $best = $null
    $bestScore = 0
    $dirName = [string]$Directory.Name
    
    # Normalize local name: strip optional leading year and separators
    $normalizedLocal = $dirName -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
    if ([string]::IsNullOrWhiteSpace($normalizedLocal)) { $normalizedLocal = $dirName }
    
    # Detect if original had year prefix and capture it
    $origYear = $null
    $m = [regex]::Match($dirName, '^[\(\[]?(?<year>\d{4})[\)\]]?')
    if ($m.Success) { $origYear = $m.Groups['year'].Value }

    if ($ForcedAlbum) {
        $best = $ForcedAlbum
        $forcedScoreResult = Get-AlbumScore -SpotifyAlbum $ForcedAlbum -NormalizedLocal $normalizedLocal -OrigYear $origYear
        if ($forcedScoreResult -is [array] -and $forcedScoreResult.Count -gt 0) {
            $bestScore = [double]$forcedScoreResult[0]
        } elseif ($null -ne $forcedScoreResult) {
            $bestScore = [double]$forcedScoreResult
        }
    } else {
        # Use tiered search strategy
        # Special handling for Various Artists compilations
        if ($SelectedArtist.Name -eq 'Various Artists') {
            $spotifyAlbums = Get-SpotifyCompilationsForLocal -NormalizedLocal $normalizedLocal -OrigYear $origYear
        } else {
            $spotifyAlbums = Get-SpotifyAlbumsForLocal -NormalizedLocal $normalizedLocal -OrigYear $origYear -SelectedArtist $SelectedArtist
        }
        
        # Find best match from search results
        $best, $bestScore = Get-BestAlbumMatch -SpotifyAlbums $spotifyAlbums -NormalizedLocal $normalizedLocal -OrigYear $origYear
    }
    
    # Build album comparison object
    $albumInfo = Build-AlbumComparisonObject -Directory $Directory -Best $best -BestScore $bestScore -NormalizedLocal $normalizedLocal -OrigYear $origYear
    
    return $albumInfo
}

function Get-SpotifyCompilationsForLocal {
    <#
    .SYNOPSIS
    Searches Spotify for compilation albums using tiered search strategy.
    
    .DESCRIPTION
    Searches for compilation albums (Various Artists) using multiple tiers:
    1. Precise compilation search (album, year)
    2. Year-influenced compilation search
    3. Broad compilation fallback search
    #>
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedLocal,
        
        [string]$OrigYear
    )
    
    $spotifyAlbums = @()
    
    # Tier 1: Various Artists Specific Search (user's working query pattern)
    $q1 = "various artists `"$NormalizedLocal`""
    Write-Verbose "Trying Various Artists query: '$q1'"
    $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q1 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    
    # Tier 2: Various Artists with Year
    if ($spotifyAlbums.Count -eq 0 -and $OrigYear) {
        $q2 = "various artists `"$NormalizedLocal`" $OrigYear"
        Write-Verbose "Trying Various Artists with year query: '$q2'"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q2 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    }
    
    # Tier 3: Precise Compilation Search (album, year, compilation)
    if ($spotifyAlbums.Count -eq 0 -and $OrigYear) {
        $q3 = "album:`"$NormalizedLocal`" year:$OrigYear tag:compilation"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q3 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    }
    
    # Tier 4: Year-Influenced Compilation Search
    if ($spotifyAlbums.Count -eq 0 -and $OrigYear) {
        $q4 = "album:`"$NormalizedLocal`" $OrigYear tag:compilation"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q4 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    }
    
    # Tier 5: Broad Compilation Fallback Search
    if ($spotifyAlbums.Count -eq 0) {
        $q5 = "album:`"$NormalizedLocal`" tag:compilation"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q5 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    }
    
    # If no compilation-specific results, try general album search
    if ($spotifyAlbums.Count -eq 0) {
        Write-Verbose "No compilation-specific results, trying general album search..."
        $q6 = "album:`"$NormalizedLocal`""
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q6 -AlbumName $NormalizedLocal -ArtistName "Various Artists" -Year $OrigYear
    }
    
    return $spotifyAlbums
}

function Get-SpotifyAlbumsForLocal {
    <#
    .SYNOPSIS
    Searches Spotify for albums using tiered search strategy.
    
    .DESCRIPTION
    Implements a comprehensive search strategy with multiple tiers:
    1. Precise filtered search (artist, album, year)
    2. Year-influenced search (artist, album, year as keyword)
    3. Broad fallback search (artist, album)
    4. Limited fallback for very short album names
    #>
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedLocal,
        
        [string]$OrigYear,
        
        [Parameter(Mandatory)]
        $SelectedArtist
    )
    
    $spotifyAlbums = @()
    
    # Tier 1: Precise Filtered Search (artist, album, year)
    if ($OrigYear) {
        $q1 = "artist:`"$($SelectedArtist.Name)`" album:`"$NormalizedLocal`" year:$OrigYear"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q1 -AlbumName $NormalizedLocal -ArtistName $SelectedArtist.Name -Year $OrigYear
    }
    
    # Tier 2: Year-Influenced Search (artist, album, year as keyword)
    if ($spotifyAlbums.Count -eq 0 -and $OrigYear) {
        $q2 = "artist:`"$($SelectedArtist.Name)`" album:`"$NormalizedLocal`" $OrigYear"
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q2 -AlbumName $NormalizedLocal -ArtistName $SelectedArtist.Name -Year $OrigYear
    }
    
    # Tier 3: Broad Fallback Search (artist, album)
    if ($spotifyAlbums.Count -eq 0) {
        $q3 = "artist:`"$($SelectedArtist.Name)`" album:`"$NormalizedLocal`""
        $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q3 -AlbumName $NormalizedLocal -ArtistName $SelectedArtist.Name -Year $OrigYear
    }
    
    # Tier 4: Limited fallback - only for very short album names
    if ($spotifyAlbums.Count -eq 0 -and $NormalizedLocal.Length -le 10) {
        Write-Verbose "Very short album name, trying limited artist discography..."
        $artistAlbums = Get-SpotifyArtistAlbums -ArtistId $SelectedArtist.Id -IncludeSingles:$false -IncludeCompilations:$false -ErrorAction Stop
        # Only check albums with reasonable similarity to avoid processing thousands
        $spotifyAlbums = $artistAlbums | Where-Object { 
            $quickScore = Get-StringSimilarity -String1 $NormalizedLocal -String2 $_.Name
            $quickScore -ge 0.5
        } | Select-Object -First 20
    }
    
    return $spotifyAlbums
}

function Get-BestAlbumMatch {
    <#
    .SYNOPSIS
    Finds the best matching album from Spotify search results.
    
    .DESCRIPTION
    Evaluates all Spotify album results, applies scoring with year bonuses,
    and returns the best match with its score.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$SpotifyAlbums,
        
        [Parameter(Mandatory)]
        [string]$NormalizedLocal,
        
        [string]$OrigYear
    )
    
    $best = $null
    $bestScore = 0
    
    foreach ($sa in $SpotifyAlbums) {
        try {
            if (-not $sa) { continue }
            
            $score, $saName = Get-AlbumScore -SpotifyAlbum $sa -NormalizedLocal $NormalizedLocal -OrigYear $OrigYear
            
            if ($score -gt $bestScore) { 
                $bestScore = $score
                $best = $sa 
            }
        } catch {
            Write-Verbose ("Album compare skipped due to error: {0}" -f $_.Exception.Message)
            # Fallback quick ratio
            $fallbackScore = Get-FallbackAlbumScore -SpotifyAlbum $sa -NormalizedLocal $NormalizedLocal
            if ($fallbackScore -gt $bestScore) { 
                $bestScore = $fallbackScore
                $best = $sa 
            }
        }
    }
    
    return $best, $bestScore
}

function Get-AlbumScore {
    <#
    .SYNOPSIS
    Calculates similarity score for a Spotify album.
    
    .DESCRIPTION
    Computes base similarity score and applies year bonuses for better matching.
    Handles both pre-scored results and raw album objects.
    #>
    param(
        [Parameter(Mandatory)]
        $SpotifyAlbum,
        
        [Parameter(Mandatory)]
        [string]$NormalizedLocal,
        
        [string]$OrigYear
    )
    
    $score = 0
    $saName = $null
    
    # Check if this is already a scored result from Get-SpotifyAlbumMatches
    if ($SpotifyAlbum.PSObject.Properties.Match('Score').Count -gt 0 -and $SpotifyAlbum.PSObject.Properties.Match('AlbumName').Count -gt 0) {
        # This is a pre-scored result, use its score and name
        $score = [double]$SpotifyAlbum.Score
        $saName = [string]$SpotifyAlbum.AlbumName
        
        # Apply year bonus for pre-scored results
        $score = Add-YearBonus -Score $score -SpotifyAlbum $SpotifyAlbum -OrigYear $OrigYear -AlbumName $saName
    } else {
        # This is a raw Spotify album object, score it manually
        $saName = Get-SpotifyAlbumName -SpotifyAlbum $SpotifyAlbum
        if ($null -eq $saName) { return 0, $null }
        
        if ($saName -is [array]) { $saName = ($saName -join ' ') } else { $saName = [string]$saName }
        $score = Get-StringSimilarity -String1 $NormalizedLocal -String2 $saName
        
        # Apply year bonus for raw albums
        $score = Add-YearBonus -Score $score -SpotifyAlbum $SpotifyAlbum -OrigYear $OrigYear -AlbumName $saName
    }
    
    return $score, $saName
}

function Get-SpotifyAlbumName {
    <#
    .SYNOPSIS
    Extracts album name from Spotify album object.
    
    .DESCRIPTION
    Handles different property naming conventions in Spotify API responses.
    #>
    param([Parameter(Mandatory)]$SpotifyAlbum)
    
    $saName = $null
    if ($SpotifyAlbum.PSObject.Properties.Match('Name').Count -gt 0) { 
        $saName = $SpotifyAlbum.Name 
    } elseif ($SpotifyAlbum.PSObject.Properties.Match('name').Count -gt 0) { 
        $saName = $SpotifyAlbum.name 
    }
    
    return $saName
}

function Add-YearBonus {
    <#
    .SYNOPSIS
    Adds year matching bonus to album similarity score.
    
    .DESCRIPTION
    Provides significant bonus for albums that match the local folder's year,
    helping to prefer original releases over reissues.
    #>
    param(
        [Parameter(Mandatory)]
        [double]$Score,
        
        [Parameter(Mandatory)]
        $SpotifyAlbum,
        
        [string]$OrigYear,
        
        [Parameter(Mandatory)]
        [string]$AlbumName
    )
    
    # Boost score for year matches to prefer original releases  
    if ($OrigYear -and $SpotifyAlbum.PSObject.Properties.Match('ReleaseDate').Count -gt 0 -and $SpotifyAlbum.ReleaseDate) {
        $saYear = [regex]::Match([string]$SpotifyAlbum.ReleaseDate, '^(?<y>\d{4})')
        if ($saYear.Success -and $saYear.Groups['y'].Value -eq $OrigYear) {
            $Score += 1.0  # Heavily boost for exact year match
            Write-Verbose ("Year match bonus: {0} ({1}) matches local year {2}" -f $AlbumName, $saYear.Groups['y'].Value, $OrigYear)
        }
    }
    
    return $Score
}

function Get-FallbackAlbumScore {
    <#
    .SYNOPSIS
    Calculates fallback similarity score using basic string comparison.
    
    .DESCRIPTION
    Used when normal scoring fails, provides basic length-based similarity.
    #>
    param(
        [Parameter(Mandatory)]
        $SpotifyAlbum,
        
        [Parameter(Mandatory)]
        [string]$NormalizedLocal
    )
    
    try {
        $saName = Get-SpotifyAlbumName -SpotifyAlbum $SpotifyAlbum
        $n1 = $NormalizedLocal.ToLowerInvariant().Trim()
        $n2 = ([string]$saName).ToLowerInvariant().Trim()
        
        if (-not [string]::IsNullOrWhiteSpace($n1) -and -not [string]::IsNullOrWhiteSpace($n2)) {
            $l1 = $n1.Length
            $l2 = $n2.Length
            $max = [Math]::Max($l1, $l2)
            if ($max -gt 0) { 
                return ([Math]::Min($l1, $l2) / $max) 
            }
        }
    } catch { }
    
    return 0
}

function Build-AlbumComparisonObject {
    <#
    .SYNOPSIS
    Creates a structured album comparison object.
    
    .DESCRIPTION
    Builds the final comparison object with all necessary properties
    for further processing and decision making.
    #>
    param(
        [Parameter(Mandatory)]
        $Directory,
        
        $Best,
        
        [Parameter(Mandatory)]
        [double]$BestScore,
        
        [Parameter(Mandatory)]
        [string]$NormalizedLocal,
        
        [string]$OrigYear
    )
    
    $dirName = [string]$Directory.Name
    
    # Build proposed target name based on Spotify album name and available year info
    $matchName = $null
    if ($Best) {
        if ($Best.PSObject.Properties.Match('Name').Count) {
            $matchName = [string]$Best.Name
        } elseif ($Best.PSObject.Properties.Match('AlbumName').Count) {
            $matchName = [string]$Best.AlbumName
        }
    }
    
    $matchType = if ($Best) { 
        if ($Best.PSObject.Properties.Match('AlbumType').Count) { 
            [string]$Best.AlbumType 
        } else { 
            $null 
        } 
    } else { 
        $null 
    }
    
    $matchYear = $null
    if ($Best -and $Best.PSObject.Properties.Match('ReleaseDate').Count -gt 0 -and $Best.ReleaseDate) {
        $ym = [regex]::Match([string]$Best.ReleaseDate, '^(?<y>\d{4})')
        if ($ym.Success) { $matchYear = $ym.Groups['y'].Value }
    }
    
    $targetBase = if ($matchName) { ConvertTo-SafeFileName $matchName } else { $null }
    $proposed = $null
    if ($targetBase) {
        if ($OrigYear) {
            $y = if ($matchYear) { $matchYear } else { $OrigYear }
            $proposed = "${y} - $targetBase"
        } else {
            $proposed = $targetBase
        }
    }
    
    return [PSCustomObject]@{
        LocalAlbum   = $dirName
        LocalNorm    = $NormalizedLocal
        LocalPath    = $Directory.FullName
        MatchName    = $matchName
        MatchType    = $matchType
        MatchScore   = [math]::Round($BestScore, 2)
        MatchYear    = $matchYear
        ProposedName = $proposed
        MatchedItem  = $Best # Keep the full object for track fetching
    }
}

function Add-TrackInformationToComparisons {
    <#
    .SYNOPSIS
    Adds track information to album comparisons when IncludeTracks is enabled.
    
    .DESCRIPTION
    Enhances album comparison objects with local and Spotify track information,
    including composer data and track counts.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$AlbumComparisons,
        
        [bool]$BoxMode = $false
    )
    
    foreach ($c in $AlbumComparisons) {
        try {
            # Determine paths to scan for tracks (BoxMode aggregates subfolders as discs)
            $scanPaths = if ($BoxMode -and (Get-ChildItem -LiteralPath $c.LocalPath -Directory -ErrorAction SilentlyContinue)) {
                Get-ChildItem -LiteralPath $c.LocalPath -Directory | Select-Object -ExpandProperty FullName
            } else {
                @($c.LocalPath)
            }
            
            $tracks = @()
            foreach ($p in $scanPaths) {
                $tracks += Get-AudioFileTags -Path $p -IncludeComposer
            }
            
            $c | Add-Member -NotePropertyName TrackCountLocal -NotePropertyValue $tracks.Count
            
            # Add composer information if available
            $composers = $tracks | Where-Object { $_.Composer } | Group-Object -Property Composer | Sort-Object -Property Count -Descending
            $primaryComposer = if ($composers.Count -gt 0) { $composers[0].Name } else { $null }
            $c | Add-Member -NotePropertyName PrimaryComposer -NotePropertyValue $primaryComposer
            
            # Get Spotify track information if available - optimized approach
            if ($c.MatchedItem -and $c.MatchedItem.Item) {
                $spotifyAlbum = if ($c.MatchedItem -and $c.MatchedItem.Item) { $c.MatchedItem.Item } else { $null }
                if ($spotifyAlbum -and $spotifyAlbum.Id) {
                    # Note: Spotify tracks will be populated later by batch optimization
                    # Just set up the structure here for now
                    $c | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue 0
                    $c | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue @()
                } else {
                    $c | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue 0
                    $c | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue @()
                }
            } else {
                $c | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue 0
                $c | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue @()
            }
        } catch {
            Write-Verbose ("Track info collection failed for '{0}': {1}" -f $c.LocalAlbum, $_.Exception.Message)
            $c | Add-Member -NotePropertyName TrackCountLocal -NotePropertyValue 0
            $c | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue 0
            $c | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue @()
        }
    }
}