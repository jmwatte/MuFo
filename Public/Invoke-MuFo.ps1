function Invoke-MuFo {
    <#
.SYNOPSIS
    Validates and corrects music library folders and files using Spotify API.

.DESCRIPTION
    Invoke-MuFo scans a music library structure (Artist/Album/Tracks) and validates it against Spotify data.
    It can check artists, albums, and tracks, offering corrections for mismatches. Supports various modes
    for automation, manual confirmation, or smart application.

.PARAMETER Path
    The path to the music library folder to validate. Can be an artist folder, album folder, or root music directory.
    Defaults to current directory if not specified.

.PARAMETER DoIt
    The execution mode for applying changes:
    - 'Automatic': Apply all changes without prompting
    - 'Manual': Prompt for each change (Enter=accept, Esc=skip)
    - 'Smart': Auto-apply high-confidence matches, prompt for uncertain ones
    Default: Manual

.PARAMETER ConfidenceThreshold
    Minimum similarity score (0.0-1.0) to consider a match "confident". Used by Smart mode for automatic application.
    Lower values are more permissive, higher values require closer matches. Default: 0.6

.PARAMETER ArtistAt
    Specifies where artist folders are located relative to the current path:
    - 'Here': Current path contains artist folders
    - '1U'/'2U': Go up 1 or 2 levels to find artist folders
    - '1D'/'2D': Artist folders are 1 or 2 levels down
    Default: 'Here'

.PARAMETER ExcludeFolders
    Array of folder names or patterns to exclude from scanning. Supports wildcards:
    - Exact names: 'Bonus', 'Live'
    - Wildcards: 'E_*', '*_Live', 'Album?'
    - Character classes: 'Demo[0-9]', 'Track[A-Z]'

.PARAMETER ExcludedFoldersSave
    Save current exclusion list to a JSON file for reuse. Specify the file path to create.

.PARAMETER ExcludedFoldersLoad
    Load exclusion list from a previously saved JSON file. Specify the file path to load.

.PARAMETER ExcludedFoldersReplace
    When loading exclusions, replace the current list instead of adding to it.

.PARAMETER ExcludedFoldersShow
    Display the current exclusion list and exit without processing.

.PARAMETER LogTo
    Path to save detailed results in JSON format. Can be reviewed later with -ShowResults.

.PARAMETER IncludeSingles
    Include single releases when fetching album data from Spotify. Useful for comprehensive validation.

.PARAMETER IncludeCompilations
    Include compilation albums when fetching album data from Spotify. Helps validate various artist collections.

.PARAMETER IncludeTracks
    Enable track-level analysis and validation. Reads audio file tags and compares against Spotify track data.
    Provides detailed metrics about missing titles, track mismatches, and completeness.

.PARAMETER FixTags
    Enable writing and enhancement of audio file tags. Fills missing information and corrects inconsistencies.
    Requires TagLib-Sharp. Use with -WhatIf to preview changes before applying.

.PARAMETER FixOnly
    Limit tag fixing to specific types only (requires -FixTags):
    'Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists'
    Cannot be used with -DontFix. When specified, only these tag types will be modified.
    Default behavior fixes 'AlbumArtists' (80% of use cases). Use 'TrackArtists' for compilation albums.

.PARAMETER DontFix
    Exclude specific tag types from being fixed (requires -FixTags):
    'Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists'
    Cannot be used with -FixOnly. All other detected issues will be fixed.
    By default, only 'AlbumArtists' are fixed to preserve track-level performer information.

.PARAMETER OptimizeClassicalTags
    Apply special tag optimization for classical music (requires -FixTags):
    - Use composer as album artist when appropriate
    - Enhance conductor and performer information
    - Optimize track titles for classical compositions

.PARAMETER ValidateCompleteness
    Check for missing tracks, duplicates, and collection issues (works with -IncludeTracks).
    Compares local tracks against complete Spotify album to identify gaps.

.PARAMETER CreateMissingFilesLog
    Create log files listing missing tracks when completeness validation finds gaps.
    Generates timestamped log files in the current directory for each album with missing tracks.

.PARAMETER ValidateDurations
    Enable duration validation when matching albums and tracks. Compares track lengths between local files
    and Spotify data to improve matching accuracy and detect potential order issues.

.PARAMETER DurationValidationLevel
    Set the strictness of duration validation:
    - 'Strict': Tight tolerances (2% for percentage-based, strict empirical for DataDriven)
    - 'Normal': Balanced tolerances (5% or normal empirical) - Default
    - 'Relaxed': Loose tolerances (10% or relaxed empirical)
    - 'DataDriven': Use empirical thresholds from real music library analysis (recommended)

.PARAMETER ShowDurationMismatches
    Display detailed information about duration mismatches when validation is enabled.
    Shows which tracks have significant duration differences and provides recommendations.

.PARAMETER IncludeSpotifyObjects
    Include full Spotify album objects in the output records when available. This enables integration
    with other functions like Get-MuFoStats that can accept pre-fetched album data to avoid additional API calls.

.PARAMETER BoxMode
    Treat subfolders as discs of a box set, aggregating all tracks into one album for validation.
    Useful for multi-disc releases stored in separate folders.

.PARAMETER Preview
    Perform analysis only without prompting or making changes. Outputs structured objects for review.
    Use this for automation or when you want to examine results without interaction.

.PARAMETER ShowEverything
    Include all available details in output: ArtistId, AlbumType, Score, LocalPath, Decision, Reason, etc.
    Provides comprehensive information for debugging and detailed analysis.

.PARAMETER ShowResults
    Display results from a previous run's JSON log file (requires -LogTo). Allows filtering and review
    of past analysis without re-running the full validation process.

.PARAMETER Action
    Filter displayed results by action type when using -ShowResults:
    - 'rename': Show only items that would be renamed
    - 'skip': Show items that were skipped
    - 'error': Show items that encountered errors

.PARAMETER MinScore
    Filter results to show only items with confidence score >= specified value (0.0-1.0).
    Used with -ShowResults to focus on high-confidence matches.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music" -DoIt Smart
    
    Validates the entire music library using Smart mode, which automatically applies high-confidence matches
    and prompts for uncertain ones.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Pink Floyd" -ArtistAt Here -WhatIf
    
    Analyzes a specific artist folder without making changes, showing what would be renamed or corrected.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music" -ExcludeFolders "Bonus", "*_Live", "Demo*" -LogTo "results.json"
    
    Scans music library excluding bonus tracks, live albums, and demo releases, saving results for later review.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Albums" -ArtistAt 1U -IncludeTracks -FixTags -WhatIf
    
    Analyzes albums where artists are one level up, includes track validation, and previews tag fixes
    without applying changes.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Various" -IncludeCompilations -IncludeSingles -Preview
    
    Validates compilation albums and singles, outputting structured results without interaction.

.EXAMPLE
    Invoke-MuFo -ShowResults -LogTo "results.json" -Action "rename" -MinScore 0.8
    
    Reviews previous results, showing only items that would be renamed with confidence >= 80%.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\BoxSets" -BoxMode -IncludeTracks -ValidateCompleteness
    
    Validates box sets treating subfolders as discs, checking for missing tracks and completeness.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music" -FixTags -FixOnly "Titles", "TrackNumbers" -DoIt Automatic

    Automatically fixes only missing titles and track numbers without prompting.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Classical" -OptimizeClassicalTags -IncludeTracks -FixTags

    Optimizes tag organization for classical music with composer and conductor enhancements.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Progressive" -IncludeTracks -ValidateDurations -DurationValidationLevel DataDriven -ShowDurationMismatches

    Validates progressive rock albums using data-driven duration thresholds optimized for varied track lengths,
    displaying detailed information about any duration mismatches found.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music\Compilations" -FixTags -DontFix "TrackArtists" -DoIt Smart

    Fixes album-level information but preserves individual track artists for compilation albums.

.EXAMPLE
    Invoke-MuFo -Path "C:\Music" -FixTags -FixOnly "AlbumArtists" -WhatIf

    Preview album artist fixes without changing track-level performer information.

.EXAMPLE
    Invoke-MuFo -ExcludedFoldersLoad "my-exclusions.json" -Path "C:\Music" -DoIt Smart

    Loads previously saved exclusion patterns and validates library with Smart mode..EXAMPLE
    Invoke-MuFo -Path "C:\Music" -ConfidenceThreshold 0.9 -DoIt Smart -Verbose
    
    Uses high confidence threshold (90%) for Smart mode with detailed progress information.

.NOTES
    Author: jmwatte
    Requires: Spotify API access, TagLib-Sharp
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [Alias("FullName")]
    [string]$Path = ".",        [Parameter(Mandatory = $false)]
        [ValidateSet("Automatic", "Manual", "Smart")]
        [string]$DoIt = "Manual",

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.0, 1.0)]
        [double]$ConfidenceThreshold = 0.6,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Here', '1U', '2U', '1D', '2D')]
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
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists')]
        [string[]]$FixOnly = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists')]
        [string[]]$DontFix = @(),

        [Parameter(Mandatory = $false)]
        [switch]$OptimizeClassicalTags,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateCompleteness,

        [Parameter(Mandatory = $false)]
        [switch]$CreateMissingFilesLog,

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
        [ValidateSet('rename', 'skip', 'error')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [double]$MinScore = 0.0,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateDurations,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Strict', 'Normal', 'Relaxed', 'DataDriven')]
        [string]$DurationValidationLevel = 'Normal',

        [Parameter(Mandatory = $false)]
        [switch]$ShowDurationMismatches,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSpotifyObjects

    )

    begin {
        # Initialization code here
        Write-Verbose "Starting Invoke-MuFo with Path: $Path, DoIt: $DoIt, ConfidenceThreshold: $ConfidenceThreshold"
        # Connect to Spotify (validate Spotishell setup)
        if (Get-Module -ListAvailable -Name Spotishell) {
            Connect-SpotifyService
        }
        else {
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
                }
                else {
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

                        if (-not $Preview -and -not $WhatIfPreference) {
                            if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}' (LocalPath: {2})" -f $c.LocalAlbum, $c.ProposedName, $c.LocalPath)
                            }
                        }


                    }
                    else {
                        Write-Output $objFull
                        if (-not $Preview -and -not $WhatIfPreference) {
                            if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}' (LocalPath: {2})" -f $c.LocalAlbum, $c.ProposedName, $c.LocalPath)
                            }
                        }
                    }
                }
            }
            catch {
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

        # Detect if original path points to a specific album folder (when ArtistAt is not 'Here')
        # This allows processing only the specified album instead of all albums in the artist folder
        $specificAlbumPath = $null
        if ($ArtistAt -ne 'Here' -and (Test-Path -LiteralPath $Path -PathType Container)) {
            $parentPath = Split-Path $Path -Parent
            if ($parentPath -and $artistPaths -contains $parentPath) {
                $specificAlbumPath = $Path
                Write-Verbose "Detected specific album path: $specificAlbumPath"
            }
        }

        # Process each artist path
        foreach ($artistPath in $artistPaths) {
            $currentPath = $artistPath
            $localArtist = Split-Path $currentPath -Leaf
            Write-Verbose "Processing artist: $localArtist at $currentPath"



            # Enhanced artist search with variations (similar to Get-MuFoArtistReport)
            Write-Verbose "Searching Spotify for artist: $localArtist"
            
            # Special handling for "Various Artists" - compilation albums
            $isVariousArtists = $localArtist -eq 'Various Artists'
            if ($isVariousArtists) {
                Write-Verbose "Detected 'Various Artists' compilation - using special handling"
                # Create a synthetic artist object for Various Artists compilations
                $selectedArtist = [PSCustomObject]@{
                    Name = 'Various Artists'
                    Id = 'various-artists-compilation'  # Synthetic ID
                    Genres = @()
                    Popularity = 0
                    Followers = [PSCustomObject]@{ total = 0 }
                    Images = @()
                }
                $artistSelectionSource = 'compilation'
                $topMatches = @()  # No real matches for Various Artists
            }
            else {
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
                                $spotifyName = if ($match.Artist -and $match.Artist.Name) { $match.Artist.Name } else { "Unknown" }
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
            }
            
            if ($topMatches -or $isVariousArtists) {
                if (-not $isVariousArtists) {
                    Write-Verbose "Found $($topMatches.Count) potential matches on Spotify"
                }

                # Use refactored artist selection logic (skip for Various Artists compilations)
                if (-not $isVariousArtists) {
                    if (-not $effectiveExclusions) { $effectiveExclusions = @() }
                    if ($effectiveExclusions.Count -eq 0) { $effectiveExclusions = @('') }  # Non-empty array with empty string
                    $artistSelection = Get-ArtistSelection -LocalArtist $localArtist -TopMatches $topMatches -DoIt $DoIt -ConfidenceThreshold $ConfidenceThreshold -IsPreview $isPreview -CurrentPath $currentPath -EffectiveExclusions $effectiveExclusions -IncludeSingles $IncludeSingles -IncludeCompilations $IncludeCompilations
                    $selectedArtist = $artistSelection.SelectedArtist
                    $artistSelectionSource = $artistSelection.SelectionSource
                }

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
                        # If a specific album path was detected, only process that album
                        if ($specificAlbumPath) {
                            Write-Verbose "Processing specific album: $(Split-Path $specificAlbumPath -Leaf)"
                            $albumComparisons = Get-SingleAlbumComparison -Directory (Get-Item -LiteralPath $specificAlbumPath) -SelectedArtist $selectedArtist
                            $albumComparisons = @($albumComparisons)  # Convert to array for consistency
                        }
                        else {
                            $albumComparisons = Get-AlbumComparisons -CurrentPath $currentPath -SelectedArtist $selectedArtist -EffectiveExclusions $effectiveExclusions
                        }
                        
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
                                    # Get track information that was added by Add-TrackInformationToComparisons
                                    $scanPaths = if ($BoxMode -and (Get-ChildItem -LiteralPath $c.LocalPath -Directory -ErrorAction SilentlyContinue)) {
                                        Get-ChildItem -LiteralPath $c.LocalPath -Directory | Select-Object -ExpandProperty FullName
                                    }
                                    else {
                                        # Auto-detect format-separated folders (FLAC/, APE/, MP3/, etc.)
                                        $subDirs = Get-ChildItem -LiteralPath $c.LocalPath -Directory -ErrorAction SilentlyContinue
                                        $formatDirs = $subDirs | Where-Object {
                                            $_.Name -in @('FLAC', 'APE', 'MP3', 'M4A', 'OGG', 'WAV', 'WMA') -or
                                            $_.Name -match '^(FLAC|APE|MP3|M4A|OGG|WAV|WMA)$'
                                        }
                                        
                                        if ($formatDirs) {
                                            # Use format-separated subfolders
                                            $formatDirs | Select-Object -ExpandProperty FullName
                                        }
                                        else {
                                            # Use the album folder directly (normal case)
                                            @($c.LocalPath)
                                        }
                                    }
                                    $tracks = @()
                                    foreach ($p in $scanPaths) {
                                        $tracks += Get-AudioFileTags -Path $p -IncludeComposer -ShowProgress
                                    }
                                    
                                    $missingTitle = ($tracks | Where-Object { -not $_.Title }).Count
                                    $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue $missingTitle

                                    # Duration validation if enabled
                                    if ($ValidateDurations -and $c.SpotifyAlbum -and $tracks.Count -gt 0) {
                                        try {
                                            Write-Verbose "Performing duration validation for album: $($c.LocalAlbumName)"
                                            $durationValidation = Test-AlbumDurationConsistency -AlbumPath $c.LocalPath -SpotifyAlbumData $c.SpotifyAlbum -ShowWarnings $ShowDurationMismatches -ValidationLevel $DurationValidationLevel
                                            
                                            if ($durationValidation) {
                                                # Enhance album confidence based on duration validation
                                                $originalConfidence = if ($c.ConfidenceScore) { $c.ConfidenceScore } else { 0.5 }
                                                $durationConfidence = $durationValidation.Summary.AverageConfidence / 100
                                                
                                                # Weighted combination: 70% original matching, 30% duration validation
                                                $enhancedConfidence = [math]::Round(($originalConfidence * 0.7) + ($durationConfidence * 0.3), 3)
                                                
                                                $c | Add-Member -NotePropertyName DurationValidation -NotePropertyValue $durationValidation -Force
                                                $c | Add-Member -NotePropertyName OriginalConfidence -NotePropertyValue $originalConfidence -Force
                                                $c | Add-Member -NotePropertyName DurationConfidence -NotePropertyValue $durationConfidence -Force
                                                $c | Add-Member -NotePropertyName EnhancedConfidence -NotePropertyValue $enhancedConfidence -Force
                                                
                                                # Update the main confidence score with enhanced value
                                                $c.ConfidenceScore = $enhancedConfidence
                                                
                                                Write-Verbose "Duration validation complete. Original: $($originalConfidence), Duration: $($durationConfidence), Enhanced: $($enhancedConfidence)"
                                            }
                                        }
                                        catch {
                                            Write-Warning "Duration validation failed for album $($c.LocalAlbumName): $($_.Exception.Message)"
                                        }
                                    }

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

                                    # Safety check: Warn about mixed audio formats that could cause track numbering issues
                                    $skipTagEnhancement = $false
                                    if ($FixTags -and $tracks.Count -gt 0) {
                                        $audioFiles = $tracks | Where-Object { $_.Format -and $_.Format -ne '' }
                                        $formats = $audioFiles | Group-Object Format | Select-Object -ExpandProperty Name

                                        if ($formats.Count -gt 1) {
                                            Write-Warning "⚠️ Mixed audio formats detected in '$($c.LocalAlbum)': $($formats -join ', ')"
                                            Write-Host "   This can cause track numbering issues. Consider separating formats into different folders." -ForegroundColor Yellow
                                            Write-Host "   Use .\Reorganize-MusicFormats.ps1 to automatically separate formats." -ForegroundColor Cyan

                                            # Ask user if they want to skip tag enhancement for this album
                                            if (-not $Force) {
                                                $response = Read-Host "Continue with tag enhancement anyway? (y/N)"
                                                if ($response -notmatch '^[Yy]') {
                                                    Write-Host "Skipping tag enhancement for '$($c.LocalAlbum)'" -ForegroundColor Gray
                                                    $skipTagEnhancement = $true
                                                }
                                            }
                                        }
                                    }

                                    # Tag enhancement if requested
                                    if ($FixTags -and $tracks.Count -gt 0 -and -not $skipTagEnhancement) {
                                        Write-Verbose "Enhancing tags for: $($c.LocalPath)"
                                        
                                        $tagParams = @{
                                            Path   = $c.LocalPath
                                            WhatIf = $WhatIfPreference
                                        }
                                        
                                        # Pass tag fixing parameters to Set-AudioFileTags
                                        if ($FixOnly.Count -gt 0) { $tagParams.FixOnly = $FixOnly }
                                        if ($DontFix.Count -gt 0) { $tagParams.DontFix = $DontFix }
                                        if ($OptimizeClassicalTags) { $tagParams.OptimizeClassicalTags = $true }
                                        if ($ValidateCompleteness) { $tagParams.ValidateCompleteness = $true }
                                        if ($CreateMissingFilesLog) { $tagParams.CreateMissingFilesLog = $true }
                                        
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
                            
                            # OPTIMIZATION: Batch process Spotify track validation for all albums at once
                            # This replaces individual API calls with efficient batching, caching, and rate limiting
                            Write-Verbose "Starting optimized Spotify track validation for $($albumComparisons.Count) albums"
                            $albumComparisons = Optimize-SpotifyTrackValidation -Comparisons $albumComparisons -ShowProgress:$($albumComparisons.Count -gt 20)
                        }

                        # Display summary; later we'll wire -DoIt rename/apply
                        # Threshold used for decisions and rename map
                        $goodThreshold = [double]$ConfidenceThreshold

                        # Prepare decisions and emit structured objects
                        $records = @()
                        $processedCount = 0
                        foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
                            $processedCount++
                            
                            # Periodic memory monitoring for large collections
                            if ($albumComparisons.Count -gt 500 -and ($processedCount % 100) -eq 0) {
                                $null = Add-MemoryOptimization -Phase 'Progress'
                            }
                            $decision = 'skip'
                            $reason = ''
                            switch ($DoIt) {
                                'Automatic' { if ($c.MatchScore -ge $goodThreshold -and $c.ProposedName) { $decision = 'rename' } else { $reason = 'below-threshold-or-no-proposal' } }
                                'Smart' { if ($c.MatchScore -ge $goodThreshold -and $c.ProposedName) { $decision = 'rename' } else { $decision = 'prompt'; $reason = if ($c.ProposedName) { 'manual-confirmation' } else { 'no-proposal' } } }
                                'Manual' { $decision = if ($c.ProposedName) { 'prompt' } else { 'skip' }; if (-not $c.ProposedName) { $reason = 'no-proposal' } }
                            }
                            $rec = [ordered]@{
                                Artist        = $selectedArtist.Name
                                ArtistId      = $selectedArtist.Id
                                ArtistSource  = $artistSelectionSource
                                LocalArtist   = $localArtist
                                LocalFolder   = $c.LocalAlbum
                                LocalAlbum    = $c.LocalNorm
                                SpotifyAlbum  = $c.MatchName
                                AlbumType     = $c.MatchType
                                Score         = $c.MatchScore
                                LocalPath     = $c.LocalPath
                                NewFolderName = $c.ProposedName
                                Decision      = $decision
                                Reason        = $reason
                                SpotifyAlbumObject = if ($IncludeSpotifyObjects -and $c.MatchedItem -and $c.MatchedItem.Item) { $c.MatchedItem.Item } else { $null }
                                SpotifyAlbumId = if ($c.MatchedItem -and $c.MatchedItem.Item -and $c.MatchedItem.Item.id) { $c.MatchedItem.Item.id } else { $null }
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
                                # Add Spotify webpage link if available
                                if ($objFull.SpotifyAlbumId) {
                                    Write-Host "Found at: https://open.spotify.com/album/$($objFull.SpotifyAlbumId)" -ForegroundColor Cyan
                                }
                                # Check if this album needs renaming and display message immediately
                                if ([string]::Equals($objFull.LocalFolder, $objFull.NewFolderName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                    Write-NothingToRenameMessage
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
                                        $parentPath = Split-Path -Path $c.LocalPath -Parent
                                        $renameMap[[string]$c.LocalPath] = Join-Path -Path $parentPath -ChildPath ([string]$c.ProposedName)
                                    }
                                }
                            }
                            if ($renameMap.Count -gt 0) {
                                Write-RenameOperation -RenameMap $renameMap -Mode 'WhatIf'
                            }
                            else {
                                # Check if artist rename is suggested but albums don't need renaming
                                if ($localArtist -ne $selectedArtist.Name) {
                                    Write-ArtistRenameMessage -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name
                                }
                                else {
                                    # If nothing to rename, check for equal-name cases and surface that clearly
                                    $equalCases = $albumComparisons | Where-Object { $_.ProposedName -and [string]::Equals($_.LocalAlbum, $_.ProposedName, [StringComparison]::InvariantCultureIgnoreCase) }
                                    if ($equalCases) {
                                        # Individual "Nothing to Rename" messages are now displayed per album above
                                        Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $equalCases[0].LocalAlbum, $equalCases[0].ProposedName)
                                    }
                                    else {
                                        Write-WhatIfMessage -Message "No rename candidates at the current threshold."
                                        if ($currentPath) {
                                            Write-ClickableFilePath -Path $currentPath -Label "Folder" -Color "Gray"
                                        }
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
                                    if (-not $c.ProposedName) { $message = 'no-proposal'; $outcomes += [PSCustomObject]@{ LocalFolder = $c.LocalAlbum; LocalPath = $c.LocalPath; NewFolderName = $c.ProposedName; Action = $action; Reason = $message; Score = $c.MatchScore; SpotifyAlbum = $c.MatchName }; continue }
                                    if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) { 
                                        # Check if artist rename is suggested but this album doesn't need renaming
                                        if ($artistRenameName -and $localArtist -cne $selectedArtist.Name) {
                                            # around line ~817
                                            $reason = if (-not $Preview -and -not $WhatIfPreference) { 'No rename needed' } else { 'WhatIf Will rename ' }
                                            Write-AlbumNoRenameNeeded -LocalAlbum $c.LocalAlbum -LocalArtist $localArtist -SpotifyArtist $selectedArtist.Name -Reason $reason      
                                        }
                                        Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $c.LocalAlbum, $c.ProposedName); $message = 'already-matching'; $outcomes += [PSCustomObject]@{ LocalFolder = $c.LocalAlbum; LocalPath = $c.LocalPath; NewFolderName = $c.ProposedName; Action = $action; Reason = $message; Score = $c.MatchScore; SpotifyAlbum = $c.MatchName }; continue 
                                    }
                                    $currentPath = [string]$c.LocalPath
                                    $parentPath = Split-Path -Path $currentPath -Parent
                                    $targetPath = Join-Path -Path $parentPath -ChildPath $c.ProposedName
                                    if (Test-Path -LiteralPath $targetPath) { Write-Warning ("Skip rename: Target already exists: {0}" -f $targetPath); $message = 'target-exists'; $outcomes += [PSCustomObject]@{ LocalFolder = $c.LocalAlbum; LocalPath = $c.LocalPath; NewFolderName = $c.ProposedName; Action = $action; Reason = $message; Score = $c.MatchScore; SpotifyAlbum = $c.MatchName }; continue }

                                    $shouldRename = $false
                                    switch ($DoIt) {
                                        'Automatic' { $shouldRename = ($c.MatchScore -ge $goodThreshold) }
                                        'Smart' { if ($c.MatchScore -ge $goodThreshold) { $shouldRename = $true } else { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } } }
                                        'Manual' { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } }
                                    }
                                    if ($shouldRename) {
                                        if ($PSCmdlet.ShouldProcess($currentPath, ("Rename to '{0}'" -f $c.ProposedName))) {
                                            Rename-Item -LiteralPath $currentPath -NewName $c.ProposedName -ErrorAction Stop
                                            Write-Verbose ("Renamed: '{0}' -> '{1}'" -f $c.LocalAlbum, $c.ProposedName)
                                            $action = 'rename'; $message = 'renamed'
                                        }
                                    }
                                    else {
                                        Write-Verbose ("Skipped rename for '{0}' (score {1})" -f $c.LocalAlbum, $c.MatchScore)
                                        $action = 'skip'; $message = if ($c.MatchScore -ge $goodThreshold) { 'user-declined' } else { 'below-threshold' }
                                    }
                                    $outcomes += [PSCustomObject]@{ LocalFolder = $c.LocalAlbum; LocalPath = $c.LocalPath; NewFolderName = $c.ProposedName; Action = $action; Reason = $message; Score = $c.MatchScore; SpotifyAlbum = $c.MatchName }
                                }
                                catch { Write-Warning ("Rename failed for '{0}': {1}" -f $c.LocalAlbum, $_.Exception.Message); $outcomes += [PSCustomObject]@{ LocalFolder = $c.LocalAlbum; LocalPath = $c.LocalPath; NewFolderName = $c.ProposedName; Action = 'error'; Reason = $_.Exception.Message; Score = $c.MatchScore; SpotifyAlbum = $c.MatchName } }
                            }
                            # After album renames, perform artist folder rename if proposed
                            if ($artistRenameName) {
                                try {
                                    $currentArtistPath = [string]$currentPath
                                    $targetArtistPath = Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName
                                    if (Test-Path -LiteralPath $targetArtistPath) {
                                        Write-Warning ("Skip artist rename: Target already exists: {0}" -f $targetArtistPath)
                                    }
                                    else {
                                        if ($PSCmdlet.ShouldProcess($currentArtistPath, ("Rename artist folder to '{0}'" -f $artistRenameName))) {
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
                            # Print a concise map of performed renames
                            $performed = $outcomes | Where-Object { $_.Action -eq 'rename' }
                            if ($performed) {
                                $renameMap = [ordered]@{}
                                foreach ($r in $performed) { 
                                    $parentPath = Split-Path -Path $r.LocalPath -Parent
                                    $renameMap[[string]$r.LocalPath] = Join-Path -Path $parentPath -ChildPath ([string]$r.NewFolderName)
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
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $currentPath; Mode = $DoIt; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $outcomes }
                                    ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                                    Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                                }
                                catch { Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message) }
                            }
                        }
                        else {
                            # Preview-only logging
                            if ($LogTo) {
                                try {
                                    $dir = Split-Path -Parent -Path $LogTo
                                    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = $currentPath; Mode = 'Preview'; ConfidenceThreshold = $ConfidenceThreshold; ExcludedFolders = @($effectiveExclusions); Items = $records }
                                    ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $LogTo -Encoding utf8
                                    Write-Verbose ("Wrote JSON log: {0}" -f $LogTo)
                                }
                                catch { Write-Warning ("Failed to write log '{0}': {1}" -f $LogTo, $_.Exception.Message) }
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
                    Write-Warning "No artist selected"
                }

                # Save exclusions to disk if requested and processing was successful
                if ($ExcludedFoldersSave -and $selectedArtist) {
                    try {
                        $saveFile = if ($ExcludedFoldersSave) { Join-Path $storePath.Dir $ExcludedFoldersSave } else { $storePath.File }
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
        } # End foreach artistPath
    }

    end {
        # Final memory cleanup for large collections
        $null = Add-MemoryOptimization -Phase 'End' -ForceCleanup:($PSCmdlet.MyInvocation.BoundParameters.Count -gt 0)
        
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}
