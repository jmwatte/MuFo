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

.PARAMETER SpotifyAlbumId
    Force processing to prefer a specific Spotify album when analyzing the selected artist.
    When supplied, MuFo retrieves that album directly instead of relying solely on search
    heuristics, helping manual corrections or regression scenarios.

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
        [double]$MinScore = 0.0,

    [Parameter(Mandatory = $false)]
    [string]$SpotifyAlbumId,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateDurations,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Strict', 'Normal', 'Relaxed', 'DataDriven')]
        [string]$DurationValidationLevel = 'Normal',

        [Parameter(Mandatory = $false)]
        [switch]$ShowDurationMismatches

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
            $showResultsParams = @{
                LogTo          = $LogTo
                MinScore       = $MinScore
                ShowEverything = $ShowEverything
                Detailed       = $Detailed
            }

            if ($PSBoundParameters.ContainsKey('Action') -and $Action) {
                $showResultsParams.Action = $Action
            }

            Show-MuFoLogResults @showResultsParams
            return
        }

        if (-not $PSCmdlet.ShouldProcess($Path, 'Invoke MuFo processing')) {
            return
        }

        # Main analysis logic always runs; actual changes are guarded by ShouldProcess
        $processingContext = Get-MuFoProcessingContext -Path $Path -ArtistAt $ArtistAt -ExcludeFolders $ExcludeFolders -ExcludedFoldersLoad $ExcludedFoldersLoad -ExcludedFoldersReplace:$ExcludedFoldersReplace -ExcludedFoldersShow:$ExcludedFoldersShow -Preview:$Preview -WhatIfPreference:$WhatIfPreference

        $effectiveExclusions = $processingContext.EffectiveExclusions
        $artistPaths = $processingContext.ArtistPaths

        if (-not $artistPaths -or $artistPaths.Count -eq 0) {
            Write-Warning "No artist paths found for ArtistAt '$ArtistAt' at '$Path'"
            return
        }

        foreach ($artistPath in $artistPaths) {
            Invoke-MuFoArtistProcessing -ArtistPath $artistPath `
                -EffectiveExclusions $effectiveExclusions `
                -DoIt $DoIt `
                -ConfidenceThreshold $ConfidenceThreshold `
                -SpotifyAlbumId $SpotifyAlbumId `
                -IncludeSingles:$IncludeSingles.IsPresent `
                -IncludeCompilations:$IncludeCompilations.IsPresent `
                -IncludeTracks:$IncludeTracks.IsPresent `
                -FixTags:$FixTags.IsPresent `
                -FixOnly $FixOnly `
                -DontFix $DontFix `
                -OptimizeClassicalTags:$OptimizeClassicalTags.IsPresent `
                -ValidateCompleteness:$ValidateCompleteness.IsPresent `
                -BoxMode:$BoxMode.IsPresent `
                -Preview:$processingContext.IsPreview `
                -Detailed:$Detailed.IsPresent `
                -ShowEverything:$ShowEverything.IsPresent `
                -ValidateDurations:$ValidateDurations.IsPresent `
                -DurationValidationLevel $DurationValidationLevel `
                -ShowDurationMismatches:$ShowDurationMismatches.IsPresent `
                -LogTo $LogTo `
                -ExcludedFoldersSave $ExcludedFoldersSave `
                -WhatIfPreference:$WhatIfPreference `
                -CallerCmdlet $PSCmdlet
        }
    }

    end {
        # Final memory cleanup for large collections
        $null = Add-MemoryOptimization -Phase 'End' -ForceCleanup:($PSCmdlet.MyInvocation.BoundParameters.Count -gt 0)
        
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}
