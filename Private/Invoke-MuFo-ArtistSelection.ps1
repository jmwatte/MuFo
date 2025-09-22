# Artist Selection Functions for Invoke-MuFo
# These functions handle the complex logic for selecting the best Spotify artist match

function Get-ArtistSelection {
    <#
    .SYNOPSIS
    Selects the best Spotify artist match using multiple strategies.
    
    .DESCRIPTION
    Implements a sophisticated artist selection process that includes:
    - Direct search matching with confidence thresholds
    - Album-based inference and voting
    - Manual user selection
    - Catalog evaluation for best-fit determination
    
    .PARAMETER LocalArtist
    The local artist name from the folder structure.
    
    .PARAMETER TopMatches
    Array of top Spotify artist matches from search.
    
    .PARAMETER DoIt
    The operation mode ('Manual', 'Smart', 'Automatic').
    
    .PARAMETER ConfidenceThreshold
    Minimum confidence score for automatic selection.
    
    .PARAMETER IsPreview
    Whether this is a preview/WhatIf operation.
    
    .PARAMETER CurrentPath
    Path to the current artist directory.
    
    .PARAMETER EffectiveExclusions
    Array of folder exclusion patterns.
    
    .PARAMETER IncludeSingles
    Whether to include singles in catalog evaluation.
    
    .PARAMETER IncludeCompilations
    Whether to include compilations in catalog evaluation.
    
    .OUTPUTS
    PSCustomObject with SelectedArtist and SelectionSource properties.
    
    .NOTES
    This function encapsulates the complex artist selection logic that was
    previously embedded in the main Invoke-MuFo function.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [array]$TopMatches,
        
        [Parameter(Mandatory)]
        [string]$DoIt,
        
        [Parameter(Mandatory)]
        [double]$ConfidenceThreshold,
        
        [Parameter(Mandatory)]
        [bool]$IsPreview,
        
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        
        [Parameter(Mandatory)]
        [array]$EffectiveExclusions,
        
        [bool]$IncludeSingles = $false,
        [bool]$IncludeCompilations = $false
    )
    
    $selectedArtist = $null
    $artistSelectionSource = 'search'
    
    switch ($DoIt) {
        "Automatic" {
            $selectedArtist = $TopMatches[0].Artist
            $artistSelectionSource = 'search'
            Write-Verbose "Automatically selected: $($selectedArtist.Name)"
        }
        "Manual" {
            # Don't override high-confidence artist matches with inference
            # Use a higher threshold (0.8) to ensure we only skip inference for very confident matches
            if ($TopMatches[0].Score -ge 0.8) {
                $selectedArtist = $TopMatches[0].Artist
                $artistSelectionSource = 'search'
                Write-Verbose "High-confidence artist match found (score: $([math]::Round($TopMatches[0].Score, 2))), using directly: $($selectedArtist.Name)"
            } elseif (-not $IsPreview) {
                # Prompt user to choose (skip prompts in Preview/WhatIf)
                for ($i = 0; $i -lt $TopMatches.Count; $i++) {
                    Write-Host "$($i + 1). $($TopMatches[$i].Artist.Name) (Score: $([math]::Round($TopMatches[$i].Score, 2)))"
                }
                $choice = Read-Host "Select artist (1-$($TopMatches.Count)) [Enter=1, S=skip]"
                if (-not $choice) {
                    $selectedArtist = $TopMatches[0].Artist
                    $artistSelectionSource = 'search'
                } elseif ($choice -match '^(?i)s(kip)?$' -or $choice -match '^0$') {
                    # skip
                } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $TopMatches.Count) {
                    $selectedArtist = $TopMatches[[int]$choice - 1].Artist
                }
            } else {
                # In WhatIf/Preview, pick the top match for analysis so we still produce results
                $selectedArtist = $TopMatches[0].Artist
                $artistSelectionSource = 'search'
                Write-Verbose "Preview/WhatIf: assuming top search match '$($selectedArtist.Name)' for analysis."
            }
        }
        "Smart" {
            if ($TopMatches[0].Score -ge $ConfidenceThreshold) {
                $selectedArtist = $TopMatches[0].Artist
                Write-Verbose "Smart selected: $($selectedArtist.Name)"
            } else {
                # Low confidence: defer to inference first; we may prompt later if still unresolved
                Write-Verbose "Low confidence. Deferring to album-based inference before any prompt."
            }
        }
    }
    
    if (-not $selectedArtist) {
        # Run artist inference
        $inferenceResult = Get-ArtistFromInference -LocalArtist $LocalArtist -CurrentPath $CurrentPath -EffectiveExclusions $EffectiveExclusions -IsPreview $IsPreview -DoIt $DoIt -ConfidenceThreshold $ConfidenceThreshold
        $selectedArtist = $inferenceResult.SelectedArtist
        if ($selectedArtist) {
            $artistSelectionSource = 'inferred'
        }
    }
    
    # If still not selected and Smart mode, offer manual selection only when not in Preview/WhatIf
    if (-not $selectedArtist -and $DoIt -eq 'Smart' -and -not $IsPreview) {
        Write-Verbose "No artist after inference. Switching to manual selection."
        for ($i = 0; $i -lt $TopMatches.Count; $i++) {
            Write-Host "$($i + 1). $($TopMatches[$i].Artist.Name) (Score: $([math]::Round($TopMatches[$i].Score, 2)))"
        }
        $choice = Read-Host "Select artist (1-$($TopMatches.Count)) [Enter=1, S=skip]"
        if (-not $choice) {
            $selectedArtist = $TopMatches[0].Artist
        } elseif ($choice -match '^(?i)s(kip)?$' -or $choice -match '^0$') {
            # skip
        } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $TopMatches.Count) {
            $selectedArtist = $TopMatches[[int]$choice - 1].Artist
        }
    }
    
    # Evaluate top search candidates against local album folders to pick best-fit artist
    if (-not $selectedArtist -and $TopMatches -and $TopMatches.Count -gt 0) {
        $evaluationResult = Get-BestArtistFromCatalogEvaluation -TopMatches $TopMatches -CurrentPath $CurrentPath -EffectiveExclusions $EffectiveExclusions -IncludeSingles $IncludeSingles -IncludeCompilations $IncludeCompilations
        if ($evaluationResult.SelectedArtist) {
            $selectedArtist = $evaluationResult.SelectedArtist
            $artistSelectionSource = 'evaluated'
        }
    }
    
    # Final fallback in Preview/WhatIf: if still not selected, assume top match to enable analysis
    if (-not $selectedArtist -and $IsPreview -and $TopMatches -and $TopMatches.Count -gt 0) {
        $selectedArtist = $TopMatches[0].Artist
        $artistSelectionSource = 'search'
        Write-Verbose "Preview/WhatIf: no confident or inferred artist; assuming top search match '$($selectedArtist.Name)' for analysis."
    }
    
    return [PSCustomObject]@{
        SelectedArtist = $selectedArtist
        SelectionSource = $artistSelectionSource
    }
}

function Get-ArtistFromInference {
    <#
    .SYNOPSIS
    Infers the best artist match based on local album folder analysis.
    
    .DESCRIPTION
    Performs sophisticated album-based artist inference using multiple search strategies
    and voting mechanisms to determine the most likely correct artist.
    
    .OUTPUTS
    PSCustomObject with SelectedArtist property.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        
        [Parameter(Mandatory)]
        [array]$EffectiveExclusions,
        
        [Parameter(Mandatory)]
        [bool]$IsPreview,
        
        [Parameter(Mandatory)]
        [string]$DoIt,
        
        [Parameter(Mandatory)]
        [double]$ConfidenceThreshold
    )
    
    $selectedArtist = $null
    
    try {
        $localAlbumDirs = Get-ChildItem -LiteralPath $CurrentPath -Directory -ErrorAction SilentlyContinue
        $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $EffectiveExclusions) }
        $localNames = @()
        foreach ($d in $localAlbumDirs) {
            $n = [string]$d.Name
            $nn = $n -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
            if (-not [string]::IsNullOrWhiteSpace($nn)) { $localNames += $nn }
        }
        
        # Quick path: use the first local album name to infer directly from top album match
        if ($localNames.Count -gt 0) {
            $quickResult = Get-QuickArtistInference -LocalArtist $LocalArtist -LocalNames $localNames -LocalAlbumDirs $localAlbumDirs
            if ($quickResult.SelectedArtist) {
                return $quickResult
            }
            
            # If quick inference failed, try voting inference
            $votingResult = Get-ArtistFromVoting -LocalArtist $LocalArtist -LocalNames $localNames -IsPreview $IsPreview -DoIt $DoIt -ConfidenceThreshold $ConfidenceThreshold
            if ($votingResult.SelectedArtist) {
                return $votingResult
            }
        }
    } catch { 
        Write-Verbose ("Artist inference failed: {0}" -f $_.Exception.Message) 
    }
    
    return [PSCustomObject]@{ SelectedArtist = $null }
}

function Get-QuickArtistInference {
    <#
    .SYNOPSIS
    Attempts quick artist inference using the first local album name.
    
    .DESCRIPTION
    Uses targeted search queries with the first album to quickly identify
    the correct artist without running full voting inference.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [array]$LocalNames,
        
        [Parameter(Mandatory)]
        [array]$LocalAlbumDirs
    )
    
    $selectedArtist = $null
    $primary = $LocalNames[0]
    
    # Extract year from first album folder for targeted search
    $primaryYear = $null
    if ($LocalAlbumDirs -and $LocalAlbumDirs.Count -gt 0) {
        $firstDir = $LocalAlbumDirs[0].Name
        $ym = [regex]::Match($firstDir, '^[\(\[]?(?<year>\d{4})[\)\]]?')
        if ($ym.Success) { $primaryYear = $ym.Groups['year'].Value }
    }
    
    $query = if ($primaryYear) {
        "artist:`"$LocalArtist`" album:`"$primary`" year:$primaryYear"
    } else {
        "artist:`"$LocalArtist`" album:`"$primary`""
    }
    
    $quick = Get-SpotifyAlbumMatches -Query $query -AlbumName $primary -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($quick -and $quick.Artists -and $quick.Artists.Count -gt 0) {
        $qa = $quick.Artists[0]
        if ((Get-StringSimilarity -String1 $LocalArtist -String2 $qa.Name) -ge 0.8) {
            $selectedArtist = [PSCustomObject]@{ Name=[string]$qa.Name; Id=[string]$qa.Id }
            Write-Verbose ("Quick-inferred artist from album '{0}': {1}" -f $primary, $selectedArtist.Name)
        }
    } else {
        # Quick fallback using combined All search
        $selectedArtist = Get-QuickAllSearchInference -LocalArtist $LocalArtist -Primary $primary
        if (-not $selectedArtist) {
            # Try phrase-based searches as last resort for quick inference
            $selectedArtist = Get-QuickPhraseSearchInference -LocalArtist $LocalArtist -Primary $primary
        }
    }
    
    return [PSCustomObject]@{ SelectedArtist = $selectedArtist }
}

function Get-QuickAllSearchInference {
    <#
    .SYNOPSIS
    Quick artist inference using Search-Item All query.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$Primary
    )
    
    $selectedArtist = $null
    
    try {
        $q = "{0} {1}" -f $LocalArtist, $Primary
        Write-Verbose ("Search-Item All query (quick): '{0}'" -f $q)
        $all = Search-Item -Type All -Query $q -ErrorAction Stop
        $albums = Get-AlbumItemsFromSearchResult -Result $all
        
        # Score albums by similarity to local album name and choose best
        $scored = @()
        $normLocal = ConvertTo-ComparableName -Name $Primary
        foreach ($i in $albums) {
            $nm = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
            if ([string]::IsNullOrWhiteSpace($nm)) { continue }
            $s = 0.0
            try { $s = Get-StringSimilarity -String1 $Primary -String2 $nm } catch { $s = 0.0 }
            
            # Boost exact normalized name match
            try {
                $nn = ConvertTo-ComparableName -Name $nm
                if ($nn -eq $normLocal) { $s += 1.0 }
                else {
                    # Penalize common variant tags if not present in local
                    $nnWords = $nm.ToLowerInvariant()
                    $localWords = $Primary.ToLowerInvariant()
                    $pen = 0.0
                    if ($nnWords -match '\blive\b' -and $localWords -notmatch '\blive\b') { $pen += 0.2 }
                    if ($nnWords -match '\bdeluxe\b' -and $localWords -notmatch '\bdeluxe\b') { $pen += 0.1 }
                    if ($nnWords -match '\bremaster(ed)?\b' -and $localWords -notmatch '\bremaster(ed)?\b') { $pen += 0.1 }
                    $s -= $pen
                }
            } catch { }
            $scored += [PSCustomObject]@{ AlbumName=$nm; Score=[double]$s; Item=$i }
        }
        
        $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
        if ($best -and $best.Item -and $best.Item.Artists -and $best.Item.Artists.Count -gt 0) {
            # Require a minimal relevance: token overlap and minimum score
            $minScore = 0.3
            $primaryTokens = ($Primary.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 })
            $bestTokens = ($best.AlbumName.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 })
            $overlap = @($primaryTokens | Where-Object { $bestTokens -contains $_ })
            if ($best.Score -lt $minScore -or ($overlap.Count -eq 0)) {
                Write-Verbose ("Quick All-search best match rejected (score={0}, overlap={1}): '{2}'" -f ([math]::Round($best.Score,2)), $overlap.Count, $best.AlbumName)
                $best = $null
            }
        }
        
        if ($best -and $best.Item -and $best.Item.Artists -and $best.Item.Artists.Count -gt 0) {
            $fa = $best.Item.Artists[0]
            $san = if ($fa.PSObject.Properties.Match('Name').Count) { [string]$fa.Name } elseif ($fa.PSObject.Properties.Match('name').Count) { [string]$fa.name } else { $null }
            $said = if ($fa.PSObject.Properties.Match('Id').Count) { [string]$fa.Id } elseif ($fa.PSObject.Properties.Match('id').Count) { [string]$fa.id } else { $null }
            if ($san) {
                $selectedArtist = [PSCustomObject]@{ Name=$san; Id=$said }
                Write-Verbose ("Quick-inferred artist from All-search (best match '{0}' score={1}): {2}" -f $best.AlbumName, ([math]::Round($best.Score,2)), $san)
            }
        }
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
        Write-Verbose ("Quick All-search inference failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
    }
    
    return $selectedArtist
}

function Get-QuickPhraseSearchInference {
    <#
    .SYNOPSIS
    Quick artist inference using phrase-based album searches.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$Primary
    )
    
    $selectedArtist = $null
    
    try {
        $albums = @()
        $q1 = '"{0}"' -f $Primary
        Write-Verbose ("Search-Item Album query (phrase): {0}" -f $q1)
        $r1 = Search-Item -Type Album -Query $q1 -ErrorAction Stop
        if ($r1) { $albums += (Get-AlbumItemsFromSearchResult -Result $r1) }
        
        if (-not $albums -or $albums.Count -eq 0) {
            $q2 = '"{0} {1}"' -f $LocalArtist, $Primary
            Write-Verbose ("Search-Item Album query (artist+phrase): {0}" -f $q2)
            $r2 = Search-Item -Type Album -Query $q2 -ErrorAction Stop
            if ($r2) { $albums += (Get-AlbumItemsFromSearchResult -Result $r2) }
        }
        
        if ($albums -and $albums.Count -gt 0) {
            $scored = @()
            foreach ($i in $albums) {
                $nm = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                if ([string]::IsNullOrWhiteSpace($nm)) { continue }
                $s = 0.0
                try { $s = Get-StringSimilarity -String1 $Primary -String2 $nm } catch { $s = 0.0 }
                $scored += [PSCustomObject]@{ AlbumName=$nm; Score=[double]$s; Item=$i }
            }
            
            $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
            if ($best -and $best.Item -and $best.Item.Artists -and $best.Item.Artists.Count -gt 0 -and $best.Score -ge 0.3) {
                $fa = $best.Item.Artists[0]
                $san = if ($fa.PSObject.Properties.Match('Name').Count) { [string]$fa.Name } elseif ($fa.PSObject.Properties.Match('name').Count) { [string]$fa.name } else { $null }
                $said = if ($fa.PSObject.Properties.Match('Id').Count) { [string]$fa.Id } elseif ($fa.PSObject.Properties.Match('id').Count) { [string]$fa.id } else { $null }
                if ($san) {
                    $selectedArtist = [PSCustomObject]@{ Name=$san; Id=$said }
                    Write-Verbose ("Quick-inferred artist from phrase search (best '{0}' score={1}): {2}" -f $best.AlbumName, ([math]::Round($best.Score,2)), $san)
                }
            }
        }
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
        Write-Verbose ("Phrase album search inference failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
    }
    
    return $selectedArtist
}

function Get-ArtistFromVoting {
    <#
    .SYNOPSIS
    Determines the best artist using album-based voting inference.
    
    .DESCRIPTION
    Runs comprehensive album searches and uses voting mechanisms to identify
    the most likely correct artist based on album match patterns.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [array]$LocalNames,
        
        [Parameter(Mandatory)]
        [bool]$IsPreview,
        
        [Parameter(Mandatory)]
        [string]$DoIt,
        
        [Parameter(Mandatory)]
        [double]$ConfidenceThreshold
    )
    
    $selectedArtist = $null
    $artistVotes = @{}
    
    Write-Verbose "Starting artist voting inference process"
    
    foreach ($ln in $LocalNames) {
        if ($selectedArtist) { break }
        
        # Try both album-only and combined artist+album queries to improve recall
        # Extract year from current album name for targeted search
        $lnYear = $null
        $lym = [regex]::Match($ln, '^[\(\[]?(?<year>\d{4})[\)\]]?')
        if ($lym.Success) { $lnYear = $lym.Groups['year'].Value }
        
        $albumQuery = if ($lnYear) {
            "artist:`"$LocalArtist`" album:`"$($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','')`" year:$lnYear"
        } else {
            "artist:`"$LocalArtist`" album:`"$($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','')`""
        }
        
        $m1 = Get-SpotifyAlbumMatches -Query $albumQuery -AlbumName ($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','') -ErrorAction SilentlyContinue
        
        # Also try a combined All-type query via Search-Item directly
        $m3 = Get-AllSearchMatches -LocalArtist $LocalArtist -AlbumName $ln
        
        # Add phrase-based album matches too
        $m4, $m5 = Get-PhraseSearchMatches -LocalArtist $LocalArtist -AlbumName $ln
        
        if (-not $selectedArtist) {
            Write-Verbose "Processing album '$ln' for artist votes"
            $allMatches = @()
            if ($m1) { $allMatches += @($m1); Write-Verbose "Added m1 matches: $($m1.Count)" }
            if ($m3) { $allMatches += @($m3); Write-Verbose "Added m3 matches: $($m3.Count)" }
            if ($m4) { $allMatches += @($m4); Write-Verbose "Added m4 matches: $($m4.Count)" }
            if ($m5) { $allMatches += @($m5); Write-Verbose "Added m5 matches: $($m5.Count)" }
            Write-Verbose "Total matches for voting: $($allMatches.Count)"
            
            foreach ($m in $allMatches) {
                if ($m.Artists) {
                    foreach ($a in $m.Artists) {
                        if (-not $a.Name) { continue }
                        Write-Verbose "Checking artist vote for: $($a.Name) with match score: $($m.Score)"
                        
                        # Only count votes for reasonably relevant matches
                        if ($m.Score -ge 0.3) {
                            $artistSimilarity = Get-StringSimilarity -String1 $LocalArtist -String2 $a.Name
                            Write-Verbose "Artist similarity between '$LocalArtist' and '$($a.Name)': $artistSimilarity"
                            if ($artistSimilarity -ge 0.7) {
                                if (-not $artistVotes.ContainsKey($a.Name)) { 
                                    $artistVotes[$a.Name] = [PSCustomObject]@{ Name=$a.Name; Id=$a.Id; Votes=0; BestScore=0.0 } 
                                }
                                $entry = $artistVotes[$a.Name]
                                $entry.Votes += 1
                                if ($m.Score -gt $entry.BestScore) { $entry.BestScore = [double]$m.Score }
                                Write-Verbose "Added vote for artist '$($a.Name)' (total votes: $($entry.Votes), best score: $($entry.BestScore))"
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (-not $selectedArtist -and $artistVotes.Count -gt 0) {
        $inferred = $artistVotes.Values | Sort-Object -Property Votes, BestScore -Descending | Select-Object -First 1
        if ($inferred) {
            # If preview/whatif, prefer inferred artist for analysis; otherwise use thresholds/prompts
            if ($IsPreview -or $DoIt -eq 'Automatic' -or ($DoIt -eq 'Smart' -and $inferred.BestScore -ge [Math]::Min(1.0, $ConfidenceThreshold))) {
                $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id }
                Write-Verbose ("Inferred artist from albums: {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
            } else {
                if (-not $IsPreview) {
                    Write-Host ("Likely artist based on albums: {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
                    $resp = Read-Host ("Use inferred artist? [Y/n]")
                    if (-not $resp -or $resp -match '^(?i)y(es)?$') { 
                        $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id } 
                    }
                } else {
                    # In preview, use the inferred artist if it has reasonable confidence
                    if ($inferred.BestScore -ge 0.7) {
                        $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id }
                        Write-Verbose ("Preview: Using inferred artist {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
                    }
                }
            }
        }
    }
    
    return [PSCustomObject]@{ SelectedArtist = $selectedArtist }
}

function Get-AllSearchMatches {
    <#
    .SYNOPSIS
    Gets album matches using Search-Item All query.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$AlbumName
    )
    
    $matches = @()
    
    try {
        $q = "{0} {1}" -f $LocalArtist, $AlbumName
        Write-Verbose ("Search-Item All query: '{0}'" -f $q)
        $all = Search-Item -Type All -Query $q -ErrorAction Stop
        $albums = Get-AlbumItemsFromSearchResult -Result $all
        
        foreach ($i in $albums) {
            $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $score = Get-StringSimilarity -String1 $AlbumName -String2 $name
            $artists = @()
            if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                foreach ($a in $i.Artists) {
                    $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                    $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                    if ($an) { $artists += [PSCustomObject]@{ Name=$an; Id=$aid } }
                }
            }
            $matches += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$artists }
        }
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
        Write-Verbose ("Search-Item All failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
    }
    
    return $matches
}

function Get-PhraseSearchMatches {
    <#
    .SYNOPSIS
    Gets album matches using phrase-based searches.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$AlbumName
    )
    
    $m4 = @(); $m5 = @()
    
    try {
        $q1 = '"{0}"' -f $AlbumName
        Write-Verbose ("Search-Item Album query (phrase): {0}" -f $q1)
        $r1 = Search-Item -Type Album -Query $q1 -ErrorAction Stop
        $albums1 = Get-AlbumItemsFromSearchResult -Result $r1
        
        foreach ($i in $albums1) {
            $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $score = Get-StringSimilarity -String1 $AlbumName -String2 $name
            $arts = @()
            if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) { 
                foreach ($a in $i.Artists) { 
                    $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                    $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                    if ($an) { $arts += [PSCustomObject]@{ Name=$an; Id=$aid } } 
                } 
            }
            $m4 += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$arts }
        }
        
        $q2 = '"{0} {1}"' -f $LocalArtist, $AlbumName
        Write-Verbose ("Search-Item Album query (artist+phrase): {0}" -f $q2)
        $r2 = Search-Item -Type Album -Query $q2 -ErrorAction Stop
        $albums2 = Get-AlbumItemsFromSearchResult -Result $r2
        
        foreach ($i in $albums2) {
            $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $score = Get-StringSimilarity -String1 $AlbumName -String2 $name
            $arts = @()
            if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) { 
                foreach ($a in $i.Artists) { 
                    $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                    $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                    if ($an) { $arts += [PSCustomObject]@{ Name=$an; Id=$aid } } 
                } 
            }
            $m5 += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$arts }
        }
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
        Write-Verbose ("Phrase m4/m5 search failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
    }
    
    return $m4, $m5
}

function Get-BestArtistFromCatalogEvaluation {
    <#
    .SYNOPSIS
    Evaluates top search candidates against local album folders to pick best-fit artist.
    
    .DESCRIPTION
    Compares each candidate artist's catalog against local albums to determine
    which artist has the best overall match to the local collection.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$TopMatches,
        
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        
        [Parameter(Mandatory)]
        [array]$EffectiveExclusions,
        
        [bool]$IncludeSingles = $false,
        [bool]$IncludeCompilations = $false
    )
    
    $selectedArtist = $null
    
    try {
        # Gather local album names (normalized)
        $localAlbumDirs = Get-ChildItem -LiteralPath $CurrentPath -Directory -ErrorAction SilentlyContinue
        $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $EffectiveExclusions) }
        $localNames = @()
        foreach ($d in $localAlbumDirs) {
            $n = [string]$d.Name
            $nn = $n -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
            if (-not [string]::IsNullOrWhiteSpace($nn)) { $localNames += $nn }
        }
        
        $bestCand = $null; $bestScoreSum = -1.0
        foreach ($tm in $TopMatches) {
            $cand = $tm.Artist
            if (-not $cand -or -not $cand.Id) { continue }
            $albums = @()
            try { 
                $albums = Get-SpotifyArtistAlbums -ArtistId $cand.Id -IncludeSingles:$IncludeSingles -IncludeCompilations:$IncludeCompilations -ErrorAction Stop 
            } catch { 
                $albums = @() 
            }
            if (-not $albums) { continue }
            
            $sum = 0.0
            foreach ($ln in $localNames) {
                $bestLocal = 0.0
                foreach ($sa in $albums) {
                    $saName = $null
                    if ($sa.PSObject.Properties.Match('Name').Count -gt 0) { $saName = $sa.Name }
                    elseif ($sa.PSObject.Properties.Match('name').Count -gt 0) { $saName = $sa.name }
                    if ($null -eq $saName) { continue }
                    $score = Get-StringSimilarity -String1 $ln -String2 ([string]$saName)
                    if ($score -gt $bestLocal) { $bestLocal = $score }
                }
                $sum += [double]$bestLocal
                
                # Boost for near-exact matches after normalization
                try {
                    $nl = ConvertTo-ComparableName -Name $ln
                    $match = ($albums | ForEach-Object {
                        $nsa = $null
                        if ($_.PSObject.Properties.Match('Name').Count -gt 0) { $nsa = [string]$_.Name } 
                        elseif ($_.PSObject.Properties.Match('name').Count -gt 0) { $nsa = [string]$_.name }
                        if ($nsa) { ConvertTo-ComparableName -Name $nsa } else { $null }
                    }) | Where-Object { $_ -eq $nl } | Select-Object -First 1
                    if ($match) { $sum += 0.5 }
                } catch { }
            }
            if ($sum -gt $bestScoreSum) { $bestScoreSum = [double]$sum; $bestCand = $cand }
        }
        
        if ($bestCand -and $bestScoreSum -ge 0) {
            $selectedArtist = $bestCand
            Write-Verbose ("Selected artist by catalog evaluation: {0} (aggregate={1})" -f $selectedArtist.Name, ([math]::Round($bestScoreSum,2)))
        }
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
        Write-Verbose ("Candidate evaluation failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
    }
    
    return [PSCustomObject]@{ SelectedArtist = $selectedArtist }
}

function Get-ArtistRenameProposal {
    <#
    .SYNOPSIS
    Determines if an artist folder should be renamed based on the selected artist.
    
    .DESCRIPTION
    Evaluates whether the current artist folder name should be changed to match
    the selected Spotify artist name, considering selection confidence.
    
    .OUTPUTS
    PSCustomObject with RenameNeeded, ProposedName, and TargetPath properties.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CurrentPath,
        
        [Parameter(Mandatory)]
        $SelectedArtist,
        
        [Parameter(Mandatory)]
        [string]$SelectionSource
    )
    
    $folderArtistName = Split-Path -Leaf -Path $CurrentPath
    $renameNeeded = $false
    $proposedName = $null
    $targetPath = $null
    
    if ($SelectedArtist.Name -and -not [string]::Equals($folderArtistName, $SelectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
        # Only propose artist rename when selection is inferred/evaluated (not a weak top search guess)
        if ($SelectionSource -in @('inferred','evaluated')) {
            $renameNeeded = $true
            $proposedName = ConvertTo-SafeFileName -Name $SelectedArtist.Name
            
            # Compute target path for display and WhatIf map
            try {
                $currentArtistPath = [string]$CurrentPath
                $targetPath = Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $proposedName
            } catch { }
            Write-Verbose ("Proposing artist folder rename: '{0}' -> '{1}'" -f $folderArtistName, $proposedName)
        } else {
            Write-Verbose ("Artist name differs but selection source '{0}' is not confident enough for rename proposal" -f $SelectionSource)
        }
    }
    
    return [PSCustomObject]@{
        RenameNeeded = $renameNeeded
        ProposedName = $proposedName
        TargetPath = $targetPath
    }
}