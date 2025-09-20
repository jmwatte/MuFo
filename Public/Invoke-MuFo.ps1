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

.PARAMETER ArtistAt
    Specifies the folder level for the artist (e.g., 1U for one up, 1D for one down).

.PARAMETER ExcludeFolders
    Folders to exclude from scanning.

.PARAMETER LogTo
    Path to the log file for results.

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
        [string]$ArtistAt,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeFolders,

        [Parameter(Mandatory = $false)]
        [string]$LogTo
    )

    begin {
        # Initialization code here
        Write-Verbose "Starting Invoke-MuFo with Path: $Path, DoIt: $DoIt"
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
                        if ($topMatches[0].Score -ge 0.9) {
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

                        $spotifyAlbums = Get-SpotifyArtistAlbums -ArtistId $selectedArtist.Id -ErrorAction Stop
                        Write-Verbose ("Spotify albums retrieved: {0}" -f (($spotifyAlbums | Measure-Object).Count))

                        $albumComparisons = @()
                        foreach ($dir in $localAlbumDirs) {
                            $best = $null; $bestScore = 0; $dirName = [string]$dir.Name
                            foreach ($sa in $spotifyAlbums) {
                                $score = Get-StringSimilarity -String1 $dirName -String2 $sa.Name
                                if ($score -gt $bestScore) { $bestScore = $score; $best = $sa }
                            }
                            $albumComparisons += [PSCustomObject]@{
                                LocalAlbum  = $dirName
                                MatchName   = if ($best) { $best.Name } else { $null }
                                MatchType   = if ($best) { $best.AlbumType } else { $null }
                                MatchScore  = [math]::Round($bestScore,2)
                            }
                        }

                        # Display summary; later we'll wire -DoIt rename/apply
                        foreach ($c in $albumComparisons | Sort-Object -Property MatchScore -Descending) {
                            $color = if ($c.MatchScore -ge 0.9) { 'Green' } elseif ($c.MatchScore -ge 0.75) { 'DarkYellow' } else { 'Red' }
                            Write-Host ("Album: '{0}' -> '{1}' ({2}) Score={3}" -f $c.LocalAlbum, $c.MatchName, $c.MatchType, $c.MatchScore) -ForegroundColor $color
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