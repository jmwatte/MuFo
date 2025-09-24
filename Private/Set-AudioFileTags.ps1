function Set-AudioFileTags {
<#
.SYNOPSIS
    Writes and updates audio file tags with intelligent metadata enhancement.

.DESCRIPTION
    This function writes metadata to audio files with special enhancements for classical music.
    It can fill missing titles, track numbers, genres, an    # Summary
    Write-Host "`nTag Enhancement Summary:" -ForegroundColor Cyan
    Write-Host "  Files processed: $($existingTags.Count)" -ForegroundColor Gray
    
    if ($WhatIfPreference) {
        $wouldUpdate = $results | Where-Object { $_.ChangesApplied.Count -gt 0 } | Measure-Object | ForEach-Object Count
        Write-Host "  Files that would be updated: $wouldUpdate" -ForegroundColor Yellow
        Write-Host "  Files that would remain unchanged: $($existingTags.Count - $wouldUpdate)" -ForegroundColor Gray
    } else {
        Write-Host "  Files updated: $changesMade" -ForegroundColor Green
        Write-Host "  Files unchanged: $($existingTags.Count - $changesMade)" -ForegroundColor Gray
    }imize album artist organization.
    Includes validation for missing tracks and metadata consistency.

.PARAMETER Path
    Path to an audio file or directory containing audio files.

.PARAMETER SpotifyAlbum
    Spotify album object to use as reference for metadata enhancement.

.PARAMETER FixOnly
    Only fix these specific tag types. Valid values: 'Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists'.
    Cannot be used together with -DontFix. When specified, only these tag types will be fixed.

.PARAMETER DontFix
    Exclude specific tag types from being fixed. Valid values: 'Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists'.
    Cannot be used together with -FixOnly. By default, all tag types are fixed when issues are detected.

.PARAMETER OptimizeClassicalTags
    Optimize tags for classical music (composer as album artist, conductor info, etc.).

.PARAMETER ValidateCompleteness
    Check for missing tracks in the album sequence.

.PARAMETER CreateMissingFilesLog
    Create a small log file in the album folder listing missing track numbers when completeness validation finds gaps.

.PARAMETER WhatIf
    Show what changes would be made without actually writing them.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina" -OptimizeClassicalTags
    
    Fixes all metadata issues and optimizes for classical music organization.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Album" -SpotifyAlbum $album -DontFix Genres -ValidateCompleteness
    
    Fixes all metadata except genres, and validates track completeness.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Album" -FixOnly Titles,TrackNumbers
    
    Only fixes track titles and track numbers, leaves other metadata unchanged.

.NOTES
    Requires TagLib-Sharp to be available for writing tags.
    Author: jmw
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [object]$SpotifyAlbum,
        
        [Parameter()]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$FixOnly = @(),
        
        [Parameter()]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$DontFix = @(),
        
        [switch]$OptimizeClassicalTags,
        
        [switch]$ValidateCompleteness,
        
        [switch]$CreateMissingFilesLog,
        
        [string]$LogTo
    )
    
    # Supported audio file extensions
    $supportedExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')
    
    # Check if TagLib-Sharp is available (reuse detection from Get-AudioFileTags)
    $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
    
    if (-not $tagLibLoaded) {
        Write-Warning "TagLib-Sharp is required for writing tags but is not loaded."
        Write-Host "Please run: Get-AudioFileTags first to load TagLib-Sharp" -ForegroundColor Yellow
        return @()
    }
    
    # Get current tags to work with (this will now exclude lib folders)
    $existingTags = Get-AudioFileTags -Path $Path -IncludeComposer
    if ($existingTags.Count -eq 0) {
        Write-Warning "No audio files found or could not read existing tags"
        return @()
    }
    
    Write-Verbose "Processing $($existingTags.Count) audio files for tag enhancement"
    
    # Parameter validation: FixOnly and DontFix are mutually exclusive
    if ($FixOnly.Count -gt 0 -and $DontFix.Count -gt 0) {
        throw "Cannot specify both -FixOnly and -DontFix parameters. Use one or the other."
    }
    
    # Determine which tags to fix - Include TrackArtists by default for comprehensive fixing
    $tagsToFix = if ($FixOnly.Count -gt 0) {
        $FixOnly
    } elseif ($DontFix.Count -gt 0) {
        @('Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists') | Where-Object { $_ -notin $DontFix }
    } else {
        @('Titles', 'TrackNumbers', 'Years', 'Genres', 'AlbumArtists', 'TrackArtists')  # Default: fix everything including track artists
    }
    
    Write-Verbose "Tags to fix: $($tagsToFix -join ', ')"
    
    $results = @()
    $changesMade = 0
    
    # Analyze album for consistency and gaps
    $albumAnalysis = @{
        AlbumName = ($existingTags | Where-Object { $_.Album } | Group-Object Album | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name)
        ArtistName = ($existingTags | Where-Object { $_.Artist } | Group-Object Artist | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name)
        IsClassical = ($existingTags | Where-Object { $_.IsClassical -eq $true }).Count -gt ($existingTags.Count / 2)
        TrackNumbers = $existingTags | Where-Object { $_.Track -gt 0 } | ForEach-Object { $_.Track } | Sort-Object
        ExpectedTracks = if ($SpotifyAlbum -and $SpotifyAlbum.total_tracks) { $SpotifyAlbum.total_tracks } else { $existingTags.Count }
    }
    
    # Fetch album tracks early so we can check for actual track artist changes
    if ($SpotifyAlbum -and 'TrackArtists' -in $tagsToFix -and -not $SpotifyAlbum.tracks) {
        try {
            $albumTracks = Get-AlbumTracks -Id $SpotifyAlbum.id
            $SpotifyAlbum | Add-Member -MemberType NoteProperty -Name tracks -Value @{ items = $albumTracks } -Force
            Write-Verbose "Fetched $($albumTracks.Count) tracks for album '$($SpotifyAlbum.name)' for change detection"
        } catch {
            Write-Verbose "Could not fetch album tracks for change detection: $($_.Exception.Message)"
        }
    }
    
    # Detect if this might be a compilation album (Various Artists scenario)
    $artistVariations = $existingTags | Where-Object { $_.Artist -and $_.Artist -ne '' } | Group-Object Artist
    $isLikelyCompilation = $artistVariations.Count -gt ($existingTags.Count * 0.5) -or 
                          ($albumAnalysis.ArtistName -match "(?i)(various|compilation|mixed|soundtrack)")
    
    # Check if any track artists will actually be changed
    $tracksWithArtistChanges = 0
    if ('TrackArtists' -in $tagsToFix) {
        foreach ($track in $existingTags) {
            $suggestedArtist = $null
            # Get track-specific artist from Spotify track data first
            if ($SpotifyAlbum -and $SpotifyAlbum.tracks -and $SpotifyAlbum.tracks.items -and $track.Track -gt 0) {
                $spotifyTrack = $SpotifyAlbum.tracks.items | Where-Object { $_.track_number -eq $track.Track }
                if ($spotifyTrack -and $spotifyTrack.artists -and $spotifyTrack.artists.Count -gt 0) {
                    $trackArtistNames = $spotifyTrack.artists | ForEach-Object { $_.name }
                    $suggestedArtist = $trackArtistNames -join ', '
                }
            }
            
            # Fall back to album artist for track artist if no track-specific data found
            if (-not $suggestedArtist -and $SpotifyAlbum -and $SpotifyAlbum.artists -and $SpotifyAlbum.artists.Count -gt 0) {
                $albumArtistNames = $SpotifyAlbum.artists | ForEach-Object { $_.name }
                $suggestedArtist = $albumArtistNames -join ', '
            }
            
            if ($suggestedArtist -and $suggestedArtist -ne $track.Artist) {
                $tracksWithArtistChanges++
            }
        }
    }
    
    # Smart warnings for TrackArtist changes - only if there are actual changes pending
    # Disabled warning as it was showing even when no changes were needed
    # if ('TrackArtists' -in $tagsToFix -and $tracksWithArtistChanges -gt 0) {
    #     Write-Warning "Track artist changes detected for album with multiple performers. This may overwrite performer credits."
    #     Write-Host "  Current track artists: $($artistVariations.Name -join ', ')" -ForegroundColor Yellow
    #     Write-Host "  Tracks that will be updated: $tracksWithArtistChanges" -ForegroundColor Yellow
    #     if ($isLikelyCompilation) {
    #         Write-Host "  💡 Consider using -DontFix 'TrackArtists' for compilation albums" -ForegroundColor Cyan
    #     }
    # }
    
    Write-Host "Album Analysis:" -ForegroundColor Cyan
    Write-Host "  Album: $($albumAnalysis.AlbumName)" -ForegroundColor Gray
    Write-Host "  Artist: $($albumAnalysis.ArtistName)" -ForegroundColor Gray
    Write-Host "  Tracks Found: $($existingTags.Count) / " -ForegroundColor Gray -NoNewline
    Write-Host "Expected: $($albumAnalysis.ExpectedTracks)" -ForegroundColor Red
    
    # Validate completeness if requested
    if ($ValidateCompleteness) {
        Write-Host "`nTrack Completeness Analysis:" -ForegroundColor Yellow
        
        if ($albumAnalysis.TrackNumbers.Count -gt 0) {
            $expectedSequence = 1..$albumAnalysis.ExpectedTracks
            $missingTracks = $expectedSequence | Where-Object { $_ -notin $albumAnalysis.TrackNumbers }
            $duplicateTracks = $albumAnalysis.TrackNumbers | Group-Object | Where-Object { $_.Count -gt 1 }
            
            if ($missingTracks) {
                Write-Host "  ⚠️ Missing track numbers: $($missingTracks -join ', ')" -ForegroundColor Red
            }
            
            if ($duplicateTracks) {
                Write-Host "  ⚠️ Duplicate track numbers: $($duplicateTracks.Name -join ', ')" -ForegroundColor Red
            }
            
            if (-not $missingTracks -and -not $duplicateTracks) {
                Write-Host "  ✅ Track sequence complete and valid" -ForegroundColor Green
            }
            
            # Create missing files log if requested and there are missing tracks
            if ($CreateMissingFilesLog -and $missingTracks) {
                $albumPath = Split-Path -Parent -Path $existingTags[0].Path
                $logFileName = "missing-tracks-$(Get-Date -Format 'yyyy-MM-dd').txt"
                $logFilePath = Join-Path -Path $albumPath -ChildPath $logFileName
                
                $logContent = @"
Missing Tracks Report
Album: $($albumAnalysis.AlbumName)
Artist: $($albumAnalysis.ArtistName)
Expected Tracks: $($albumAnalysis.ExpectedTracks)
Found Tracks: $($existingTags.Count)
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Missing track numbers: $($missingTracks -join ', ')

This file was generated by MuFo tag enhancement.
"@
                
                try {
                    $logContent | Set-Content -Path $logFilePath -Encoding UTF8
                    Write-Host "  📝 Missing tracks log created: $logFileName" -ForegroundColor Cyan
                } catch {
                    Write-Warning "Could not create missing tracks log: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "  ⚠️ No track numbers found - will assign if requested" -ForegroundColor Yellow
        }
    }
    
    # Process each file
    foreach ($track in $existingTags) {
        try {
            Write-Verbose "Processing: $($track.FileName)"
            
            $fileObj = [TagLib.File]::Create($track.Path)
            $tag = $fileObj.Tag
            $changesMadeToFile = $false
            $changes = @()
            
            # Fill missing or incorrect titles
            if ('Titles' -in $tagsToFix) {
                $suggestedTitle = $null
                $needsTitleFix = $false
                
                # Check if title is missing or obviously wrong
                if ([string]::IsNullOrWhiteSpace($tag.Title)) {
                    $needsTitleFix = $true
                } elseif ($tag.Title -eq [System.IO.Path]::GetFileNameWithoutExtension($track.FileName)) {
                    # Title looks like a placeholder or just the filename
                    $needsTitleFix = $true
                }
                
                if ($needsTitleFix) {
                    # Try to get from Spotify first (most accurate)
                    if ($SpotifyAlbum -and $SpotifyAlbum.tracks -and $track.Track -gt 0) {
                        $spotifyTrack = $SpotifyAlbum.tracks.items | Where-Object { $_.track_number -eq $track.Track }
                        if ($spotifyTrack) {
                            $suggestedTitle = $spotifyTrack.name
                        }
                    }
                    
                    # If no Spotify data, try to extract from filename
                    if (-not $suggestedTitle) {
                        $filename = [System.IO.Path]::GetFileNameWithoutExtension($track.FileName)
                        
                        # Pattern: "01 - Track Name" or "Track Name"
                        if ($filename -match '^\d+\s*[-\.]\s*(.+)$') {
                            $suggestedTitle = $matches[1].Trim()
                        } elseif ($filename -match '^\d+\s+(.+)$') {
                            $suggestedTitle = $matches[1].Trim()
                        } elseif ($filename -notlike "*test*" -and $filename -notlike "*missing*") {
                            # Use filename as-is if it doesn't look like a placeholder
                            $suggestedTitle = $filename
                        }
                    }
                    
                    # If we still don't have a suggestion but we know the title is bad, 
                    # provide a clear indication to the user
                    if (-not $suggestedTitle) {
                        $changes += "⚠️ Title: '$($tag.Title)' needs manual review (appears to be placeholder/test data)"
                        # Don't set changesMadeToFile since we're not making changes, just flagging
                    } elseif ($suggestedTitle -ne $tag.Title) {
                        if (-not $WhatIfPreference) {
                            $tag.Title = $suggestedTitle
                        }
                        $changesMadeToFile = $true
                        $changes += "Title: '$suggestedTitle' (was: '$($tag.Title)')"
                    }
                }
            }
            
            # Fill missing track numbers
            if ('TrackNumbers' -in $tagsToFix -and ($tag.Track -eq 0 -or -not $tag.Track)) {
                $suggestedTrackNumber = $null
                
                # Try to extract from filename
                $filename = [System.IO.Path]::GetFileNameWithoutExtension($track.FileName)
                if ($filename -match '^(\d+)') {
                    $suggestedTrackNumber = [int]$matches[1]
                } else {
                    # Use file order as fallback
                    $allFiles = Get-ChildItem -Path (Split-Path $track.Path) -File | 
                                Where-Object { $_.Extension.ToLower() -in @('.mp3', '.flac', '.m4a', '.ogg', '.wav') } | 
                                Sort-Object Name
                    $index = [Array]::IndexOf($allFiles.FullName, $track.Path)
                    if ($index -ge 0) {
                        $suggestedTrackNumber = $index + 1
                    }
                }
                
                if ($suggestedTrackNumber) {
                    if (-not $WhatIfPreference) {
                        $tag.Track = [uint32]$suggestedTrackNumber
                    }
                    $changesMadeToFile = $true
                    $changes += "Track: $suggestedTrackNumber"
                }
            }
            
            # Fill missing or incorrect years
            if ('Years' -in $tagsToFix) {
                $suggestedYear = $null
                
                # Try to get year from Spotify album first
                if ($SpotifyAlbum -and $SpotifyAlbum.release_date) {
                    try {
                        $releaseDate = [DateTime]::Parse($SpotifyAlbum.release_date)
                        $suggestedYear = $releaseDate.Year
                    } catch {
                        # Try parsing just the year if full date parsing fails
                        if ($SpotifyAlbum.release_date -match '^\d{4}') {
                            $suggestedYear = [int]$matches[0]
                        }
                    }
                }
                
                # Try to extract from folder name if no Spotify data
                if (-not $suggestedYear) {
                    $folderName = Split-Path $track.Path -Parent | Split-Path -Leaf
                    if ($folderName -match '(\d{4})') {
                        $suggestedYear = [int]$matches[1]
                    }
                }
                
                # Update if we have a suggested year and it's different from current
                if ($suggestedYear -and ($tag.Year -eq 0 -or $tag.Year -ne $suggestedYear)) {
                    if (-not $WhatIfPreference) {
                        $tag.Year = [uint32]$suggestedYear
                    }
                    $changesMadeToFile = $true
                    if ($tag.Year -eq 0) {
                        $changes += "Year: $suggestedYear"
                    } else {
                        $changes += "Year: $suggestedYear (was: $($tag.Year))"
                    }
                }
            }
            
            # Fill missing or enhance existing genres
            if ('Genres' -in $tagsToFix) {
                $suggestedGenres = @()
                
                # Get existing genres first
                $existingGenres = @()
                if ($tag.Genres -and $tag.Genres.Count -gt 0) {
                    $existingGenres = @($tag.Genres)
                }
                
                # Add classical genre if detected
                if ($albumAnalysis.IsClassical -and "Classical" -notin $existingGenres) {
                    $suggestedGenres += "Classical"
                } elseif ($SpotifyAlbum -and $SpotifyAlbum.artists -and $SpotifyAlbum.artists.Count -gt 0) {
                    # Get genres from artist, not album
                    try {
                        $artistId = $SpotifyAlbum.artists[0].id
                        if ($artistId) {
                            $spotifyArtist = Get-Artist -Id $artistId -ErrorAction SilentlyContinue
                            if ($spotifyArtist -and $spotifyArtist.genres -and $spotifyArtist.genres.Count -gt 0) {
                                # Add Spotify genres that aren't already present
                                foreach ($spotifyGenre in $spotifyArtist.genres) {
                                    if ($spotifyGenre -notin $existingGenres -and $spotifyGenre -notin $suggestedGenres) {
                                        $suggestedGenres += $spotifyGenre
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Verbose "Could not fetch artist genres: $($_.Exception.Message)"
                    }
                }
                
                # Only update if we have new genres to add
                if ($suggestedGenres.Count -gt 0) {
                    $finalGenres = @($existingGenres) + @($suggestedGenres)
                    
                    if (-not $WhatIfPreference) {
                        $tag.Genres = $finalGenres
                    }
                    $changesMadeToFile = $true
                    
                    if ($existingGenres.Count -gt 0) {
                        $changes += "Genres: Added '$($suggestedGenres -join ', ')' to existing '$($existingGenres -join ', ')'"
                    } else {
                        $changes += "Genres: '$($suggestedGenres -join ', ')'"
                    }
                }
            }
            
            # Fill missing or correct artist information (separate track vs album artists)
            $suggestedArtist = $null
            $suggestedAlbumArtist = $null
            # Fetch album tracks if not already available in SpotifyAlbum
            if ($SpotifyAlbum -and -not $SpotifyAlbum.tracks) {
                try {
                    $albumTracks = Get-AlbumTracks -Id $SpotifyAlbum.id
                    # Assume Get-AlbumTracks returns an array of track objects
                    $SpotifyAlbum | Add-Member -MemberType NoteProperty -Name tracks -Value @{ items = $albumTracks }
                    $SpotifyAlbum.tracks = @{ items = $albumTracks }
                    Write-Verbose "Fetched $($albumTracks.Count) tracks for album '$($SpotifyAlbum.name)'"
                } catch {
                    Write-Verbose "Could not fetch album tracks: $($_.Exception.Message)"
                }
            }
            # Get track-specific artist from Spotify track data first
            if ($SpotifyAlbum -and $SpotifyAlbum.tracks -and $SpotifyAlbum.tracks.items -and $track.Track -gt 0) {
                $spotifyTrack = $SpotifyAlbum.tracks.items | Where-Object { $_.track_number -eq $track.Track }
                if ($spotifyTrack -and $spotifyTrack.artists -and $spotifyTrack.artists.Count -gt 0) {
                    # Use track-specific artists (handles featuring artists correctly)
                    $trackArtistNames = $spotifyTrack.artists | ForEach-Object { $_.name }
                    $suggestedArtist = $trackArtistNames -join ', '
                    Write-Verbose "Track $($track.Track): Found track artists: $suggestedArtist"
                }
            }
            
            # Get album artist from Spotify album data
            if ($SpotifyAlbum -and $SpotifyAlbum.artists -and $SpotifyAlbum.artists.Count -gt 0) {
                $albumArtistNames = $SpotifyAlbum.artists | ForEach-Object { $_.name }
                $suggestedAlbumArtist = $albumArtistNames -join ', '
            }
            
            # Fall back to album artist for track artist if no track-specific data found
            if (-not $suggestedArtist -and $suggestedAlbumArtist) {
                $suggestedArtist = $suggestedAlbumArtist
            }
            
            # Check what needs fixing
            $needsTrackArtistFix = [string]::IsNullOrWhiteSpace($track.Artist) -or $track.Artist.Length -le 2
            $needsAlbumArtistFix = [string]::IsNullOrWhiteSpace($track.AlbumArtist) -or $track.AlbumArtist.Length -le 2
            
            # Handle TrackArtists (individual track performers)
            if ('TrackArtists' -in $tagsToFix -and $suggestedArtist -and $suggestedArtist -ne $track.Artist) {
                if (-not $WhatIfPreference) {
                    $tag.Performers = @($suggestedArtist)
                }
                $changesMadeToFile = $true
                if ($needsTrackArtistFix) {
                    $changes += "TrackArtist: '$suggestedArtist'"
                } else {
                    $changes += "TrackArtist: '$suggestedArtist' (was: '$($track.Artist)')"
                }
            }
            
            # Handle AlbumArtists (album-level artist - default behavior)
            if ('AlbumArtists' -in $tagsToFix -and $suggestedAlbumArtist -and $suggestedAlbumArtist -ne $track.AlbumArtist) {
                if (-not $WhatIfPreference) {
                    $tag.AlbumArtists = @($suggestedAlbumArtist)
                }
                $changesMadeToFile = $true
                if ($needsAlbumArtistFix) {
                    $changes += "AlbumArtist: '$suggestedAlbumArtist'"
                } else {
                    $changes += "AlbumArtist: '$suggestedAlbumArtist' (was: '$($track.AlbumArtist)')"
                }
            }
            
            # Optimize classical music tags
            if ($OptimizeClassicalTags -and $track.IsClassical) {
                $optimizations = @()
                
                # Set composer as album artist if not set
                if ($track.Composer -and (-not $tag.AlbumArtists -or $tag.AlbumArtists.Count -eq 0)) {
                    if (-not $WhatIfPreference) {
                        $tag.AlbumArtists = @($track.Composer)
                    }
                    $optimizations += "AlbumArtist: '$($track.Composer)' (composer)"
                    $changesMadeToFile = $true
                }
                
                # Add conductor to comment if found and not already there
                if ($track.Conductor -and (-not $tag.Comment -or $tag.Comment -notlike "*Conductor:*")) {
                    $conductorInfo = "Conductor: $($track.Conductor)"
                    $newComment = if ($tag.Comment) { "$($tag.Comment); $conductorInfo" } else { $conductorInfo }
                    
                    if (-not $WhatIfPreference) {
                        $tag.Comment = $newComment
                    }
                    $optimizations += "Comment: Added conductor info"
                    $changesMadeToFile = $true
                }
                
                if ($optimizations.Count -gt 0) {
                    $changes += $optimizations
                }
            }
            
            # Save changes if any were made
            if ($changesMadeToFile) {
                if (-not $WhatIfPreference) {
                    $fileObj.Save()
                    $changesMade++
                    
                    Write-Host "  ✓ Updated: $($track.FileName)" -ForegroundColor Green
                    foreach ($change in $changes) {
                        Write-Host "    $change" -ForegroundColor Gray
                    }
                } else {
                    # WhatIf mode - show what would be updated with clean list format
                    Write-Host "  ✓ Would update: $($track.FileName)" -ForegroundColor Yellow
                    foreach ($change in $changes) {
                        Write-Host "    $change" -ForegroundColor Gray
                    }
                }
            } elseif ($changes.Count -gt 0) {
                # Show informational messages (warnings, manual review needed, etc.)
                Write-Host "  ⚠️ Review needed: $($track.FileName)" -ForegroundColor Magenta
                foreach ($change in $changes) {
                    Write-Host "    $change" -ForegroundColor Gray
                }
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                Path = $track.Path
                FileName = $track.FileName
                ChangesApplied = $changes
                Success = $changesMadeToFile
            }
            
            $results += $result
            
            # Log if requested
            if ($LogTo) {
                $logEntry = @{
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    File = $track.FileName
                    Changes = $changes
                    Success = $changesMadeToFile
                }
                $logEntry | ConvertTo-Json | Add-Content -Path $LogTo
            }
            
            # Clean up
            $fileObj.Dispose()
            
        } catch {
            Write-Warning "Failed to update tags for $($track.FileName): $($_.Exception.Message)"
            
            $result = [PSCustomObject]@{
                Path = $track.Path
                FileName = $track.FileName
                ChangesApplied = @()
                Success = $false
                Error = $_.Exception.Message
            }
            
            $results += $result
        }
    }
    
    # Summary
    Write-Host "`nTag Enhancement Summary:" -ForegroundColor Cyan
    Write-Host "  Files processed: $($existingTags.Count)" -ForegroundColor Gray
    
    if ($WhatIfPreference) {
        $wouldUpdate = ($results | Where-Object { $_.ChangesApplied.Count -gt 0 }).Count
        Write-Host "  Files that would be updated: $wouldUpdate" -ForegroundColor Yellow
        Write-Host "  Files that would remain unchanged: $($existingTags.Count - $wouldUpdate)" -ForegroundColor Gray
    } else {
        Write-Host "  Files updated: $changesMade" -ForegroundColor Green
        Write-Host "  Files unchanged: $($existingTags.Count - $changesMade)" -ForegroundColor Gray
    }
    
    if ($LogTo) {
        Write-Host "  Log saved to: $LogTo" -ForegroundColor Yellow
    }
    
    return $results
}