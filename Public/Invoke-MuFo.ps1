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
        [switch]$IncludeCompilations
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
        # Connect to Spotify (validate Spotishell setup)
        if (Get-Module -ListAvailable -Name Spotishell) {
            Connect-SpotifyService
        } else {
            Write-Warning "Spotishell module not found. Install-Module Spotishell to enable Spotify integration."
        }
    }

    process {
        # Main logic here
        if ($PSCmdlet.ShouldProcess($Path, "Process music library")) {
            # Get the folder name as artist name
            $artistName = Split-Path $Path -Leaf
            Write-Host "Processing artist: $artistName"

            # Search Spotify for the artist and get top matches
            $topMatches = Get-SpotifyArtist -ArtistName $artistName
            if ($topMatches) {
                Write-Host "Found $($topMatches.Count) potential matches on Spotify"

                $selectedArtist = $null
                switch ($DoIt) {
                    "Automatic" {
                        $selectedArtist = $topMatches[0].Artist
                        Write-Host "Automatically selected: $($selectedArtist.Name)"
                    }
                    "Manual" {
                        # Prompt user to choose
                        for ($i = 0; $i -lt $topMatches.Count; $i++) {
                            Write-Host "$($i + 1). $($topMatches[$i].Artist.Name) (Score: $([math]::Round($topMatches[$i].Score, 2)))"
                        }
                        $choice = Read-Host "Select artist (1-$($topMatches.Count)) or press Enter to skip"
                        if ($choice -and $choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $topMatches.Count) {
                            $selectedArtist = $topMatches[$choice - 1].Artist
                        }
                    }
                    "Smart" {
                        if ($topMatches[0].Score -ge $ConfidenceThreshold) {
                            $selectedArtist = $topMatches[0].Artist
                            Write-Host "Smart selected: $($selectedArtist.Name)"
                        } else {
                            # Fall back to manual
                            Write-Host "Low confidence, switching to manual mode"
                            for ($i = 0; $i -lt $topMatches.Count; $i++) {
                                Write-Host "$($i + 1). $($topMatches[$i].Artist.Name) (Score: $([math]::Round($topMatches[$i].Score, 2)))"
                            }
                            $choice = Read-Host "Select artist (1-$($topMatches.Count)) or press Enter to skip"
                            if ($choice -and $choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $topMatches.Count) {
                                $selectedArtist = $topMatches[$choice - 1].Artist
                            }
                        }
                    }
                }

                if ($selectedArtist) {
                    Write-Host "Selected artist: $($selectedArtist.Name)"
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
                        # Use ConfidenceThreshold for green, and a warning band slightly below it
                        $goodThreshold = [double]$ConfidenceThreshold
                        $warnThreshold = [Math]::Max(0.0, [double]$ConfidenceThreshold - 0.15) # assumption: warn band = threshold - 0.15
                        foreach ($c in $albumComparisons | Sort-Object -Property MatchScore -Descending) {
                            $color = if ($c.MatchScore -ge $goodThreshold) { 'Green' } elseif ($c.MatchScore -ge $warnThreshold) { 'DarkYellow' } else { 'Red' }
                            Write-Host ("Album: '{0}' (norm '{1}') -> '{2}' ({3}) Score={4}" -f $c.LocalAlbum, $c.LocalNorm, $c.MatchName, $c.MatchType, $c.MatchScore) -ForegroundColor $color
                        }

                        # Apply rename actions per DoIt mode
                        foreach ($c in $albumComparisons) {
                            try {
                                if (-not $c.ProposedName) { continue }
                                # Skip if name already matches (case-insensitive)
                                if ([string]::Equals($c.LocalAlbum, $c.ProposedName, [StringComparison]::InvariantCultureIgnoreCase)) { continue }
                                $currentPath = [string]$c.LocalPath
                                $targetPath  = Join-Path -Path $Path -ChildPath $c.ProposedName
                                if (Test-Path -LiteralPath $targetPath) {
                                    Write-Warning ("Skip rename: Target already exists: {0}" -f $targetPath)
                                    continue
                                }

                                $shouldRename = $false
                                switch ($DoIt) {
                                    'Automatic' { $shouldRename = ($c.MatchScore -ge $goodThreshold) }
                                    'Smart'     { if ($c.MatchScore -ge $goodThreshold) { $shouldRename = $true } else { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } } }
                                    'Manual'    { $resp = Read-Host ("Rename '{0}' -> '{1}'? [y/N]" -f $c.LocalAlbum, $c.ProposedName); if ($resp -match '^(?i)y(es)?$') { $shouldRename = $true } }
                                }
                                if ($shouldRename) {
                                    if ($PSCmdlet.ShouldProcess($currentPath, ("Rename to '{0}'" -f $c.ProposedName))) {
                                        Rename-Item -LiteralPath $currentPath -NewName $c.ProposedName -ErrorAction Stop
                                        Write-Host ("Renamed: '{0}' -> '{1}'" -f $c.LocalAlbum, $c.ProposedName) -ForegroundColor Green
                                    }
                                } else {
                                    Write-Verbose ("Skipped rename for '{0}' (score {1})" -f $c.LocalAlbum, $c.MatchScore)
                                }
                            } catch {
                                Write-Warning ("Rename failed for '{0}': {1}" -f $c.LocalAlbum, $_.Exception.Message)
                            }
                        }
                    } catch {
                        Write-Warning ("Album verification failed: {0}" -f $_)
                    }
                } else {
                    Write-Warning "No artist selected"
                }
            } else {
                Write-Warning "No matches found on Spotify for '$artistName'"
            }
        }
    }

    end {
        # Cleanup code here
        Write-Verbose "Invoke-MuFo completed"
    }
}