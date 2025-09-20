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
    Specifies the folder level for the artist (e.g., 1U for one up, 1D for one down).

.PARAMETER ExcludeFolders
    Folders to exclude from scanning.

.PARAMETER LogTo
    Path to the log file for results.

.PARAMETER IncludeSingles
    Include single releases when fetching albums from provider.

.PARAMETER IncludeCompilations
    Include compilation releases when fetching albums from provider.

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
        [double]$ConfidenceThreshold = 0.9,

        [Parameter(Mandatory = $false)]
        [string]$ArtistAt,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeFolders,

        [Parameter(Mandatory = $false)]
        [string]$LogTo,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSingles,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeCompilations,

        [Parameter(Mandatory = $false)]
        [switch]$Preview,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [switch]$ShowEverything
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
    }

    process {
        # Main analysis logic always runs; actual changes are guarded by ShouldProcess
    # Get the folder name as artist name
    $artistName = Split-Path $Path -Leaf
    Write-Verbose "Processing artist: $artistName"
    $isPreview = $Preview -or $WhatIfPreference

            # Local helper: flatten Spotishell Search-Item results into a simple albums array
            function Get-AlbumItemsFromSearchResult {
                param([Parameter(Mandatory)]$Result)
                $albums = @()
                try {
                    if ($null -eq $Result) { return @() }
                    if ($Result -is [System.Array]) {
                        foreach ($p in $Result) { $albums += (Get-AlbumItemsFromSearchResult -Result $p) }
                    } else {
                        if ($Result.PSObject.Properties.Match('Albums').Count -gt 0 -and $Result.Albums) {
                            if ($Result.Albums.PSObject.Properties.Match('Items').Count -gt 0 -and $Result.Albums.Items) { $albums += $Result.Albums.Items }
                        }
                        if ($Result.PSObject.Properties.Match('Items').Count -gt 0 -and $Result.Items) { $albums += $Result.Items }
                    }
                } catch {
                    $msg = $_.Exception.Message
                    Write-Verbose ("Get-AlbumItemsFromSearchResult failed to parse result: {0}" -f $msg)
                }
                # Ensure flat, non-null array
                return @($albums | Where-Object { $_ })
            }

            # Search Spotify for the artist and get top matches
            $topMatches = Get-SpotifyArtist -ArtistName $artistName
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
                        if (-not $isPreview) {
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
                        $localAlbumDirs = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue
                        $localNames = @()
                        foreach ($d in $localAlbumDirs) {
                            $n = [string]$d.Name
                            $nn = $n -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
                            if (-not [string]::IsNullOrWhiteSpace($nn)) { $localNames += $nn }
                        }
                        # Quick path: use the first local album name to infer directly from top album match
                        if ($localNames.Count -gt 0) {
                            $primary = $localNames[0]
                            $quick = Get-SpotifyAlbumMatches -AlbumName $primary -ErrorAction SilentlyContinue | Select-Object -First 1
                            if ($quick -and $quick.Artists -and $quick.Artists.Count -gt 0) {
                                $qa = $quick.Artists[0]
                                if ($qa.Name) {
                                    $selectedArtist = [PSCustomObject]@{ Name=[string]$qa.Name; Id=[string]$qa.Id }
                                    $artistSelectionSource = 'inferred'
                                    Write-Verbose ("Quick-inferred artist from album '{0}': {1}" -f $primary, $selectedArtist.Name)
                                }
                            } else {
                                # Quick fallback using combined All search
                                try {
                                    $q = "{0} {1}" -f $artistName, $primary
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
                                            $q2 = '"{0} {1}"' -f $artistName, $primary
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
                        }
                        $artistVotes = @{}
                        foreach ($ln in $localNames) {
                            if ($selectedArtist) { break }
                            # Try both album-only and combined artist+album queries to improve recall
                            $m1 = Get-SpotifyAlbumMatches -AlbumName $ln -ErrorAction SilentlyContinue
                            $m2 = Get-SpotifyAlbumMatches -AlbumName ("{0} {1}" -f $artistName, $ln) -ErrorAction SilentlyContinue
                            # Also try a combined All-type query via Search-Item directly to mirror user's successful approach
                            $m3 = @()
                            try {
                                $q = "{0} {1}" -f $artistName, $ln
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
                                $q2 = '"{0} {1}"' -f $artistName, $ln
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
                                foreach ($m in ($m1 + $m2 + $m3 + $m4 + $m5)) {
                                    foreach ($a in $m.Artists) {
                                        if (-not $a.Name) { continue }
                                        # Only count votes for reasonably relevant matches
                                        if ($m.Score -ge 0.3) {
                                            if (-not $artistVotes.ContainsKey($a.Name)) { $artistVotes[$a.Name] = [PSCustomObject]@{ Name=$a.Name; Id=$a.Id; Votes=0; BestScore=0.0 } }
                                            $entry = $artistVotes[$a.Name]
                                            $entry.Votes += 1
                                            if ($m.Score -gt $entry.BestScore) { $entry.BestScore = [double]$m.Score }
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
                                        # In preview, don't prompt; keep unselected so we can fall back to manual selection logic if needed (but we skip prompts in preview)
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
                        $localAlbumDirs = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue
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
                if (-not $selectedArtist -and $isPreview) {
                    $selectedArtist = $topMatches[0].Artist
                    $artistSelectionSource = 'search'
                    Write-Verbose "Preview/WhatIf: no confident or inferred artist; assuming top search match '$($selectedArtist.Name)' for analysis."
                }

                if ($selectedArtist) {
                    Write-Verbose "Selected artist: $($selectedArtist.Name)"
                    # If inferred and differs from folder artist name, hint possible typo
                    if ($artistSelectionSource -eq 'inferred') {
                        $folderArtist = $artistName
                        if (-not [string]::Equals($folderArtist, $selectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
                            Write-Host ("Possible artist typo: folder '{0}' -> Spotify '{1}'" -f $folderArtist, $selectedArtist.Name) -ForegroundColor DarkYellow
                        }
                    }
                    # Determine if artist folder should be renamed (only when we have strong evidence)
                    $folderArtistName = Split-Path -Leaf -Path $Path
                    $artistRenameName = $null
                    $artistRenameTargetPath = $null
                    if ($selectedArtist.Name -and -not [string]::Equals($folderArtistName, $selectedArtist.Name, [StringComparison]::InvariantCultureIgnoreCase)) {
                        # Only propose artist rename when selection is inferred/evaluated (not a weak top search guess)
                        if ($artistSelectionSource -in @('inferred','evaluated')) {
                            $artistRenameName = ConvertTo-SafeFileName -Name $selectedArtist.Name
                            # Compute target path for display and WhatIf map
                            try {
                                $currentArtistPath = [string](Resolve-Path -LiteralPath $Path).Path
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
                        $localAlbumDirs = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue
                        Write-Verbose ("Local album folders found: {0}" -f (($localAlbumDirs | Measure-Object).Count))

                        $spotifyAlbums = Get-SpotifyArtistAlbums -ArtistId $selectedArtist.Id -IncludeSingles:$IncludeSingles -IncludeCompilations:$IncludeCompilations -ErrorAction Stop
                        Write-Verbose ("Spotify albums retrieved: {0}" -f (($spotifyAlbums | Measure-Object).Count))

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
                            foreach ($sa in $spotifyAlbums) {
                                try {
                                    if (-not $sa) { continue }
                                    $saName = $null
                                    if ($sa.PSObject.Properties.Match('Name').Count -gt 0) { $saName = $sa.Name }
                                    elseif ($sa.PSObject.Properties.Match('name').Count -gt 0) { $saName = $sa.name }
                                    if ($null -eq $saName) { continue }
                                    if ($saName -is [array]) { $saName = ($saName -join ' ') } else { $saName = [string]$saName }
                                    $score = Get-StringSimilarity -String1 $normalizedLocal -String2 $saName
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
                            $matchName = if ($best) { [string]$best.Name } else { $null }
                            $matchType = if ($best) { $best.AlbumType } else { $null }
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
                                $currentArtistPath = [string](Resolve-Path -LiteralPath $Path).Path
                                $targetArtistPath = if ($artistRenameTargetPath) { $artistRenameTargetPath } else { Join-Path -Path (Split-Path -Parent -Path $currentArtistPath) -ChildPath $artistRenameName }
                                $renameMap[$currentArtistPath] = $targetArtistPath
                            }
                            foreach ($c in ($albumComparisons | Sort-Object -Property MatchScore -Descending)) {
                                if ($c.ProposedName -and -not [string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) {
                                    # Only include confident suggestions (at/above threshold)
                                    if ($c.MatchScore -ge $goodThreshold) {
                                        $renameMap[[string]$c.LocalPath] = (Join-Path -Path $Path -ChildPath ([string]$c.ProposedName))
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
                                    $targetPath  = Join-Path -Path $Path -ChildPath $c.ProposedName
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
                                    $currentArtistPath = [string](Resolve-Path -LiteralPath $Path).Path
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
                                foreach ($r in $performed) { $renameMap[[string]$r.LocalPath] = (Join-Path -Path $Path -ChildPath ([string]$r.NewFolderName)) }
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
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = (Resolve-Path -LiteralPath $Path).Path; Mode = $DoIt; ConfidenceThreshold = $ConfidenceThreshold; Items = $outcomes }
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
                                    $payload = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Path = (Resolve-Path -LiteralPath $Path).Path; Mode = 'Preview'; ConfidenceThreshold = $ConfidenceThreshold; Items = $records }
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
            } else {
                Write-Warning "No matches found on Spotify for '$artistName'"
            }
    }

    end {
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}