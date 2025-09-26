function Invoke-MuFoArtistProcessing {
    <#
    .SYNOPSIS
        Processes a single artist folder during Invoke-MuFo execution.

    .DESCRIPTION
        Encapsulates the per-artist logic from Invoke-MuFo, including Spotify artist
        selection, album comparison, track analysis, tag updates, rename decisions,
        logging, and exclusion persistence. Outputs the same pipeline records that
        the public function previously emitted while keeping behavior unchanged.

    .PARAMETER ArtistPath
        Full path to the artist directory being processed.

    .PARAMETER EffectiveExclusions
        Array of exclusion patterns applied during processing.

    .PARAMETER DoIt
        Execution mode for rename flow: Automatic, Manual, or Smart.

    .PARAMETER ConfidenceThreshold
        Minimum score used when deciding rename actions.

    .PARAMETER IncludeSingles
        Include singles when enumerating Spotify albums.

    .PARAMETER IncludeCompilations
        Include compilation releases when enumerating Spotify albums.

    .PARAMETER IncludeTracks
        Enable track-level analysis and enrichment.

    .PARAMETER FixTags
        Enable tag enhancement when IncludeTracks is also specified.

    .PARAMETER FixOnly
        Restrict tag fixing to specific properties.

    .PARAMETER DontFix
        Skip fixing specific tag properties.

    .PARAMETER OptimizeClassicalTags
        Enable classical music specific tag adjustments.

    .PARAMETER ValidateCompleteness
        Perform track completeness analysis when IncludeTracks is enabled.

    .PARAMETER BoxMode
        Treat artist subfolders as discs in a box set.

    .PARAMETER Preview
        Indicates Preview mode is active.

    .PARAMETER Detailed
        Request detailed output objects.

    .PARAMETER ShowEverything
        Emit verbose record structures.

    .PARAMETER ValidateDurations
        Enable duration validation when analyzing tracks.

    .PARAMETER DurationValidationLevel
        Strictness level for duration validation.

    .PARAMETER ShowDurationMismatches
        Emit duration mismatch details when validation is enabled.

    .PARAMETER LogTo
        Path to the JSON log written after processing.

    .PARAMETER ExcludedFoldersSave
        Optional file name for persisting exclusions.

    .PARAMETER WhatIfPreference
        Indicates whether WhatIf mode is active for the caller.

    .PARAMETER CallerCmdlet
        PSCmdlet instance from the caller, used for ShouldProcess checks.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$ArtistPath,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]]$EffectiveExclusions,

        [Parameter(Mandatory)]
        [ValidateSet('Automatic', 'Manual', 'Smart')]
        [string]$DoIt,

        [Parameter(Mandatory)]
        [double]$ConfidenceThreshold,

        [Parameter()]
        [switch]$IncludeSingles,

        [Parameter()]
        [switch]$IncludeCompilations,

        [Parameter()]
        [switch]$IncludeTracks,

        [Parameter()]
        [switch]$FixTags,

        [Parameter()]
        [string[]]$FixOnly = @(),

        [Parameter()]
        [string[]]$DontFix = @(),

    [Parameter()]
    [string]$SpotifyAlbumId,

        [Parameter()]
        [switch]$OptimizeClassicalTags,

        [Parameter()]
        [switch]$ValidateCompleteness,

        [Parameter()]
        [switch]$BoxMode,

        [Parameter()]
        [switch]$Preview,

        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [switch]$ShowEverything,

        [Parameter()]
        [switch]$ValidateDurations,

        [Parameter()]
        [ValidateSet('Strict', 'Normal', 'Relaxed', 'DataDriven')]
        [string]$DurationValidationLevel = 'Normal',

        [Parameter()]
        [switch]$ShowDurationMismatches,

        [Parameter()]
        [string]$LogTo,

        [Parameter()]
        [string]$ExcludedFoldersSave,

        [Parameter()]
        [bool]$WhatIfPreference,

        [Parameter()]
        [System.Management.Automation.PSCmdlet]$CallerCmdlet
    )

    $artistPath = $ArtistPath
    $localArtist = Split-Path -Path $artistPath -Leaf
    Write-Verbose "Processing artist: $localArtist at $artistPath"

    $isPreview = $Preview -or $WhatIfPreference
    $storePath = Get-ExclusionsStorePath

    $effectiveExclusions = if ($EffectiveExclusions) { @($EffectiveExclusions) } else { @() }

    # Enhanced artist search with variations (similar to Get-MuFoArtistReport)
    Write-Verbose "Searching Spotify for artist: $localArtist"
    $topMatches = Get-SpotifyArtist -ArtistName $localArtist

    # If first search yields poor results, try variations (before "and", "&", etc.)
    if (-not $topMatches -or ($topMatches.Count -gt 0 -and $topMatches[0].Score -lt 70)) {
        $searchVariations = @()

        # Try part before common separators
        $separators = @(' and ', ' & ', ' featuring ', ' feat ', ' feat. ', ' ft ', ' ft. ', ' with ')
        foreach ($sep in $separators) {
            if ($localArtist -match [regex]::Escape($sep)) {
                $beforeSep = ($localArtist -split [regex]::Escape($sep), 2)[0].Trim()
                if ($beforeSep -and $beforeSep.Length -gt 2) {
                    $searchVariations += $beforeSep
                }

                # Special case: if separator is " and ", also try without "and" (e.g., "Afrika Bambaataa the Soul Sonic Force")
                if ($sep -eq ' and ') {
                    $withoutAnd = $localArtist -replace ' and ', ' '
                    if ($withoutAnd -ne $localArtist) {
                        $searchVariations += $withoutAnd.Trim()
                    }
                }
                break # Only try the first separator found
            }
        }

        # Try each variation and pick the best overall result
        foreach ($variation in $searchVariations) {
            Write-Verbose "  Trying variation: $variation"
            $variationMatches = Get-SpotifyArtist -ArtistName $variation

            if ($variationMatches -and $variationMatches.Count -gt 0) {
                # Recalculate score against original artist name
                foreach ($match in $variationMatches) {
                    $spotifyName = if ($match.Artist -and $match.Artist.Name) { $match.Artist.Name } else { 'Unknown' }
                    $variationScore = Get-StringSimilarity -String1 $variation -String2 $spotifyName
                    $originalScore = Get-StringSimilarity -String1 $localArtist -String2 $spotifyName

                    # If we have a very good match to the variation (main artist), boost the score
                    if ($variationScore -ge 0.9) {
                        # Use the higher of: original score or boosted variation score
                        $boostedScore = [Math]::Max($originalScore, ($variationScore * 0.8)) # 80% of perfect variation match
                        $match.Score = $boostedScore
                        Write-Verbose "    Boosted score for '$spotifyName': variation=$([math]::Round($variationScore,2)) -> final=$([math]::Round($boostedScore,2))"
                    }
                    else {
                        $match.Score = $originalScore
                    }
                }

                # If this variation gives better results, use them
                if (-not $topMatches -or ($variationMatches[0].Score -gt $topMatches[0].Score)) {
                    $topMatches = $variationMatches
                    Write-Verbose "  Using variation '$variation' - improved score to $($topMatches[0].Score)"
                }
            }
        }
    }

    if ($topMatches) {
        Write-Verbose "Found $($topMatches.Count) potential matches on Spotify"

        if (-not $effectiveExclusions) { $effectiveExclusions = @() }
        if ($effectiveExclusions.Count -eq 0) { $effectiveExclusions = @('') }  # Non-empty array with empty string

        $artistSelection = Get-ArtistSelection -LocalArtist $localArtist -TopMatches $topMatches -DoIt $DoIt -ConfidenceThreshold $ConfidenceThreshold -IsPreview $isPreview -CurrentPath $artistPath -EffectiveExclusions $effectiveExclusions -IncludeSingles:$IncludeSingles -IncludeCompilations:$IncludeCompilations
        $selectedArtist = $artistSelection.SelectedArtist
        $artistSelectionSource = $artistSelection.SelectionSource

        if ($selectedArtist) {
            Write-Verbose "Selected artist: $($selectedArtist.Name)"
            # If inferred and differs from folder artist name, hint possible typo
            if ($artistSelectionSource -eq 'inferred') {
                $folderArtist = $localArtist
                if (-not [string]::Equals($folderArtist, $selectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
                    Write-ArtistTypoWarning -FolderArtist $folderArtist -SpotifyArtist $selectedArtist.Name
                }
            }

            # Determine if artist folder should be renamed
            $artistRename = Get-ArtistRenameProposal -CurrentPath $artistPath -SelectedArtist $selectedArtist -SelectionSource $artistSelectionSource
            $artistRenameName = $artistRename.ProposedName
            $artistRenameTargetPath = $artistRename.TargetPath

            # Manual mode: List album candidates for user selection
            if ($DoIt -eq 'Manual' -and -not $SpotifyAlbumId) {
                Write-Host "Fetching album candidates for '$($selectedArtist.Name)'..." -ForegroundColor Cyan
                $albumComparisonsForSelection = Get-AlbumComparisons -CurrentPath $artistPath -SelectedArtist $selectedArtist -EffectiveExclusions $effectiveExclusions -ForcedAlbum $null

                if ($albumComparisonsForSelection.Count -eq 0) {
                    Write-Warning "No album candidates found for '$($selectedArtist.Name)'"
                    return
                }

                Write-Host "`nAlbum candidates for $localArtist ($($selectedArtist.Name)):" -ForegroundColor Yellow
                for ($i = 0; $i -lt $albumComparisonsForSelection.Count; $i++) {
                    $c = $albumComparisonsForSelection[$i]
                    $albumType = if ($c.MatchType) { " ($($c.MatchType))" } else { "" }
                    Write-Host "$($i+1). $($c.MatchName)$albumType - Score: $([math]::Round($c.MatchScore, 2))"
                }

                $validChoice = $false
                $chosenIndex = -1
                while (-not $validChoice) {
                    $choice = Read-Host "`nChoose album (1-$($albumComparisonsForSelection.Count)) or 0 to skip this artist"
                    if ($choice -match '^\d+$') {
                        $choiceNum = [int]$choice
                        if ($choiceNum -eq 0) {
                            Write-Host "Skipping album selection for this artist"
                            return
                        }
                        elseif ($choiceNum -ge 1 -and $choiceNum -le $albumComparisonsForSelection.Count) {
                            $chosenIndex = $choiceNum - 1
                            $validChoice = $true
                        }
                        else {
                            Write-Host "Invalid choice. Please enter a number between 0 and $($albumComparisonsForSelection.Count)" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
                    }
                }

                $chosen = $albumComparisonsForSelection[$chosenIndex]
                if ($chosen.MatchedItem -and $chosen.MatchedItem.Item -and $chosen.MatchedItem.Item.Id) {
                    $SpotifyAlbumId = $chosen.MatchedItem.Item.Id
                    Write-Host "Selected album: $($chosen.MatchName) (ID: $SpotifyAlbumId)" -ForegroundColor Green
                }
                else {
                    Write-Warning "Could not retrieve album ID for selected album. Proceeding without forced selection."
                }
            }

            $forcedAlbumWrapper = $null
            if ($SpotifyAlbumId) {
                try {
                    Write-Verbose "Spotify album override requested: $SpotifyAlbumId"
                    $rawAlbum = Get-Album -Id $SpotifyAlbumId -ErrorAction Stop
                    if ($rawAlbum) {
                        $albumName = if ($rawAlbum.PSObject.Properties.Match('Name').Count -gt 0) { [string]$rawAlbum.Name } elseif ($rawAlbum.PSObject.Properties.Match('name').Count -gt 0) { [string]$rawAlbum.name } else { $null }
                        $albumType = if ($rawAlbum.PSObject.Properties.Match('AlbumType').Count -gt 0) { $rawAlbum.AlbumType } elseif ($rawAlbum.PSObject.Properties.Match('album_type').Count -gt 0) { $rawAlbum.album_type } else { $null }
                        $releaseDate = if ($rawAlbum.PSObject.Properties.Match('ReleaseDate').Count -gt 0) { $rawAlbum.ReleaseDate } elseif ($rawAlbum.PSObject.Properties.Match('release_date').Count -gt 0) { $rawAlbum.release_date } else { $null }
                        $albumId = if ($rawAlbum.PSObject.Properties.Match('Id').Count -gt 0) { $rawAlbum.Id } elseif ($rawAlbum.PSObject.Properties.Match('id').Count -gt 0) { $rawAlbum.id } else { $SpotifyAlbumId }

                        $forcedAlbumWrapper = [pscustomobject]@{
                            AlbumName   = $albumName
                            Name        = $albumName
                            AlbumType   = $albumType
                            ReleaseDate = $releaseDate
                            Item        = $rawAlbum
                            Id          = $albumId
                            Source      = 'ForcedAlbumId'
                        }

                        if ($rawAlbum.PSObject.Properties.Match('Artists').Count -gt 0) {
                            $forcedAlbumWrapper | Add-Member -MemberType NoteProperty -Name Artists -Value $rawAlbum.Artists -Force
                        } elseif ($rawAlbum.PSObject.Properties.Match('artists').Count -gt 0) {
                            $forcedAlbumWrapper | Add-Member -MemberType NoteProperty -Name Artists -Value $rawAlbum.artists -Force
                        }

                        Write-Verbose ("Using forced Spotify album '{0}' ({1})" -f $albumName, $albumId)

                        if ($selectedArtist -and $selectedArtist.Id) {
                            $albumArtistIds = @()
                            if ($forcedAlbumWrapper.Item -and $forcedAlbumWrapper.Item.PSObject.Properties.Match('artists').Count -gt 0) {
                                $albumArtistIds = $forcedAlbumWrapper.Item.artists | ForEach-Object { $_.id }
                            } elseif ($forcedAlbumWrapper.Item -and $forcedAlbumWrapper.Item.PSObject.Properties.Match('Artists').Count -gt 0) {
                                $albumArtistIds = $forcedAlbumWrapper.Item.Artists | ForEach-Object { $_.Id }
                            }

                            if ($albumArtistIds -and ($albumArtistIds -notcontains $selectedArtist.Id)) {
                                Write-Warning "Forced album does not list the selected artist as a contributor. Proceeding anyway."
                            }
                        }
                    }
                } catch {
                    Write-Warning "Failed to retrieve Spotify album for ID ${SpotifyAlbumId}: $($_.Exception.Message)"
                }
            }

            try {
                # Use refactored album processing logic
                $albumComparisons = Get-AlbumComparisons -CurrentPath $artistPath -SelectedArtist $selectedArtist -EffectiveExclusions $effectiveExclusions -ForcedAlbum $forcedAlbumWrapper

                # Memory optimization for large collections
                $null = Add-MemoryOptimization -AlbumCount $albumComparisons.Count -Phase 'Start'
                $sizeRecommendations = Get-CollectionSizeRecommendations -AlbumCount $albumComparisons.Count -IncludeTracks:$IncludeTracks

                # Display warnings and recommendations for large collections
                foreach ($warning in $sizeRecommendations.Warnings) {
                    Write-Warning $warning
                }
                foreach ($recommendation in $sizeRecommendations.Recommendations) {
                    Write-Host "💡 $recommendation" -ForegroundColor Cyan
                }
                if ($sizeRecommendations.EstimatedProcessingMinutes -gt 5) {
                    Write-Host "⏱️ Estimated processing time: ~$($sizeRecommendations.EstimatedProcessingMinutes) minutes" -ForegroundColor Yellow
                }

                # Add track information if requested
                if ($IncludeTracks) {
                    Add-TrackInformationToComparisons -AlbumComparisons $albumComparisons -BoxMode $BoxMode

                    # Enhanced track processing for classical music, completeness validation, and tag enhancement
                    foreach ($c in $albumComparisons) {
                        try {
                            $scanPaths = if ($BoxMode -and (Get-ChildItem -LiteralPath $c.LocalPath -Directory -ErrorAction SilentlyContinue)) {
                                Get-ChildItem -LiteralPath $c.LocalPath -Directory | Select-Object -ExpandProperty FullName
                            }
                            else {
                                @($c.LocalPath)
                            }
                            $tracks = @()
                            foreach ($p in $scanPaths) {
                                $tracks += Get-AudioFileTags -Path $p -IncludeComposer -ShowProgress
                            }

                            $missingTitle = ($tracks | Where-Object { -not $_.Title }).Count
                            $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue $missingTitle

                            if ($ValidateDurations -and $c.SpotifyAlbum -and $tracks.Count -gt 0) {
                                try {
                                    Write-Verbose "Performing duration validation for album: $($c.LocalAlbumName)"
                                    $durationValidation = Test-AlbumDurationConsistency -AlbumPath $c.LocalPath -SpotifyAlbumData $c.SpotifyAlbum -ShowWarnings $ShowDurationMismatches -ValidationLevel $DurationValidationLevel

                                    if ($durationValidation) {
                                        $originalConfidence = if ($c.ConfidenceScore) { $c.ConfidenceScore } else { 0.5 }
                                        $durationConfidence = $durationValidation.Summary.AverageConfidence / 100

                                        $enhancedConfidence = [math]::Round(($originalConfidence * 0.7) + ($durationConfidence * 0.3), 3)

                                        $c | Add-Member -NotePropertyName DurationValidation -NotePropertyValue $durationValidation -Force
                                        $c | Add-Member -NotePropertyName OriginalConfidence -NotePropertyValue $originalConfidence -Force
                                        $c | Add-Member -NotePropertyName DurationConfidence -NotePropertyValue $durationConfidence -Force
                                        $c | Add-Member -NotePropertyName EnhancedConfidence -NotePropertyValue $enhancedConfidence -Force

                                        $c.ConfidenceScore = $enhancedConfidence

                                        Write-Verbose "Duration validation complete. Original: $($originalConfidence), Duration: $($durationConfidence), Enhanced: $($enhancedConfidence)"
                                    }
                                }
                                catch {
                                    Write-Warning "Duration validation failed for album $($c.LocalAlbumName): $($_.Exception.Message)"
                                }
                            }

                            $classicalTracks = $tracks | Where-Object { $_.IsClassical -eq $true }
                            $c | Add-Member -NotePropertyName ClassicalTracks -NotePropertyValue $classicalTracks.Count

                            if ($classicalTracks.Count -gt 0) {
                                $composers = $classicalTracks | Where-Object { $_.Composer } | Group-Object -Property Composer | Sort-Object -Property Count -Descending
                                $primaryComposer = if ($composers.Count -gt 0) { $composers[0].Name } else { $null }
                                $c | Add-Member -NotePropertyName PrimaryComposer -NotePropertyValue $primaryComposer -Force
                                $c | Add-Member -NotePropertyName SuggestedClassicalArtist -NotePropertyValue $classicalTracks[0].SuggestedAlbumArtist

                                $conductors = $classicalTracks | Where-Object { $_.Conductor } | Group-Object -Property Conductor | Sort-Object -Property Count -Descending
                                if ($conductors.Count -gt 0) {
                                    $c | Add-Member -NotePropertyName PrimaryConductor -NotePropertyValue $conductors[0].Name
                                }
                            }

                            if ($ValidateCompleteness) {
                                Write-Verbose "Validating album completeness for: $($c.LocalPath)"
                                $spotifyAlbum = if ($c.MatchedItem -and $c.MatchedItem.Item) { $c.MatchedItem.Item } else { $null }
                                $completenessResult = Test-AudioFileCompleteness -Path $c.LocalPath -SpotifyAlbum $spotifyAlbum -CheckAudioQuality -CheckFileNaming -SuggestFixes
                                $c | Add-Member -NotePropertyName CompletenessAnalysis -NotePropertyValue $completenessResult
                            }

                            if ($FixTags -and $tracks.Count -gt 0) {
                                Write-Verbose "Enhancing tags for: $($c.LocalPath)"

                                $tagParams = @{
                                    Path   = $c.LocalPath
                                    WhatIf = $WhatIfPreference
                                }

                                if ($FixOnly.Count -gt 0) { $tagParams.FixOnly = $FixOnly }
                                if ($DontFix.Count -gt 0) { $tagParams.DontFix = $DontFix }
                                if ($OptimizeClassicalTags) { $tagParams.OptimizeClassicalTags = $true }
                                if ($ValidateCompleteness) { $tagParams.ValidateCompleteness = $true }

                                if ($c.MatchedItem -and $c.MatchedItem.Item) {
                                    $tagParams.SpotifyAlbum = $c.MatchedItem.Item
                                }

                                if ($LogTo) {
                                    $tagLogPath = $LogTo -replace '\\.(json|log)$', '-tags.$1'
                                    $tagParams.LogTo = $tagLogPath
                                }

                                $tagResults = Set-AudioFileTags @tagParams
                                $c | Add-Member -NotePropertyName TagEnhancementResults -NotePropertyValue $tagResults

                                $enhancedTracks = Get-AudioFileTags -Path $c.LocalPath -IncludeComposer -ShowProgress
                                $updatedMissingTitles = ($enhancedTracks | Where-Object { -not $_.Title }).Count
                                $c | Add-Member -NotePropertyName TracksWithMissingTitleAfterFix -NotePropertyValue $updatedMissingTitles -Force
                            }

                            if ($ShowEverything) {
                                $c | Add-Member -NotePropertyName Tracks -NotePropertyValue $tracks
                            }
                        }
                        catch {
                            Write-Warning "Failed to read tracks for '$($c.LocalPath)': $($_.Exception.Message)"
                            $c | Add-Member -NotePropertyName TrackCountLocal -NotePropertyValue 0 -Force
                            $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue 0
                            $c | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue 0
                            if ($ShowEverything) {
                                $c | Add-Member -NotePropertyName Tracks -NotePropertyValue @()
                            }
                        }
                    }

                    Write-Verbose "Starting optimized Spotify track validation for $($albumComparisons.Count) albums"
                    $albumComparisons = Optimize-SpotifyTrackValidation -Comparisons $albumComparisons -ShowProgress:($albumComparisons.Count -gt 20)
                }

                $goodThreshold = [double]$ConfidenceThreshold
                $records = @()
                $processedCount = 0
                foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
                    $processedCount++

                    if ($albumComparisons.Count -gt 500 -and ($processedCount % 100) -eq 0) {
                        $null = Add-MemoryOptimization -Phase 'Progress'
                    }
                    $decision = 'skip'
                    $reason = ''
                    switch ($DoIt) {
                        'Automatic' { if ($c.MatchScore -ge $goodThreshold -and $c.ProposedName) { $decision = 'rename' } else { $reason = 'below-threshold-or-no-proposal' } }
                        'Smart'     { if ($c.MatchScore -ge $goodThreshold -and $c.ProposedName) { $decision = 'rename' } else { $decision = 'prompt'; $reason = if ($c.ProposedName) { 'manual-confirmation' } else { 'no-proposal' } } }
                        'Manual'    { $decision = if ($c.ProposedName) { 'prompt' } else { 'skip' }; if (-not $c.ProposedName) { $reason = 'no-proposal' } }
                    }
                    $rec = [ordered]@{
                        Artist        = $selectedArtist.Name
                        ArtistId      = $selectedArtist.Id
                        ArtistSource  = $artistSelectionSource
                        LocalFolder   = $c.LocalAlbum
                        LocalAlbum    = $c.LocalNorm
                        SpotifyAlbum  = $c.MatchName
                        AlbumType     = $c.MatchType
                        Score         = $c.MatchScore
                        LocalPath     = $c.LocalPath
                        NewFolderName = $c.ProposedName
                        Decision      = $decision
                        Reason        = $reason
                    }
                    if ($IncludeTracks) {
                        $rec['TrackCountLocal'] = $c.TrackCountLocal
                        $rec['TracksWithMissingTitle'] = $c.TracksWithMissingTitle
                        $rec['TracksMismatchedToSpotify'] = $c.TracksMismatchedToSpotify
                        if ($ShowEverything) {
                            $rec['Tracks'] = $c.Tracks
                        }
                    }
                    $objFull = [PSCustomObject]$rec
                    $records += $objFull
                    $wantFull = ($ShowEverything -or $Detailed)
                    if (-not $wantFull) {
                        $objDisplay = [PSCustomObject]([ordered]@{
                            LocalArtist   = $localArtist
                            SpotifyArtist = $objFull.Artist
                            LocalFolder   = $objFull.LocalFolder
                            LocalAlbum    = $objFull.LocalAlbum
                            SpotifyAlbum  = $objFull.SpotifyAlbum
                            NewFolderName = $objFull.NewFolderName
                            Decision      = $objFull.Decision
                            ArtistSource  = $objFull.ArtistSource
                        })
                        Write-Output $objDisplay
                    }
                    else {
                        Write-Output $objFull
                    }
                }

                $isPreviewMode = $Preview -or $WhatIfPreference
                if ($isPreviewMode) {
                    $renameMap = [ordered]@{}
                    if ($artistRenameName) {
                        $currentArtistPath = [string]$artistPath
                        $targetArtistPath = if ($artistRenameTargetPath) { $artistRenameTargetPath } else { Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName }
                        $renameMap[$currentArtistPath] = $targetArtistPath
                    }
                    foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
                        if ($c.ProposedName -and -not [string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                            if ($c.MatchScore -ge $goodThreshold) {
                                $renameMap[[string]$c.LocalPath] = Join-Path -Path $artistPath -ChildPath ([string]$c.ProposedName)
                            }
                        }
                    }
                    if ($renameMap.Count -gt 0) {
                        Write-RenameOperation -RenameMap $renameMap -Mode 'WhatIf'
                    }
                    else {
                        if ($localArtist -ne $selectedArtist.Name) {
                            Write-ArtistRenameMessage -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                        }
                        else {
                            $equalCases = $albumComparisons | Where-Object { $_.ProposedName -and [string]::Equals($_.LocalAlbum, $_.ProposedName, [StringComparison]::InvariantCultureIgnoreCase) }
                            if ($equalCases) {
                                foreach ($e in $equalCases) {
                                    if ($localArtist -cne $selectedArtist.Name) {
                                        Write-AlbumNoRenameNeeded -LocalAlbum $e.LocalAlbum -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                    }
                                    else {
                                        Write-NothingToRenameMessage
                                    }
                                    Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $e.LocalAlbum, $e.ProposedName)
                                }
                            }
                            else {
                                Write-WhatIfMessage -Message 'No rename candidates at the current threshold.'
                            }
                        }
                    }
                }

                if (-not $Preview -and -not $WhatIfPreference) {
                    $outcomes = @()
                    $artistRenamePerformed = $false
                    $artistRenameFrom = $null
                    $artistRenameTo = $null

                    foreach ($c in $albumComparisons) {
                        try {
                            $action = 'skip'
                            $message = ''
                            if (-not $c.ProposedName) {
                                $message = 'no-proposal'
                                $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                                continue
                            }
                            if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                if ($localArtist -cne $selectedArtist.Name) {
                                    Write-AlbumNoRenameNeeded -LocalAlbum $c.LocalAlbum -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                }
                                else {
                                    Write-NothingToRenameMessage
                                }
                                Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $c.LocalAlbum, $c.ProposedName)
                                $message = 'already-matching'
                                $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                                continue
                            }
                            $albumPath = [string]$c.LocalPath
                            $targetPath = Join-Path -Path (Split-Path -Parent -Path $albumPath) -ChildPath $c.ProposedName
                            if (Test-Path -LiteralPath $targetPath) {
                                Write-Warning ("Skip rename: Target already exists: {0}" -f $targetPath)
                                $message = 'target-exists'
                                $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                                continue
                            }

                            $shouldRename = $false
                            switch ($DoIt) {
                                'Automatic' { $shouldRename = ($c.MatchScore -ge $goodThreshold) }
                                'Smart'     { if ($c.MatchScore -ge $goodThreshold) { $shouldRename = $true } else { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } } }
                                'Manual'    { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } }
                            }
                            if ($shouldRename) {
                                if ($CallerCmdlet -and $CallerCmdlet.ShouldProcess($albumPath, ("Rename to '{0}'" -f $c.ProposedName))) {
                                    Rename-Item -LiteralPath $albumPath -NewName $c.ProposedName -ErrorAction Stop
                                    Write-Verbose ("Renamed: '{0}' -> '{1}'" -f $c.LocalAlbum, $c.ProposedName)
                                    $action = 'rename'
                                    $message = 'renamed'
                                }
                            }
                            else {
                                Write-Verbose ("Skipped rename for '{0}' (score {1})" -f $c.LocalAlbum, $c.MatchScore)
                                $action = 'skip'
                                $message = if ($c.MatchScore -ge $goodThreshold) { 'user-declined' } else { 'below-threshold' }
                            }
                            $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                        }
                        catch {
                            Write-Warning ("Rename failed for '{0}': {1}" -f $c.LocalAlbum, $_.Exception.Message)
                            $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action='error'; Reason=$_.Exception.Message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                        }
                    }

                    if ($artistRenameName) {
                        try {
                            $currentArtistPath = [string]$artistPath
                            $targetArtistPath  = Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName
                            if (Test-Path -LiteralPath $targetArtistPath) {
                                Write-Warning ("Skip artist rename: Target already exists: {0}" -f $targetArtistPath)
                            }
                            else {
                                if ($CallerCmdlet -and $CallerCmdlet.ShouldProcess($currentArtistPath, ("Rename artist folder to '{0}'" -f $artistRenameName))) {
                                    Rename-Item -LiteralPath $currentArtistPath -NewName $artistRenameName -ErrorAction Stop
                                    Write-Verbose ("Renamed artist folder: '{0}' -> '{1}'" -f (Split-Path -Leaf $currentArtistPath), $artistRenameName)
                                    $artistRenamePerformed = $true
                                    $artistRenameFrom = $currentArtistPath
                                    $artistRenameTo = $targetArtistPath
                                }
                            }
                        }
                        catch {
                            Write-Warning ("Artist folder rename failed: {0}" -f $_.Exception.Message)
                        }
                    }

                    $performed = $outcomes | Where-Object { $_.Action -eq 'rename' }
                    if ($performed) {
                        $renameMap = [ordered]@{}
                        foreach ($r in $performed) {
                            $renameMap[[string]$r.LocalPath] = Join-Path -Path (Split-Path -Parent -Path $r.LocalPath) -ChildPath ([string]$r.NewFolderName)
                        }
                        Write-RenameOperation -RenameMap $renameMap -Mode 'Performed'
                    }
                    if ($artistRenamePerformed) {
                        $artistMap = [ordered]@{ $artistRenameFrom = $artistRenameTo }
                        Write-RenameOperation -RenameMap $artistMap -Mode 'Performed'
                    }
                    if ($LogTo) {
                        try {
                            $dir = Split-Path -Parent -Path $LogTo
                            if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                            $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $artistPath; Mode = $DoIt; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $outcomes }
                            ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                            Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                        }
                        catch {
                            Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message)
                        }
                    }
                }
                elseif ($LogTo) {
                    try {
                        $dir = Split-Path -Parent -Path $LogTo
                        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                        $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $artistPath; Mode = 'Preview'; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $records }
                        ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                        Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                    }
                    catch {
                        Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message)
                    }
                }
            }
            catch {
                $msg = $_.Exception.Message
                $stack = $_.ScriptStackTrace
                $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                $innerText = if ($inner) { " | Inner: $inner" } else { '' }
                $stackText = if ($stack) { " | Stack: $stack" } else { '' }
                Write-Warning ("Album verification failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
            }
        }
        else {
            Write-Warning 'No artist selected'
        }

        if ($ExcludedFoldersSave -and $selectedArtist) {
            try {
                $saveFile = if ($ExcludedFoldersSave) { Join-Path -Path $storePath.Dir -ChildPath $ExcludedFoldersSave } else { $storePath.File }
                Write-ExcludedFoldersToDisk -FilePath $saveFile -ExcludedFolders $effectiveExclusions
                Write-Verbose ("Saved exclusions to disk: {0} folders excluded" -f $effectiveExclusions.Count)
            }
            catch {
                Write-Warning ("Failed to save exclusions: {0}" -f $_.Exception.Message)
            }
        }
    }
    else {
        Write-Warning "No matches found on Spotify for '$localArtist'"
    }
}
