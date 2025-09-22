function Invoke-MuFo {
<#
.SYNOPSIS
    Validates and corrects music library folders and files using Spotify API.

.DESCRIPTION
    Invoke-MuFo scans a music library structure (Artist/Album/Tracks) and validates it against Spotify data.
    It can check artists, albums, and tracks, offering corrections for mismatches. Supports various modes
    for automation, manual confirmation, or smart application.

.PARAMETER Path
    The path to the music library folder. Defaults to current directory.

.PARAMETER DoIt
    The mode for applying changes: Automatic, Manual, or Smart.

.PARAMETER ConfidenceThreshold
    Minimum similarity score [0..1] to consider a match "confident". Used by Smart mode and album colorization. Default 0.9.

.PARAMETER ArtistAt
    Specifies the relative folder level to locate the artist folder. Options: 'Here' (current path is artist), '1U'/'2U' (go up 1 or 2 levels), '1D'/'2D' (artists are 1 or 2 levels down). Default 'Here'.

.PARAMETER ExcludeFolders
    Folders to exclude from scanning. Supports exact names and wildcard patterns (*, ?, []).
    Examples: 'Bonus', 'E_*', '*_Live', 'Album?', 'Demo[0-9]', 'Track[A-Z]'

.PARAMETER LogTo
    Path to the log file for results.

.PARAMETER IncludeSingles
    Include single releases when fetching albums from provider.

.PARAMETER IncludeCompilations
    Include compilation releases when fetching albums from provider.

.PARAMETER IncludeTracks
    Include track tag inspection and validation metrics in the output. When enabled, also performs
    classical music analysis including composer detection, conductor identification, and organization suggestions.

.PARAMETER FixTags
    Enable tag writing and enhancement. Fills missing titles, track numbers, and optimizes classical music tags.

.PARAMETER FixOnly
    Only fix these specific tag types (requires -FixTags). Valid values: 'Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists'.
    Cannot be used together with -DontFix. When specified, only these tag types will be fixed.

.PARAMETER DontFix
    Exclude specific tag types from being fixed (requires -FixTags). Valid values: 'Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists'.
    Cannot be used together with -FixOnly. By default, -FixTags will fix all detected issues unless excluded here.

.PARAMETER OptimizeClassicalTags
    Optimize tags for classical music organization - composer as album artist, conductor info, etc. (requires -FixTags).

.PARAMETER ValidateCompleteness
    Check for missing tracks, duplicates, and other collection issues (works with -IncludeTracks).

.PARAMETER BoxMode
    Treat subfolders as discs of a box set, aggregating tracks from all subfolders into one album.

.PARAMETER AsObject
    [Deprecated] Replaced by default object output plus -ShowSummary/-Preview switches.

.PARAMETER Preview
    Perform analysis only and emit structured objects; do not prompt or rename. Use this to avoid WhatIf chatter.

.PARAMETER ShowSummary
    [Deprecated] Concise output and the rename map are now shown by default when using -WhatIf or -Preview.

.PARAMETER Detailed
    [Deprecated] Use -ShowEverything. When used with -Preview or -WhatIf, emit full object details instead of the concise view.

.PARAMETER ShowEverything
    Emit full object details (ArtistId, AlbumType, Score, LocalPath, Decision, Reason, etc.).

.PARAMETER ShowResults
    Display results from a previous run's JSON log file. Requires -LogTo.

.PARAMETER Action
    Filter results by action: 'rename', 'skip', or 'error'.

.PARAMETER MinScore
    Filter results to show only items with score >= MinScore.

.PARAMETER Verbose
    Provides detailed output.

.PARAMETER Debug
    Provides debug information.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music" -DoIt Smart

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Artist" -LogTo "results.json" -WhatIf
    Review the analysis results and then view them later with:
    Invoke-MuFo -ShowResults -LogTo "results.json"

.EXAMPLE
    Invoke-MuFo -ShowResults -LogTo "results.json" -Action "rename"
    Show only albums that would be renamed from previous analysis.

.EXAMPLE
    Invoke-MuFo -ShowResults -LogTo "results.json" -MinScore 0.9 -ShowEverything
    Show high-confidence matches with full details.

.EXAMPLE
    Invoke-MuFo -ShowResults -LogTo "results.json" -Action "error"
    Review any errors from previous run for troubleshooting.

.NOTES
    Author: jmwatte
    Requires: Spotify API access, TagLib-Sharp
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = ".",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Automatic", "Manual", "Smart")]
        [string]$DoIt = "Manual",

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.0,1.0)]
        [double]$ConfidenceThreshold = 0.6,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Here','1U','2U','1D','2D')]
        [string]$ArtistAt = 'Here',

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeFolders,

        [Parameter(Mandatory = $false)]
        [string]$ExcludedFoldersSave,

        [Parameter(Mandatory = $false)]
        [string]$ExcludedFoldersLoad,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludedFoldersReplace,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludedFoldersShow,

        [Parameter(Mandatory = $false)]
        [string]$LogTo,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSingles,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeCompilations,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeTracks,

        [Parameter(Mandatory = $false)]
        [switch]$FixTags,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$FixOnly = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$DontFix = @(),

        [Parameter(Mandatory = $false)]
        [switch]$OptimizeClassicalTags,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateCompleteness,

        [Parameter(Mandatory = $false)]
        [switch]$BoxMode,

        [Parameter(Mandatory = $false)]
        [switch]$Preview,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [switch]$ShowEverything,

        [Parameter(Mandatory = $false)]
        [switch]$ShowResults,

        [Parameter(Mandatory = $false)]
        [ValidateSet('rename','skip','error')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [double]$MinScore = 0.0

    )

    begin {
        # Initialization code here
        Write-Verbose "Starting Invoke-MuFo with Path: $Path, DoIt: $DoIt, ConfidenceThreshold: $ConfidenceThreshold"
        # Connect to Spotify (validate Spotishell setup)
        if (Get-Module -ListAvailable -Name Spotishell) {
            Connect-SpotifyService
        } else {
            Write-Warning "Spotishell module not found. Install-Module Spotishell to enable Spotify integration."
        }

        # Helper functions are now in Private modules
        # ConvertTo-SafeFileName and ConvertTo-ComparableName moved to Invoke-MuFo-OutputFormatting.ps1
        # Exclusions functions moved to Invoke-MuFo-Exclusions.ps1
    }

    process {
        # Parameter validation for tag enhancement
        if ($OptimizeClassicalTags -and -not $FixTags) {
            Write-Error "Tag enhancement switch (-OptimizeClassicalTags) requires -FixTags to be enabled."
            return
        }
        
        # FixOnly and DontFix are mutually exclusive
        if ($FixOnly.Count -gt 0 -and $DontFix.Count -gt 0) {
            Write-Error "Cannot specify both -FixOnly and -DontFix parameters. Use one or the other."
            return
        }
        
        if ($FixTags -and -not $IncludeTracks) {
            Write-Warning "-FixTags works best with -IncludeTracks enabled for comprehensive analysis"
        }
        
        # Handle -ShowResults mode
        if ($ShowResults) {
            if (-not $LogTo) {
                Write-Warning "-LogTo is required when using -ShowResults"
                return
            }
            if (-not (Test-Path $LogTo)) {
                Write-Warning "Log file '$LogTo' not found"
                return
            }
            try {
                $data = Get-Content -LiteralPath $LogTo -Encoding UTF8 | ConvertFrom-Json
                $allItems = $data.Items
                $originalCount = $allItems.Count
                
                # Apply filters
                $items = $allItems
                if ($Action) {
                    $items = $items | Where-Object { $_.Action -eq $Action }
                }
                if ($MinScore -gt 0) {
                    $items = $items | Where-Object { $_.Score -ge $MinScore }
                }
                
                # Display summary header
                Write-Host "`n=== MuFo Results Summary ===" -ForegroundColor Cyan
                Write-Host "Log file: $LogTo" -ForegroundColor Gray
                Write-Host "Generated: $($data.Timestamp)" -ForegroundColor Gray
                Write-Host "Original path: $($data.Path)" -ForegroundColor Gray
                Write-Host "Mode: $($data.Mode), Threshold: $($data.ConfidenceThreshold)" -ForegroundColor Gray
                
                # Summary statistics
                if ($originalCount -gt 0) {
                    $stats = $allItems | Group-Object -Property Action | Sort-Object Name
                    Write-Host "`nSummary Statistics:" -ForegroundColor Yellow
                    foreach ($stat in $stats) {
                        $color = switch ($stat.Name) {
                            'rename' { 'Green' }
                            'skip' { 'Yellow' }
                            'error' { 'Red' }
                            default { 'White' }
                        }
                        Write-Host "  $($stat.Name): $($stat.Count)" -ForegroundColor $color
                    }
                    
                    if ($Action -or $MinScore -gt 0) {
                        Write-Host "`nFiltered Results: $($items.Count) of $originalCount items" -ForegroundColor Cyan
                        if ($Action) { Write-Host "  Action filter: $Action" -ForegroundColor Gray }
                        if ($MinScore -gt 0) { Write-Host "  MinScore filter: $MinScore" -ForegroundColor Gray }
                    }
                } else {
                    Write-Host "No items found in log file." -ForegroundColor Yellow
                }
                
                if ($items.Count -gt 0) {
                    Write-Host "`n--- Results ---" -ForegroundColor Cyan
                }
                
                foreach ($item in $items) {
                    $wantFull = ($ShowEverything -or $Detailed)
                    if (-not $wantFull) {
                        $objDisplay = [PSCustomObject]([ordered]@{
                            LocalArtist   = $item.LocalArtist
                            SpotifyArtist = $item.Artist
                            LocalFolder   = $item.LocalFolder
                            LocalAlbum    = $item.LocalAlbum
                            SpotifyAlbum  = $item.SpotifyAlbum
                            NewFolderName = $item.NewFolderName
                            Decision      = $item.Decision
                            ArtistSource  = $item.ArtistSource
                        })
                        Write-Output $objDisplay
                    } else {
                        Write-Output $item
                    }
                }
            } catch {
                Write-Warning "Failed to read or parse log file '$LogTo': $($_.Exception.Message)"
            }
            return
        }

        # Main analysis logic always runs; actual changes are guarded by ShouldProcess
    $isPreview = $Preview -or $WhatIfPreference

            # Compute effective exclusions using refactored functions
            $effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders $ExcludeFolders -ExcludedFoldersLoad $ExcludedFoldersLoad -ExcludedFoldersReplace:$ExcludedFoldersReplace
            Write-Verbose "Final effective exclusions: $($effectiveExclusions -join ', ')"

            # Show exclusions if requested
            if ($ExcludedFoldersShow) {
                Show-Exclusions -EffectiveExclusions $effectiveExclusions -ExcludedFoldersLoad $ExcludedFoldersLoad
            }

            # Compute artist paths based on -ArtistAt
            $artistPaths = switch ($ArtistAt) {
                'Here' { @($Path) }
                '1U' {
                    $p = Split-Path $Path -Parent
                    if (-not $p) { Write-Warning "Cannot go up from '$Path'"; @() } else { @($p) }
                }
                '2U' {
                    $p = $Path
                    for ($i = 0; $i -lt 2; $i++) {
                        $p = Split-Path $p -Parent
                        if (-not $p) { Write-Warning "Cannot go up $($i+1) levels from '$Path'"; @(); break }
                    }
                    if ($p) { @($p) } else { @() }
                }
                '1D' {
                    Get-ChildItem -Directory $Path | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | Select-Object -ExpandProperty FullName
                }
                '2D' {
                    Get-ChildItem -Directory $Path | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | ForEach-Object {
                        Get-ChildItem -Directory $_.FullName | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | Select-Object -ExpandProperty FullName
                    }
                }
            }
            if ($artistPaths.Count -eq 0) {
                Write-Warning "No artist paths found for ArtistAt '$ArtistAt' at '$Path'"
                return
            }

            # Process each artist path
            foreach ($artistPath in $artistPaths) {
                $currentPath = $artistPath
                $localArtist = Split-Path $currentPath -Leaf
                Write-Verbose "Processing artist: $localArtist at $currentPath"



            # Search Spotify for the artist and get top matches
            $topMatches = Get-SpotifyArtist -ArtistName $localArtist
            if ($topMatches) {
                Write-Verbose "Found $($topMatches.Count) potential matches on Spotify"

                # Use refactored artist selection logic
                $artistSelection = Get-ArtistSelection -LocalArtist $localArtist -TopMatches $topMatches -DoIt $DoIt -ConfidenceThreshold $ConfidenceThreshold -IsPreview $isPreview -CurrentPath $currentPath -EffectiveExclusions $effectiveExclusions -IncludeSingles $IncludeSingles -IncludeCompilations $IncludeCompilations
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
                    $artistRename = Get-ArtistRenameProposal -CurrentPath $currentPath -SelectedArtist $selectedArtist -SelectionSource $artistSelectionSource
                    $artistRenameName = $artistRename.ProposedName
                    $artistRenameTargetPath = $artistRename.TargetPath

                    # Proceed with album verification: compare local folder names to Spotify artist albums
                    try {
                        # Use refactored album processing logic
                        $albumComparisons = Get-AlbumComparisons -CurrentPath $currentPath -SelectedArtist $selectedArtist -EffectiveExclusions $effectiveExclusions
                        
                        # Add track information if requested
                        if ($IncludeTracks) {
                            Add-TrackInformationToComparisons -AlbumComparisons $albumComparisons -BoxMode $BoxMode
                            
                            # Enhanced track processing for classical music, completeness validation, and tag enhancement
                            foreach ($c in $albumComparisons) {
                                try {
                                    # Get track information that was added by Add-TrackInformationToComparisons
                                    $scanPaths = if ($BoxMode -and (Get-ChildItem -LiteralPath $c.LocalPath -Directory -ErrorAction SilentlyContinue)) {
                                        Get-ChildItem -LiteralPath $c.LocalPath -Directory | Select-Object -ExpandProperty FullName
                                    } else {
                                        @($c.LocalPath)
                                    }
                                    $tracks = @()
                                    foreach ($p in $scanPaths) {
                                        $tracks += Get-AudioFileTags -Path $p -IncludeComposer
                                    }
                                    
                                    $missingTitle = ($tracks | Where-Object { -not $_.Title }).Count
                                    $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue $missingTitle

                                    # Classical music analysis
                                    $classicalTracks = $tracks | Where-Object { $_.IsClassical -eq $true }
                                    $c | Add-Member -NotePropertyName ClassicalTracks -NotePropertyValue $classicalTracks.Count
                                    
                                    if ($classicalTracks.Count -gt 0) {
                                        $composers = $classicalTracks | Where-Object { $_.Composer } | Group-Object Composer | Sort-Object Count -Descending
                                        $primaryComposer = if ($composers.Count -gt 0) { $composers[0].Name } else { $null }
                                        $c | Add-Member -NotePropertyName PrimaryComposer -NotePropertyValue $primaryComposer -Force
                                        $c | Add-Member -NotePropertyName SuggestedClassicalArtist -NotePropertyValue $classicalTracks[0].SuggestedAlbumArtist
                                        
                                        # Conductor analysis
                                        $conductors = $classicalTracks | Where-Object { $_.Conductor } | Group-Object Conductor | Sort-Object Count -Descending
                                        if ($conductors.Count -gt 0) {
                                            $c | Add-Member -NotePropertyName PrimaryConductor -NotePropertyValue $conductors[0].Name
                                        }
                                    }

                                    # Completeness validation if requested
                                    if ($ValidateCompleteness) {
                                        Write-Verbose "Validating album completeness for: $($c.LocalPath)"
                                        $spotifyAlbum = if ($c.MatchedItem -and $c.MatchedItem.Item) { $c.MatchedItem.Item } else { $null }
                                        $completenessResult = Test-AudioFileCompleteness -Path $c.LocalPath -SpotifyAlbum $spotifyAlbum -CheckAudioQuality -CheckFileNaming -SuggestFixes
                                        $c | Add-Member -NotePropertyName CompletenessAnalysis -NotePropertyValue $completenessResult
                                    }

                                    # Tag enhancement if requested
                                    if ($FixTags -and $tracks.Count -gt 0) {
                                        Write-Verbose "Enhancing tags for: $($c.LocalPath)"
                                        
                                        $tagParams = @{
                                            Path = $c.LocalPath
                                            WhatIf = $WhatIfPreference
                                        }
                                        
                                        # Pass tag fixing parameters to Set-AudioFileTags
                                        if ($FixOnly.Count -gt 0) { $tagParams.FixOnly = $FixOnly }
                                        if ($DontFix.Count -gt 0) { $tagParams.DontFix = $DontFix }
                                        if ($OptimizeClassicalTags) { $tagParams.OptimizeClassicalTags = $true }
                                        if ($ValidateCompleteness) { $tagParams.ValidateCompleteness = $true }
                                        
                                        # Add Spotify album data if available
                                        if ($c.MatchedItem -and $c.MatchedItem.Item) {
                                            $tagParams.SpotifyAlbum = $c.MatchedItem.Item
                                        }
                                        
                                        if ($LogTo) {
                                            $tagLogPath = $LogTo -replace '\.(json|log)$', '-tags.$1'
                                            $tagParams.LogTo = $tagLogPath
                                        }
                                        
                                        $tagResults = Set-AudioFileTags @tagParams
                                        $c | Add-Member -NotePropertyName TagEnhancementResults -NotePropertyValue $tagResults
                                        
                                        # Update track count after enhancements
                                        $enhancedTracks = Get-AudioFileTags -Path $c.LocalPath -IncludeComposer
                                        $updatedMissingTitles = ($enhancedTracks | Where-Object { -not $_.Title }).Count
                                        $c | Add-Member -NotePropertyName TracksWithMissingTitleAfterFix -NotePropertyValue $updatedMissingTitles -Force
                                    }

                                    # Compute mismatches against Spotify if album matched
                                    $mismatches = 0
                                    if ($c.MatchName -and $c.MatchScore -gt 0) {
                                        # Find the matched album object
                                        $matchedAlbum = $c.MatchedItem
                                        if ($matchedAlbum -and $matchedAlbum.Item.Id) {
                                            $spotifyTracks = Get-SpotifyAlbumTracks -AlbumId $matchedAlbum.Item.Id
                                            foreach ($localTrack in $tracks) {
                                                if (-not $localTrack.Title) { continue }
                                                $bestScore = 0
                                                foreach ($spotifyTrack in $spotifyTracks) {
                                                    $score = Get-StringSimilarity -String1 $localTrack.Title -String2 $spotifyTrack.Name
                                                    if ($score -gt $bestScore) { $bestScore = $score }
                                                }
                                                if ($bestScore -lt 0.8) { $mismatches++ }
                                            }
                                        }
                                    }
                                    $c | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue $mismatches

                                    if ($ShowEverything) {
                                        $c | Add-Member -NotePropertyName Tracks -NotePropertyValue $tracks
                                    }
                                } catch {
                                    Write-Warning "Failed to read tracks for '$($c.LocalPath)': $($_.Exception.Message)"
                                    $c | Add-Member -NotePropertyName TrackCountLocal -NotePropertyValue 0 -Force
                                    $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue 0
                                    $c | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue 0
                                    if ($ShowEverything) {
                                        $c | Add-Member -NotePropertyName Tracks -NotePropertyValue @()
                                    }
                                }
                            }
                        }

                        # Display summary; later we'll wire -DoIt rename/apply
                        # Threshold used for decisions and rename map
                        $goodThreshold = [double]$ConfidenceThreshold

                        # Prepare decisions and emit structured objects
                        $records = @()
                        foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
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
                            # Default to concise view unless -ShowEverything/-Detailed is set
                            $wantFull = ($ShowEverything -or $Detailed)
                            if (-not $wantFull) {
                                $objDisplay = [PSCustomObject]([ordered]@{
                                    LocalArtist   = $folderArtistName
                                    SpotifyArtist = $objFull.Artist
                                    LocalFolder   = $objFull.LocalFolder
                                    LocalAlbum    = $objFull.LocalAlbum
                                    SpotifyAlbum  = $objFull.SpotifyAlbum
                                    NewFolderName = $objFull.NewFolderName
                                    Decision      = $objFull.Decision
                                    ArtistSource  = $objFull.ArtistSource
                                })
                                Write-Output $objDisplay
                            } else {
                                Write-Output $objFull
                            }
                            # Intentionally suppress verbose per-album UI line to avoid redundancy when objects are emitted.
                        }

                        # If running in WhatIf or -Preview, always print a concise rename map by default
                        $isPreview = $Preview -or $WhatIfPreference
                        if ($isPreview) {
                            $renameMap = [ordered]@{}
                            # Include artist folder rename if applicable
                            if ($artistRenameName) {
                                $currentArtistPath = [string]$currentPath
                                $targetArtistPath = if ($artistRenameTargetPath) { $artistRenameTargetPath } else { Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName }
                                $renameMap[$currentArtistPath] = $targetArtistPath
                            }
                            foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
                                if ($c.ProposedName -and -not [string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                    # Only include confident suggestions (at/above threshold)
                                    if ($c.MatchScore -ge $goodThreshold) {
                                        $renameMap[[string]$c.LocalPath] = (Join-Path -Path $currentPath -ChildPath ([string]$c.ProposedName))
                                    }
                                }
                            }
                            if ($renameMap.Count -gt 0) {
                                Write-RenameOperation -RenameMap $renameMap -Mode 'WhatIf'
                            } else {
                                # Check if artist rename is suggested but albums don't need renaming
                                if ($localArtist -ne $selectedArtist.Name) {
                                    Write-ArtistRenameMessage -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                } else {
                                    # If nothing to rename, check for equal-name cases and surface that clearly
                                    $equalCases = $albumComparisons | Where-Object { $_.ProposedName -and [string]::Equals($_.LocalAlbum, $_.ProposedName, [StringComparison]::InvariantCultureIgnoreCase) }
                                    if ($equalCases) {
                                        foreach ($e in $equalCases) {
                                            # Check if artist rename is suggested but this album doesn't need renaming
                                            if ($localArtist -cne $selectedArtist.Name) {
                                                Write-AlbumNoRenameNeeded -LocalAlbum $e.LocalAlbum -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                            } else {
                                                Write-NothingToRenameMessage
                                            }
                                            Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $e.LocalAlbum, $e.ProposedName)
                                        }
                                    } else {
                                        Write-WhatIfMessage -Message "No rename candidates at the current threshold."
                                    }
                                }
                            }
                        }

                        # If Preview or WhatIf, skip renames entirely (clean output, no WhatIf chatter)
                        if (-not $Preview -and -not $WhatIfPreference) {
                            $outcomes = @()
                            foreach ($c in $albumComparisons) {
                                try {
                                    $action = 'skip'; $message = ''
                                    if (-not $c.ProposedName) { $message = 'no-proposal'; $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }; continue }
                                    if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) { 
                                        # Check if artist rename is suggested but this album doesn't need renaming
                                        if ($localArtist -cne $selectedArtist.Name) {
                                            Write-AlbumNoRenameNeeded -LocalAlbum $c.LocalAlbum -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                        } else {
                                            Write-NothingToRenameMessage
                                        }
                                        Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $c.LocalAlbum, $c.ProposedName); $message = 'already-matching'; $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }; continue }
                                    $currentPath = [string]$c.LocalPath
                                    $targetPath  = Join-Path -Path $currentPath -ChildPath $c.ProposedName
                                    if (Test-Path -LiteralPath $targetPath) { Write-Warning ("Skip rename: Target already exists: {0}" -f $targetPath); $message = 'target-exists'; $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }; continue }

                                    $shouldRename = $false
                                    switch ($DoIt) {
                                        'Automatic' { $shouldRename = ($c.MatchScore -ge $goodThreshold) }
                                        'Smart'     { if ($c.MatchScore -ge $goodThreshold) { $shouldRename = $true } else { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } } }
                                        'Manual'    { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } }
                                    }
                                    if ($shouldRename) {
                                        if ($PSCmdlet.ShouldProcess($currentPath, ("Rename to '{0}'" -f $c.ProposedName))) {
                                            Rename-Item -LiteralPath $currentPath -NewName $c.ProposedName -ErrorAction Stop
                                            Write-Verbose ("Renamed: '{0}' -> '{1}'" -f $c.LocalAlbum, $c.ProposedName)
                                            $action = 'rename'; $message = 'renamed'
                                        }
                                    } else {
                                        Write-Verbose ("Skipped rename for '{0}' (score {1})" -f $c.LocalAlbum, $c.MatchScore)
                                        $action = 'skip'; $message = if ($c.MatchScore -ge $goodThreshold) { 'user-declined' } else { 'below-threshold' }
                                    }
                                    $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }
                                } catch { Write-Warning ("Rename failed for '{0}': {1}" -f $c.LocalAlbum, $_.Exception.Message); $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action='error'; Reason=$_.Exception.Message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName } }
                            }
                            # After album renames, perform artist folder rename if proposed
                            if ($artistRenameName) {
                                try {
                                    $currentArtistPath = [string]$currentPath
                                    $targetArtistPath  = Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName
                                    if (Test-Path -LiteralPath $targetArtistPath) {
                                        Write-Warning ("Skip artist rename: Target already exists: {0}" -f $targetArtistPath)
                                    } else {
                                        if ($PSCmdlet.ShouldProcess($currentArtistPath, ("Rename artist folder to '{0}'" -f $artistRenameName))) {
                                            Rename-Item -LiteralPath $currentArtistPath -NewName $artistRenameName -ErrorAction Stop
                                            Write-Verbose ("Renamed artist folder: '{0}' -> '{1}'" -f (Split-Path -Leaf $currentArtistPath), $artistRenameName)
                                            $artistRenamePerformed = $true
                                            $artistRenameFrom = $currentArtistPath
                                            $artistRenameTo = $targetArtistPath
                                        }
                                    }
                                } catch {
                                    Write-Warning ("Artist folder rename failed: {0}" -f $_.Exception.Message)
                                }
                            }
                            # Print a concise map of performed renames
                            $performed = $outcomes | Where-Object { $_.Action -eq 'rename' }
                            if ($performed) {
                                $renameMap = [ordered]@{}
                                foreach ($r in $performed) { $renameMap[[string]$r.LocalPath] = (Join-Path -Path $currentPath -ChildPath ([string]$r.NewFolderName)) }
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
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $currentPath; Mode = $DoIt; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $outcomes }
                                    ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                                    Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                                } catch { Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message) }
                            }
                        } else {
                            # Preview-only logging
                            if ($LogTo) {
                                try {
                                    $dir = Split-Path -Parent -Path $LogTo
                                    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $currentPath; Mode = 'Preview'; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $records }
                                    ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                                    Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                                } catch { Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message) }
                            }
                        }
                    } catch {
                        $msg = $_.Exception.Message
                        $stack = $_.ScriptStackTrace
                        $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                        $innerText = if ($inner) { " | Inner: $inner" } else { '' }
                        $stackText = if ($stack) { " | Stack: $stack" } else { '' }
                        Write-Warning ("Album verification failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
                    }
                } else {
                    Write-Warning "No artist selected"
                }

                # Save exclusions to disk if requested and processing was successful
                if ($ExcludedFoldersSave -and $selectedArtist) {
                    try {
                        $saveFile = if ($ExcludedFoldersSave) { Join-Path $storePath.Dir $ExcludedFoldersSave } else { $storePath.File }
                        Write-ExcludedFoldersToDisk -FilePath $saveFile -ExcludedFolders $effectiveExclusions
                        Write-Verbose ("Saved exclusions to disk: {0} folders excluded" -f $effectiveExclusions.Count)
                    } catch {
                        Write-Warning ("Failed to save exclusions: {0}" -f $_.Exception.Message)
                    }
                }
            } else {
                Write-Warning "No matches found on Spotify for '$localArtist'"
            }
        } # End foreach artistPath
    }

    end {
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}
