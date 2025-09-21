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
    Folders to exclude from scanning. Supports exact names and wildcard patterns (* and ?).
    Examples: 'Bonus', 'E_*', '*_Live', 'Album?'

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

.PARAMETER DontFix
    Exclude specific tag types from being fixed (requires -FixTags). Valid values: 'Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists'.
    By default, -FixTags will fix all detected issues unless excluded here.

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
        function ConvertTo-SafeFileName {
            param([Parameter(Mandatory)][string]$Name)
            $invalid = [IO.Path]::GetInvalidFileNameChars()
            $chars = $Name.ToCharArray() | ForEach-Object { if ($invalid -contains $_) { ' ' } else { $_ } }
            $out = -join $chars
            $out = $out -replace '\s{2,}', ' '
            $out = $out.Trim().TrimEnd('.')
            return $out
        }
        function ConvertTo-ComparableName {
            param([Parameter(Mandatory)][string]$Name)
            $n = $Name.ToLowerInvariant().Trim()
            # Strip non-alphanumeric for robust equality checks
            return ($n -replace "[^a-z0-9]", '')
        }
        # Connect to Spotify (validate Spotishell setup)
        if (Get-Module -ListAvailable -Name Spotishell) {
            Connect-SpotifyService
        } else {
            Write-Warning "Spotishell module not found. Install-Module Spotishell to enable Spotify integration."
        }

        function Get-ExclusionsStorePath {
            $storeDir = Join-Path $PSScriptRoot 'Exclusions'
            $storeFile = Join-Path $storeDir 'excluded-folders.json'
            return [PSCustomObject]@{ Dir = $storeDir; File = $storeFile }
        }
        function Read-ExcludedFoldersFromDisk {
            param([Parameter(Mandatory)][string]$FilePath)
            try {
                if (-not (Test-Path -LiteralPath $FilePath)) { return @() }
                $json = Get-Content -LiteralPath $FilePath -Encoding UTF8 -Raw
                $data = $json | ConvertFrom-Json
                # Handle both array format and single-item format
                if ($data -is [array]) { 
                    return [string[]]$data 
                } elseif ($data -is [string]) {
                    return @([string]$data)
                } else { 
                    return @() 
                }
            } catch {
                Write-Warning "Failed to read exclusions from '$FilePath': $($_.Exception.Message)"
                return @()
            }
        }
        function Test-ExclusionMatch {
            param([string]$FolderName, [System.Collections.Generic.HashSet[string]]$Exclusions)
            if (-not $Exclusions -or $Exclusions.Count -eq 0) { return $false }
            foreach ($pattern in $Exclusions) {
                try {
                    if ($pattern.Contains('*') -or $pattern.Contains('?')) {
                        # Use wildcard matching
                        if ($FolderName -like $pattern) { return $true }
                    } else {
                        # Use exact case-insensitive matching for backwards compatibility
                        if ([string]::Equals($FolderName, $pattern, [StringComparison]::InvariantCultureIgnoreCase)) { return $true }
                    }
                } catch {
                    # If pattern is invalid, skip it
                    Write-Verbose ("Invalid exclusion pattern '{0}': {1}" -f $pattern, $_.Exception.Message)
                }
            }
            return $false
        }
        function Write-ExcludedFoldersToDisk {
            param([string]$FilePath, [string[]]$ExcludedFolders)
            try {
                $dir = Split-Path -Parent $FilePath
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                $payload = @{ ExcludedFolders = $ExcludedFolders; Timestamp = (Get-Date).ToString('o') }
                $payload | ConvertTo-Json -Depth 2 | Set-Content -LiteralPath $FilePath -Encoding UTF8
                Write-Verbose "Saved exclusions to '$FilePath'"
            } catch {
                Write-Warning "Failed to save exclusions to '$FilePath': $($_.Exception.Message)"
            }
        }
    }

    process {
        # Parameter validation for tag enhancement
        if ($OptimizeClassicalTags -and -not $FixTags) {
            Write-Error "Tag enhancement switch (-OptimizeClassicalTags) requires -FixTags to be enabled."
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
                $items = $data.Items
                if ($Action) {
                    $items = $items | Where-Object { $_.Action -eq $Action }
                }
                if ($MinScore -gt 0) {
                    $items = $items | Where-Object { $_.Score -ge $MinScore }
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

            # Compute effective exclusions
            $storePath = Get-ExclusionsStorePath
            $effectiveExclusions = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase)

            # First, add command-line exclusions if provided
            if ($ExcludeFolders) {
                $ExcludeFolders | ForEach-Object { $effectiveExclusions.Add($_) | Out-Null }
                Write-Verbose "Added command-line exclusions: $($ExcludeFolders -join ', ')"
            }
            
            # Then handle file-based exclusions
            if ($ExcludedFoldersLoad) {
                $loaded = if (Test-Path -LiteralPath $ExcludedFoldersLoad) {
                    $loadedResult = Read-ExcludedFoldersFromDisk -FilePath $ExcludedFoldersLoad
                    Write-Verbose "Loaded exclusions from file '$ExcludedFoldersLoad': $($loadedResult -join ', ')"
                    $loadedResult
                } else {
                    Write-Warning "Exclusion file not found: $ExcludedFoldersLoad"
                    @()
                }
                
                if ($ExcludedFoldersReplace) {
                    # Replace mode: clear existing exclusions and use only command line
                    $effectiveExclusions.Clear()
                    Write-Verbose "Replace mode: cleared existing exclusions"
                    if ($ExcludeFolders) {
                        $ExcludeFolders | ForEach-Object { $effectiveExclusions.Add($_) | Out-Null }
                        Write-Verbose "Replace mode: re-added command-line exclusions: $($ExcludeFolders -join ', ')"
                    }
                } else {
                    # Merge mode: add file exclusions to existing command-line exclusions
                    $loaded | ForEach-Object { $effectiveExclusions.Add($_) | Out-Null }
                    Write-Verbose "Merge mode: added file exclusions to existing ones"
                }
            }
            
            Write-Verbose "Final effective exclusions: $($effectiveExclusions -join ', ')"

            # Show exclusions if requested
            if ($ExcludedFoldersShow) {
                Write-Host "Effective Exclusions:" -ForegroundColor Cyan
                if ($effectiveExclusions.Count -gt 0) {
                    $effectiveExclusions | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                } else {
                    Write-Host "  (none)" -ForegroundColor White
                }
                Write-Host "Persisted Exclusions:" -ForegroundColor Cyan
                $persisted = Read-ExcludedFoldersFromDisk -FilePath $storePath.File
                if ($persisted.Count -gt 0) {
                    $persisted | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                } else {
                    Write-Host "  (none)" -ForegroundColor White
                }
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

            # Local helper: flatten Spotishell Search-Item results into a simple albums array
            function Get-AlbumItemsFromSearchResult {
                param([Parameter(Mandatory)]$Result)
                $albums = @()
                try {
                    if ($null -eq $Result) { return @() }
                    
                    $resultsToProcess = if ($Result -is [System.Array]) { $Result } else { @($Result) }

                    foreach ($p in $resultsToProcess) {
                        if ($null -eq $p) { continue }
                        
                        if ($p.PSObject.Properties.Match('Albums').Count -gt 0 -and $p.Albums) {
                            if ($p.Albums.PSObject.Properties.Match('Items').Count -gt 0 -and $p.Albums.Items) {
                                $albums += @($p.Albums.Items)
                            }
                        }
                        if ($p.PSObject.Properties.Match('Items').Count -gt 0 -and $p.Items) {
                            $albums += @($p.Items)
                        }
                    }
                } catch {
                    $msg = $_.Exception.Message
                    Write-Verbose ("Get-AlbumItemsFromSearchResult failed to parse result: {0}" -f $msg)
                }
                # Ensure flat, non-null array
                return @($albums | Where-Object { $_ })
            }

            # Search Spotify for the artist and get top matches
            $topMatches = Get-SpotifyArtist -ArtistName $localArtist
            if ($topMatches) {
                Write-Verbose "Found $($topMatches.Count) potential matches on Spotify"

                $selectedArtist = $null
                $artistSelectionSource = 'search'
                switch ($DoIt) {
                    "Automatic" {
                        $selectedArtist = $topMatches[0].Artist
                        $artistSelectionSource = 'search'
                        Write-Verbose "Automatically selected: $($selectedArtist.Name)"
                    }
                    "Manual" {
                        if ($localAlbumDirs.Count -eq 0) {
                            Write-Verbose "No album directories found, will use artist inference"
                            $selectedArtist = $null
                        } elseif (-not $isPreview) {
                            # Prompt user to choose (skip prompts in Preview/WhatIf)
                            for ($i = 0; $i -lt $topMatches.Count; $i++) {
                                Write-Host "$($i + 1). $($topMatches[$i].Artist.Name) (Score: $([math]::Round($topMatches[$i].Score, 2)))"
                            }
                            $choice = Read-Host "Select artist (1-$($topMatches.Count)) [Enter=1, S=skip]"
                            if (-not $choice) {
                                $selectedArtist = $topMatches[0].Artist
                                $artistSelectionSource = 'search'
                            } elseif ($choice -match '^(?i)s(kip)?$' -or $choice -match '^0$') {
                                # skip
                            } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $topMatches.Count) {
                                $selectedArtist = $topMatches[[int]$choice - 1].Artist
                            }
                        } else {
                            # In WhatIf/Preview, pick the top match for analysis so we still produce results
                            $selectedArtist = $topMatches[0].Artist
                            $artistSelectionSource = 'search'
                            Write-Verbose "Preview/WhatIf: assuming top search match '$($selectedArtist.Name)' for analysis."
                        }
                    }
                    "Smart" {
                        if ($topMatches[0].Score -ge $ConfidenceThreshold) {
                            $selectedArtist = $topMatches[0].Artist
                            Write-Verbose "Smart selected: $($selectedArtist.Name)"
                        } else {
                            # Low confidence: defer to inference first; we may prompt later if still unresolved
                            Write-Verbose "Low confidence. Deferring to album-based inference before any prompt."
                        }
                    }
                }

                if (-not $selectedArtist) {
                    # Fallback: infer likely artist from local album folder names
                    try {
                        $localAlbumDirs = Get-ChildItem -LiteralPath $currentPath -Directory -ErrorAction SilentlyContinue
                        $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions) }
                        $localNames = @()
                        foreach ($d in $localAlbumDirs) {
                            $n = [string]$d.Name
                            $nn = $n -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
                            if (-not [string]::IsNullOrWhiteSpace($nn)) { $localNames += $nn }
                        }
                        # Quick path: use the first local album name to infer directly from top album match
                        if ($localNames.Count -gt 0) {
                            $primary = $localNames[0]
                            # Extract year from first album folder for targeted search
                            $primaryYear = $null
                            if ($localAlbumDirs -and $localAlbumDirs.Count -gt 0) {
                                $firstDir = $localAlbumDirs[0].Name
                                $ym = [regex]::Match($firstDir, '^[\(\[]?(?<year>\d{4})[\)\]]?')
                                if ($ym.Success) { $primaryYear = $ym.Groups['year'].Value }
                            }
                            
                            $query = if ($primaryYear) {
                                "artist:`"$localArtist`" album:`"$primary`" year:$primaryYear"
                            } else {
                                "artist:`"$localArtist`" album:`"$primary`""
                            }
                            $quick = Get-SpotifyAlbumMatches -Query $query -AlbumName $primary -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($quick -and $quick.Artists -and $quick.Artists.Count -gt 0) {
                                $qa = $quick.Artists[0]
                                if ((Get-StringSimilarity -String1 $localArtist -String2 $qa.Name) -ge 0.8) {
                                    $selectedArtist = [PSCustomObject]@{ Name=[string]$qa.Name; Id=[string]$qa.Id }
                                    $artistSelectionSource = 'inferred'
                                    Write-Verbose ("Quick-inferred artist from album '{0}': {1}" -f $primary, $selectedArtist.Name)
                                }
                            } else {
                                # Quick fallback using combined All search
                                try {
                                    $q = "{0} {1}" -f $localArtist, $primary
                                    Write-Verbose ("Search-Item All query (quick): '{0}'" -f $q)
                                    $all = Search-Item -Type All -Query $q -ErrorAction Stop
                                    $albums = Get-AlbumItemsFromSearchResult -Result $all
                                    # Score albums by similarity to local album name and choose best
                                    $scored = @()
                                    $normLocal = ConvertTo-ComparableName -Name $primary
                                    foreach ($i in $albums) {
                                        $nm = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                                        if ([string]::IsNullOrWhiteSpace($nm)) { continue }
                                        $s = 0.0
                                        try { $s = Get-StringSimilarity -String1 $primary -String2 $nm } catch { $s = 0.0 }
                                        # Boost exact normalized name match
                                        try {
                                            $nn = ConvertTo-ComparableName -Name $nm
                                            if ($nn -eq $normLocal) { $s += 1.0 }
                                            else {
                                                # Penalize common variant tags if not present in local
                                                $nnWords = $nm.ToLowerInvariant()
                                                $localWords = $primary.ToLowerInvariant()
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
                                        $primaryTokens = ($primary.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 })
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
                                            $artistSelectionSource = 'inferred'
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
                                # If still not selected, try phrase album searches as a last resort
                                if (-not $selectedArtist) {
                                    try {
                                        $albums = @()
                                        $q1 = '"{0}"' -f $primary
                                        Write-Verbose ("Search-Item Album query (phrase): {0}" -f $q1)
                                        $r1 = Search-Item -Type Album -Query $q1 -ErrorAction Stop
                                        if ($r1) { $albums += (Get-AlbumItemsFromSearchResult -Result $r1) }
                                        if (-not $albums -or $albums.Count -eq 0) {
                                            $q2 = '"{0} {1}"' -f $localArtist, $primary
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
                                                try { $s = Get-StringSimilarity -String1 $primary -String2 $nm } catch { $s = 0.0 }
                                                $scored += [PSCustomObject]@{ AlbumName=$nm; Score=[double]$s; Item=$i }
                                            }
                                            $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
                                            if ($best -and $best.Item -and $best.Item.Artists -and $best.Item.Artists.Count -gt 0 -and $best.Score -ge 0.3) {
                                                $fa = $best.Item.Artists[0]
                                                $san = if ($fa.PSObject.Properties.Match('Name').Count) { [string]$fa.Name } elseif ($fa.PSObject.Properties.Match('name').Count) { [string]$fa.name } else { $null }
                                                $said = if ($fa.PSObject.Properties.Match('Id').Count) { [string]$fa.Id } elseif ($fa.PSObject.Properties.Match('id').Count) { [string]$fa.id } else { $null }
                                                if ($san) {
                                                    $selectedArtist = [PSCustomObject]@{ Name=$san; Id=$said }
                                                    $artistSelectionSource = 'inferred'
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
                                }
                            }
                        }
                        # Only run voting if we still don't have a selected artist after quick/phrase inference
                        if ($selectedArtist) {
                            Write-Verbose ("Artist already selected by quick inference ('{0}'); skipping album-vote inference." -f $selectedArtist.Name)
                        } else {
                            Write-Verbose "Starting artist voting inference process"
                            # Run the full voting inference since no quick match was found
                            $artistVotes = @{}
                        }
                        foreach ($ln in $localNames) {
                            if ($selectedArtist) { break }
                            # Try both album-only and combined artist+album queries to improve recall
                            # Extract year from current album name for targeted search
                            $lnYear = $null
                            $lym = [regex]::Match($ln, '^[\(\[]?(?<year>\d{4})[\)\]]?')
                            if ($lym.Success) { $lnYear = $lym.Groups['year'].Value }
                            
                            $albumQuery = if ($lnYear) {
                                "artist:`"$localArtist`" album:`"$($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','')`" year:$lnYear"
                            } else {
                                "artist:`"$localArtist`" album:`"$($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','')`""
                            }
                            $m1 = Get-SpotifyAlbumMatches -Query $albumQuery -AlbumName ($ln -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*','') -ErrorAction SilentlyContinue
                            # Also try a combined All-type query via Search-Item directly to mirror user's successful approach
                            $m3 = @()
                            try {
                                $q = "{0} {1}" -f $localArtist, $ln
                                Write-Verbose ("Search-Item All query: '{0}'" -f $q)
                                $all = Search-Item -Type All -Query $q -ErrorAction Stop
                                $albums = Get-AlbumItemsFromSearchResult -Result $all
                                foreach ($i in $albums) {
                                    $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                                    $score = Get-StringSimilarity -String1 $ln -String2 $name
                                    $artists = @()
                                    if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                                        foreach ($a in $i.Artists) {
                                            $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                                            $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                                            if ($an) { $artists += [PSCustomObject]@{ Name=$an; Id=$aid } }
                                        }
                                    }
                                    $m3 += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$artists }
                                }
                            } catch {
                                $msg = $_.Exception.Message
                                $stack = $_.ScriptStackTrace
                                $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                                $innerText = if ($inner) { " | Inner: $inner" } else { '' }
                                $stackText = if ($stack) { " | Stack: $stack" } else { '' }
                                Write-Verbose ("Search-Item All failed: {0}{1}{2}" -f $msg, $innerText, $stackText)
                            }
                            # Add phrase-based album matches too
                            $m4 = @(); $m5 = @()
                            try {
                                $q1 = '"{0}"' -f $ln
                                Write-Verbose ("Search-Item Album query (phrase): {0}" -f $q1)
                                $r1 = Search-Item -Type Album -Query $q1 -ErrorAction Stop
                                $albums1 = Get-AlbumItemsFromSearchResult -Result $r1
                                foreach ($i in $albums1) {
                                    $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                                    $score = Get-StringSimilarity -String1 $ln -String2 $name
                                    $arts = @(); if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) { foreach ($a in $i.Artists) { $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }; $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }; if ($an) { $arts += [PSCustomObject]@{ Name=$an; Id=$aid } } } }
                                    $m4 += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$arts }
                                }
                                $q2 = '"{0} {1}"' -f $localArtist, $ln
                                Write-Verbose ("Search-Item Album query (artist+phrase): {0}" -f $q2)
                                $r2 = Search-Item -Type Album -Query $q2 -ErrorAction Stop
                                $albums2 = Get-AlbumItemsFromSearchResult -Result $r2
                                foreach ($i in $albums2) {
                                    $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                                    $score = Get-StringSimilarity -String1 $ln -String2 $name
                                    $arts = @(); if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) { foreach ($a in $i.Artists) { $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }; $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }; if ($an) { $arts += [PSCustomObject]@{ Name=$an; Id=$aid } } } }
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
                                                $artistSimilarity = Get-StringSimilarity -String1 $localArtist -String2 $a.Name
                                                Write-Verbose "Artist similarity between '$localArtist' and '$($a.Name)': $artistSimilarity"
                                                if ($artistSimilarity -ge 0.7) {
                                                    if (-not $artistVotes.ContainsKey($a.Name)) { $artistVotes[$a.Name] = [PSCustomObject]@{ Name=$a.Name; Id=$a.Id; Votes=0; BestScore=0.0 } }
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
                                if ($isPreview -or $DoIt -eq 'Automatic' -or ($DoIt -eq 'Smart' -and $inferred.BestScore -ge [Math]::Min(1.0, $ConfidenceThreshold))) {
                                    $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id }
                                    $artistSelectionSource = 'inferred'
                                    Write-Verbose ("Inferred artist from albums: {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
                                } else {
                                    if (-not $Preview -and -not $WhatIfPreference) {
                                        Write-Host ("Likely artist based on albums: {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
                                        $resp = Read-Host ("Use inferred artist? [Y/n]")
                                        if (-not $resp -or $resp -match '^(?i)y(es)?$') { $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id }; $artistSelectionSource = 'inferred' }
                                    } else {
                                        # In preview, use the inferred artist if it has reasonable confidence
                                        if ($inferred.BestScore -ge 0.7) {
                                            $selectedArtist = [PSCustomObject]@{ Name=$inferred.Name; Id=$inferred.Id }
                                            $artistSelectionSource = 'inferred'
                                            Write-Verbose ("Preview: Using inferred artist {0} (votes={1}, bestScore={2})" -f $inferred.Name, $inferred.Votes, ([math]::Round($inferred.BestScore,2)))
                                        }
                                    }
                                }
                            }
                        }
                    } catch { Write-Verbose ("Artist inference failed: {0}" -f $_.Exception.Message) }
                }

                # If still not selected and Smart mode, offer manual selection only when not in Preview/WhatIf
                if (-not $selectedArtist -and $DoIt -eq 'Smart' -and -not $isPreview) {
                    Write-Verbose "No artist after inference. Switching to manual selection."
                    for ($i = 0; $i -lt $topMatches.Count; $i++) {
                        Write-Host "$($i + 1). $($topMatches[$i].Artist.Name) (Score: $([math]::Round($topMatches[$i].Score, 2)))"
                    }
                    $choice = Read-Host "Select artist (1-$($topMatches.Count)) [Enter=1, S=skip]"
                    if (-not $choice) {
                        $selectedArtist = $topMatches[0].Artist
                    } elseif ($choice -match '^(?i)s(kip)?$' -or $choice -match '^0$') {
                        # skip
                    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $topMatches.Count) {
                        $selectedArtist = $topMatches[[int]$choice - 1].Artist
                    }
                }

                # Evaluate top search candidates against local album folders to pick best-fit artist (helps WhatIf/Preview too)
                if (-not $selectedArtist -and $topMatches -and $topMatches.Count -gt 0) {
                    try {
                        # Gather local album names (normalized)
                        $localAlbumDirs = Get-ChildItem -LiteralPath $currentPath -Directory -ErrorAction SilentlyContinue
                        $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions) }
                        $localNames = @()
                        foreach ($d in $localAlbumDirs) {
                            $n = [string]$d.Name
                            $nn = $n -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
                            if (-not [string]::IsNullOrWhiteSpace($nn)) { $localNames += $nn }
                        }
                        $bestCand = $null; $bestScoreSum = -1.0
                        foreach ($tm in $topMatches) {
                            $cand = $tm.Artist
                            if (-not $cand -or -not $cand.Id) { continue }
                            $albums = @()
                            try { $albums = Get-SpotifyArtistAlbums -ArtistId $cand.Id -IncludeSingles:$IncludeSingles -IncludeCompilations:$IncludeCompilations -ErrorAction Stop } catch { $albums = @() }
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
                                        if ($_.PSObject.Properties.Match('Name').Count -gt 0) { $nsa = [string]$_.Name } elseif ($_.PSObject.Properties.Match('name').Count -gt 0) { $nsa = [string]$_.name }
                                        if ($nsa) { ConvertTo-ComparableName -Name $nsa } else { $null }
                                    }) | Where-Object { $_ -eq $nl } | Select-Object -First 1
                                    if ($match) { $sum += 0.5 }
                                } catch { }
                            }
                            if ($sum -gt $bestScoreSum) { $bestScoreSum = [double]$sum; $bestCand = $cand }
                        }
                        if ($bestCand -and $bestScoreSum -ge 0) {
                            $selectedArtist = $bestCand
                            $artistSelectionSource = 'evaluated'
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
                }

                # Final fallback in Preview/WhatIf: if still not selected, assume top match to enable analysis
                if (-not $selectedArtist -and $isPreview -and $topMatches -and $topMatches.Count -gt 0) {
                    $selectedArtist = $topMatches[0].Artist
                    $artistSelectionSource = 'search'
                    Write-Verbose "Preview/WhatIf: no confident or inferred artist; assuming top search match '$($selectedArtist.Name)' for analysis."
                }

                if ($selectedArtist) {
                    Write-Verbose "Selected artist: $($selectedArtist.Name)"
                    # If inferred and differs from folder artist name, hint possible typo
                    if ($artistSelectionSource -eq 'inferred') {
                        $folderArtist = $localArtist
                        if (-not [string]::Equals($folderArtist, $selectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
                            Write-Host ("Possible artist typo: folder '{0}' -> Spotify '{1}'" -f $folderArtist, $selectedArtist.Name) -ForegroundColor DarkYellow
                        }
                    }
                    # Determine if artist folder should be renamed (only when we have strong evidence)
                    $folderArtistName = Split-Path -Leaf -Path $currentPath
                    $artistRenameName = $null
                    $artistRenameTargetPath = $null
                    if ($selectedArtist.Name -and -not [string]::Equals($folderArtistName, $selectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
                        # Only propose artist rename when selection is inferred/evaluated (not a weak top search guess)
                        if ($artistSelectionSource -in @('inferred','evaluated')) {
                            $artistRenameName = ConvertTo-SafeFileName -Name $selectedArtist.Name
                            # Compute target path for display and WhatIf map
                            try {
                                $currentArtistPath = [string]$currentPath
                                $artistRenameTargetPath = Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName
                            } catch { }
                            Write-Verbose ("Proposing artist folder rename: '{0}' -> '{1}'" -f $folderArtistName, $artistRenameName)
                        } else {
                            Write-Verbose ("Artist differs from folder but selection source is '{0}'; skipping automatic artist rename proposal." -f $artistSelectionSource)
                        }
                    }

                    # Proceed with album verification: compare local folder names to Spotify artist albums
                    try {
                        # Local album folders = immediate subfolders under artist folder
                        $localAlbumDirs = Get-ChildItem -LiteralPath $currentPath -Directory -ErrorAction SilentlyContinue
                        Write-Verbose "Found album directories before exclusion filtering: $($localAlbumDirs.Name -join ', ')"
                        $localAlbumDirs = $localAlbumDirs | Where-Object { -not (Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions) }
                        Write-Verbose "Album directories after exclusion filtering: $($localAlbumDirs.Name -join ', ')"
                        Write-Verbose ("Local album folders found: {0}" -f (($localAlbumDirs | Measure-Object).Count))

                        $albumComparisons = @()
                        foreach ($dir in $localAlbumDirs) {
                            $best = $null; $bestScore = 0; $dirName = [string]$dir.Name
                            # Normalize local name: strip optional leading year and separators, e.g., "1974 - Sheet Music" -> "Sheet Music"
                            $normalizedLocal = $dirName -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
                            if ([string]::IsNullOrWhiteSpace($normalizedLocal)) { $normalizedLocal = $dirName }
                            # Detect if original had year prefix and capture it
                            $origYear = $null
                            $m = [regex]::Match($dirName, '^[\(\[]?(?<year>\d{4})[\)\]]?')
                            if ($m.Success) { $origYear = $m.Groups['year'].Value }

                            # Tiered search for albums
                            $spotifyAlbums = @()
                            # Tier 1: Precise Filtered Search (artist, album, year)
                            if ($origYear) {
                                $q1 = "artist:`"$($selectedArtist.Name)`" album:`"$normalizedLocal`" year:$origYear"
                                $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q1 -AlbumName $normalizedLocal -ArtistName $selectedArtist.Name -Year $origYear
                            }
                            # Tier 2: Year-Influenced Search (artist, album, year as keyword)
                            if ($spotifyAlbums.Count -eq 0 -and $origYear) {
                                $q2 = "artist:`"$($selectedArtist.Name)`" album:`"$normalizedLocal`" $origYear"
                                $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q2 -AlbumName $normalizedLocal -ArtistName $selectedArtist.Name -Year $origYear
                            }
                            # Tier 3: Broad Fallback Search (artist, album)
                            if ($spotifyAlbums.Count -eq 0) {
                                $q3 = "artist:`"$($selectedArtist.Name)`" album:`"$normalizedLocal`""
                                $spotifyAlbums += Get-SpotifyAlbumMatches -Query $q3 -AlbumName $normalizedLocal -ArtistName $selectedArtist.Name -Year $origYear
                            }
                            # Tier 4: Limited fallback - only for very short album names
                            if ($spotifyAlbums.Count -eq 0 -and $normalizedLocal.Length -le 10) {
                                Write-Verbose "Very short album name, trying limited artist discography..."
                                $artistAlbums = Get-SpotifyArtistAlbums -ArtistId $selectedArtist.Id -IncludeSingles:$false -IncludeCompilations:$false -ErrorAction Stop
                                # Only check albums with reasonable similarity to avoid processing thousands
                                $spotifyAlbums = $artistAlbums | Where-Object { 
                                    $quickScore = Get-StringSimilarity -String1 $normalizedLocal -String2 $_.Name
                                    $quickScore -ge 0.5
                                } | Select-Object -First 20
                            }

                            foreach ($sa in $spotifyAlbums) {
                                try {
                                    if (-not $sa) { continue }
                                    
                                    # Check if this is already a scored result from Get-SpotifyAlbumMatches
                                    if ($sa.PSObject.Properties.Match('Score').Count -gt 0 -and $sa.PSObject.Properties.Match('AlbumName').Count -gt 0) {
                                        # This is a pre-scored result, use its score and name
                                        $score = [double]$sa.Score
                                        $saName = [string]$sa.AlbumName
                                        
                                        # Boost score for year matches to prefer original releases  
                                        if ($origYear -and $sa.PSObject.Properties.Match('ReleaseDate').Count -gt 0 -and $sa.ReleaseDate) {
                                            $saYear = [regex]::Match([string]$sa.ReleaseDate, '^(?<y>\d{4})')
                                            if ($saYear.Success -and $saYear.Groups['y'].Value -eq $origYear) {
                                                $score += 1.0  # Heavily boost for exact year match
                                                Write-Verbose ("Year match bonus: {0} ({1}) matches local year {2}" -f $saName, $saYear.Groups['y'].Value, $origYear)
                                            }
                                        }
                                    } else {
                                        # This is a raw Spotify album object, score it manually
                                        $saName = $null
                                        if ($sa.PSObject.Properties.Match('Name').Count -gt 0) { $saName = $sa.Name }
                                        elseif ($sa.PSObject.Properties.Match('name').Count -gt 0) { $saName = $sa.name }
                                        if ($null -eq $saName) { continue }
                                        if ($saName -is [array]) { $saName = ($saName -join ' ') } else { $saName = [string]$saName }
                                        $score = Get-StringSimilarity -String1 $normalizedLocal -String2 $saName
                                        
                                        # Boost score for year matches to prefer original releases
                                        if ($origYear -and $sa.PSObject.Properties.Match('ReleaseDate').Count -gt 0 -and $sa.ReleaseDate) {
                                            $saYear = [regex]::Match([string]$sa.ReleaseDate, '^(?<y>\d{4})')
                                            if ($saYear.Success -and $saYear.Groups['y'].Value -eq $origYear) {
                                                $score += 1.0  # Heavily boost for exact year match
                                                Write-Verbose ("Year match bonus: {0} ({1}) matches local year {2}" -f $saName, $saYear.Groups['y'].Value, $origYear)
                                            }
                                        }
                                    }
                                    
                                    if ($score -gt $bestScore) { $bestScore = $score; $best = $sa }
                                } catch {
                                    Write-Verbose ("Album compare skipped due to error: {0}" -f $_.Exception.Message)
                                    # fallback quick ratio
                                    try {
                                        $n1 = $normalizedLocal.ToLowerInvariant().Trim()
                                        $n2 = ([string]$saName).ToLowerInvariant().Trim()
                                        if (-not [string]::IsNullOrWhiteSpace($n1) -and -not [string]::IsNullOrWhiteSpace($n2)) {
                                            $l1 = $n1.Length; $l2 = $n2.Length
                                            $max = [Math]::Max($l1, $l2)
                                            if ($max -gt 0) { $fallback = ([Math]::Min($l1, $l2) / $max) } else { $fallback = 0 }
                                            if ($fallback -gt $bestScore) { $bestScore = $fallback; $best = $sa }
                                        }
                                    } catch { }
                                }
                            }
                            # Build proposed target name based on Spotify album name and available year info
                            $matchName = $null
                            if ($best) {
                                if ($best.PSObject.Properties.Match('Name').Count) {
                                    $matchName = [string]$best.Name
                                } elseif ($best.PSObject.Properties.Match('AlbumName').Count) {
                                    $matchName = [string]$best.AlbumName
                                }
                            }
                            $matchType = if ($best) { if ($best.PSObject.Properties.Match('AlbumType').Count) { [string]$best.AlbumType } else { $null } } else { $null }
                            $matchYear = $null
                            if ($best -and $best.PSObject.Properties.Match('ReleaseDate').Count -gt 0 -and $best.ReleaseDate) {
                                $ym = [regex]::Match([string]$best.ReleaseDate, '^(?<y>\d{4})')
                                if ($ym.Success) { $matchYear = $ym.Groups['y'].Value }
                            }
                            $targetBase = if ($matchName) { ConvertTo-SafeFileName $matchName } else { $null }
                            $proposed = $null
                            if ($targetBase) {
                                if ($origYear) {
                                    $y = if ($matchYear) { $matchYear } else { $origYear }
                                    $proposed = "${y} - $targetBase"
                                } else {
                                    $proposed = $targetBase
                                }
                            }
                            $albumComparisons += [PSCustomObject]@{
                                LocalAlbum  = $dirName
                                LocalNorm   = $normalizedLocal
                                LocalPath   = $dir.FullName
                                MatchName   = $matchName
                                MatchType   = $matchType
                                MatchScore  = [math]::Round($bestScore,2)
                                MatchYear   = $matchYear
                                ProposedName= $proposed
                                MatchedItem = $best # Keep the full object for track fetching
                            }
                        }

                        # If IncludeTracks, collect track information and compute metrics
                        if ($IncludeTracks) {
                            foreach ($c in $albumComparisons) {
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
                                    $missingTitle = ($tracks | Where-Object { -not $_.Title }).Count
                                    $c | Add-Member -NotePropertyName TracksWithMissingTitle -NotePropertyValue $missingTitle

                                    # Classical music analysis
                                    $classicalTracks = $tracks | Where-Object { $_.IsClassical -eq $true }
                                    $c | Add-Member -NotePropertyName ClassicalTracks -NotePropertyValue $classicalTracks.Count
                                    
                                    if ($classicalTracks.Count -gt 0) {
                                        $composers = $classicalTracks | Where-Object { $_.Composer } | Group-Object Composer | Sort-Object Count -Descending
                                        $primaryComposer = if ($composers.Count -gt 0) { $composers[0].Name } else { $null }
                                        $c | Add-Member -NotePropertyName PrimaryComposer -NotePropertyValue $primaryComposer
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
                                        
                                        # Pass DontFix parameter to Set-AudioFileTags
                                        if ($DontFix) { $tagParams.DontFix = $DontFix }
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
                                    $c | Add-Member -NotePropertyName TrackCountLocal -NotePropertyValue 0
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
                                Write-Host "What If: Performing Rename Operation" -ForegroundColor DarkYellow
                                foreach ($kv in $renameMap.GetEnumerator()) {
                                    Write-Host "Name  : " -ForegroundColor Green -NoNewline; Write-Host $kv.Key
                                    Write-Host "Value : " -ForegroundColor Green -NoNewline; Write-Host $kv.Value
                                }
                            } else {
                                # If nothing to rename, check for equal-name cases and surface that clearly
                                $equalCases = $albumComparisons | Where-Object { $_.ProposedName -and [string]::Equals($_.LocalAlbum, $_.ProposedName, [StringComparison]::InvariantCultureIgnoreCase) }
                                if ($equalCases) {
                                    foreach ($e in $equalCases) {
                                        Write-Host "Nothing to Rename: LocalFolder = NewFolderName" -ForegroundColor DarkYellow
                                        Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $e.LocalAlbum, $e.ProposedName)
                                    }
                                } else {
                                    Write-Host "What If: No rename candidates at the current threshold." -ForegroundColor DarkYellow
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
                                    if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) { Write-Host "Nothing to Rename: LocalFolder = NewFolderName" -ForegroundColor DarkYellow; Write-Verbose ("Nothing to Rename: LocalFolder '{0}' equals NewFolderName '{1}'" -f $c.LocalAlbum, $c.ProposedName); $message = 'already-matching'; $outcomes += [PSCustomObject]@{ LocalFolder=$c.LocalAlbum; LocalPath=$c.LocalPath; NewFolderName=$c.ProposedName; Action=$action; Reason=$message; Score=$c.MatchScore; SpotifyAlbum=$c.MatchName }; continue }
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
                                Write-Host "Performed Rename Operation"
                                foreach ($kv in $renameMap.GetEnumerator()) {
                                    Write-Host "Name  : " -ForegroundColor Green -NoNewline; Write-Host $kv.Key
                                    Write-Host "Value : " -ForegroundColor Green -NoNewline; Write-Host $kv.Value
                                }
                            }
                            if ($artistRenamePerformed) {
                                $artistMap = [ordered]@{ $artistRenameFrom = $artistRenameTo }
                                Write-Host "Performed Rename Operation"
                                foreach ($kv in $artistMap.GetEnumerator()) {
                                    Write-Host "Name  : " -ForegroundColor Green -NoNewline; Write-Host $kv.Key
                                    Write-Host "Value : " -ForegroundColor Green -NoNewline; Write-Host $kv.Value
                                }
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
            }
    }

    end {
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}
