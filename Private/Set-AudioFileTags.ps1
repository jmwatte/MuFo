function Set-AudioFileTags {
<#
.SYNOPSIS
    Writes and updates audio file tags with intelligent metadata enhancement.

.DESCRIPTION
    This function writes metadata to audio files with special enhancements for classical music.
    It can fill missing titles, track numbers, genres, and optimize album artist organization.
    Includes validation for missing tracks and metadata consistency.

.PARAMETER Path
    Path to an audio file or directory containing audio files.

.PARAMETER SpotifyAlbum
    Spotify album object to use as reference for metadata enhancement.

.PARAMETER FillMissingTitles
    Automatically fill missing track titles from filename or Spotify data.

.PARAMETER FillMissingTrackNumbers
    Automatically assign track numbers based on file order or filename patterns.

.PARAMETER FillMissingGenres
    Fill missing genre information from Spotify or infer from classical music detection.

.PARAMETER OptimizeClassicalTags
    Optimize tags for classical music (composer as album artist, conductor info, etc.).

.PARAMETER ValidateCompleteness
    Check for missing tracks in the album sequence.

.PARAMETER WhatIf
    Show what changes would be made without actually writing them.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina" -FillMissingTitles -OptimizeClassicalTags
    
    Fills missing metadata and optimizes for classical music organization.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Album" -SpotifyAlbum $album -FillMissingTrackNumbers -ValidateCompleteness
    
    Uses Spotify album data to fill track numbers and check for missing tracks.

.NOTES
    Requires TagLib-Sharp to be available for writing tags.
    Author: jmw
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [object]$SpotifyAlbum,
        
        [switch]$FillMissingTitles,
        
        [switch]$FillMissingTrackNumbers,
        
        [switch]$FillMissingGenres,
        
        [switch]$OptimizeClassicalTags,
        
        [switch]$ValidateCompleteness,
        
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
    
    $results = @()
    $changesMade = 0
    
    # Analyze album for consistency and gaps
    $albumAnalysis = @{
        AlbumName = ($existingTags | Where-Object { $_.Album } | Group-Object Album | Sort-Object Count -Descending | Select-Object -First 1).Name
        ArtistName = ($existingTags | Where-Object { $_.Artist } | Group-Object Artist | Sort-Object Count -Descending | Select-Object -First 1).Name
        IsClassical = ($existingTags | Where-Object { $_.IsClassical -eq $true }).Count -gt ($existingTags.Count / 2)
        TrackNumbers = $existingTags | Where-Object { $_.Track -gt 0 } | ForEach-Object { $_.Track } | Sort-Object
        ExpectedTracks = if ($SpotifyAlbum -and $SpotifyAlbum.total_tracks) { $SpotifyAlbum.total_tracks } else { $existingTags.Count }
    }
    
    Write-Host "Album Analysis:" -ForegroundColor Cyan
    Write-Host "  Album: $($albumAnalysis.AlbumName)" -ForegroundColor Gray
    Write-Host "  Artist: $($albumAnalysis.ArtistName)" -ForegroundColor Gray
    Write-Host "  Classical Music: $($albumAnalysis.IsClassical)" -ForegroundColor Gray
    Write-Host "  Tracks Found: $($existingTags.Count) / Expected: $($albumAnalysis.ExpectedTracks)" -ForegroundColor Gray
    
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
            
            # Fill missing titles
            if ($FillMissingTitles -and [string]::IsNullOrWhiteSpace($tag.Title)) {
                $suggestedTitle = $null
                
                # Try to extract from filename
                $filename = [System.IO.Path]::GetFileNameWithoutExtension($track.FileName)
                
                # Pattern: "01 - Track Name" or "Track Name"
                if ($filename -match '^\d+\s*[-\.]\s*(.+)$') {
                    $suggestedTitle = $matches[1].Trim()
                } elseif ($filename -match '^\d+\s+(.+)$') {
                    $suggestedTitle = $matches[1].Trim()
                } else {
                    $suggestedTitle = $filename
                }
                
                # Try to get from Spotify if available
                if ($SpotifyAlbum -and $SpotifyAlbum.tracks -and $track.Track -gt 0) {
                    $spotifyTrack = $SpotifyAlbum.tracks.items | Where-Object { $_.track_number -eq $track.Track }
                    if ($spotifyTrack) {
                        $suggestedTitle = $spotifyTrack.name
                    }
                }
                
                if ($suggestedTitle -and $PSCmdlet.ShouldProcess($track.Path, "Set title to '$suggestedTitle'")) {
                    $tag.Title = $suggestedTitle
                    $changes += "Title: '$suggestedTitle'"
                    $changesMadeToFile = $true
                }
            }
            
            # Fill missing track numbers
            if ($FillMissingTrackNumbers -and ($tag.Track -eq 0 -or -not $tag.Track)) {
                $suggestedTrackNumber = $null
                
                # Try to extract from filename
                $filename = [System.IO.Path]::GetFileNameWithoutExtension($track.FileName)
                if ($filename -match '^(\d+)') {
                    $suggestedTrackNumber = [int]$matches[1]
                } else {
                    # Use file order as fallback
                    $allFiles = Get-ChildItem -Path (Split-Path $track.Path) -Filter "*.mp3", "*.flac", "*.m4a", "*.ogg", "*.wav" | Sort-Object Name
                    $index = [Array]::IndexOf($allFiles.FullName, $track.Path)
                    if ($index -ge 0) {
                        $suggestedTrackNumber = $index + 1
                    }
                }
                
                if ($suggestedTrackNumber -and $PSCmdlet.ShouldProcess($track.Path, "Set track number to $suggestedTrackNumber")) {
                    $tag.Track = [uint32]$suggestedTrackNumber
                    $changes += "Track: $suggestedTrackNumber"
                    $changesMadeToFile = $true
                }
            }
            
            # Fill missing genres
            if ($FillMissingGenres -and (-not $tag.Genres -or $tag.Genres.Count -eq 0)) {
                $suggestedGenre = $null
                
                if ($albumAnalysis.IsClassical) {
                    $suggestedGenre = "Classical"
                } elseif ($SpotifyAlbum -and $SpotifyAlbum.genres -and $SpotifyAlbum.genres.Count -gt 0) {
                    $suggestedGenre = $SpotifyAlbum.genres[0]
                }
                
                if ($suggestedGenre -and $PSCmdlet.ShouldProcess($track.Path, "Set genre to '$suggestedGenre'")) {
                    $tag.Genres = @($suggestedGenre)
                    $changes += "Genre: '$suggestedGenre'"
                    $changesMadeToFile = $true
                }
            }
            
            # Optimize classical music tags
            if ($OptimizeClassicalTags -and $track.IsClassical) {
                $optimizations = @()
                
                # Set composer as album artist if not set
                if ($track.Composer -and (-not $tag.AlbumArtists -or $tag.AlbumArtists.Count -eq 0)) {
                    if ($PSCmdlet.ShouldProcess($track.Path, "Set album artist to composer '$($track.Composer)'")) {
                        $tag.AlbumArtists = @($track.Composer)
                        $optimizations += "AlbumArtist: '$($track.Composer)' (composer)"
                        $changesMadeToFile = $true
                    }
                }
                
                # Add conductor to comment if found and not already there
                if ($track.Conductor -and (-not $tag.Comment -or $tag.Comment -notlike "*Conductor:*")) {
                    $conductorInfo = "Conductor: $($track.Conductor)"
                    $newComment = if ($tag.Comment) { "$($tag.Comment); $conductorInfo" } else { $conductorInfo }
                    
                    if ($PSCmdlet.ShouldProcess($track.Path, "Add conductor info to comment")) {
                        $tag.Comment = $newComment
                        $optimizations += "Comment: Added conductor info"
                        $changesMadeToFile = $true
                    }
                }
                
                if ($optimizations.Count -gt 0) {
                    $changes += $optimizations
                }
            }
            
            # Save changes if any were made
            if ($changesMadeToFile) {
                $fileObj.Save()
                $changesMade++
                
                Write-Host "  ✓ Updated: $($track.FileName)" -ForegroundColor Green
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
    Write-Host "  Files updated: $changesMade" -ForegroundColor Green
    Write-Host "  Files unchanged: $($existingTags.Count - $changesMade)" -ForegroundColor Gray
    
    if ($LogTo) {
        Write-Host "  Log saved to: $LogTo" -ForegroundColor Yellow
    }
    
    return $results
}