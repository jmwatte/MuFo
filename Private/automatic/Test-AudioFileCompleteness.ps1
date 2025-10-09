function Test-AudioFileCompleteness {
<#
.SYNOPSIS
    Validates audio file collection completeness and identifies issues.

.DESCRIPTION
    This function performs comprehensive validation of audio file collections including:
    - Missing tracks in sequence
    - Duplicate track numbers
    - File naming consistency
    - Audio quality analysis
    - Metadata consistency across album

.PARAMETER Path
    Path to a directory containing audio files (album folder).

.PARAMETER SpotifyAlbum
    Optional Spotify album object for reference validation.

.PARAMETER CheckAudioQuality
    Perform basic audio quality analysis (bitrate, sample rate consistency).

.PARAMETER CheckFileNaming
    Validate file naming patterns and consistency.

.PARAMETER SuggestFixes
    Provide suggestions for fixing identified issues.

.EXAMPLE
    Test-AudioFileCompleteness -Path "C:\Music\Arvo Pärt\1999 - Alina" -CheckAudioQuality -SuggestFixes
    
    Comprehensive validation with quality check and fix suggestions.

.NOTES
    Requires TagLib-Sharp for audio file analysis.
    Author: jmw
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [object]$SpotifyAlbum,
        
        [switch]$CheckAudioQuality,
        
        [switch]$CheckFileNaming,
        
        [switch]$SuggestFixes,
        
        [string]$LogTo
    )
    
    Write-Host "=== Audio File Completeness Analysis ===" -ForegroundColor Cyan
    Write-Host "Analyzing: $Path" -ForegroundColor Yellow
    
    if (-not (Test-Path $Path -PathType Container)) {
        Write-Error "Path does not exist or is not a directory: $Path"
        return
    }
    
    # Get all audio file tags (this will now exclude lib folders)
    $audioTags = Get-AudioFileTags -Path $Path -IncludeComposer
    
    if ($audioTags.Count -eq 0) {
        Write-Warning "No audio files found in: $Path"
        return
    }
    
    $issues = @()
    $analysis = @{
        TotalFiles = $audioTags.Count
        Issues = @()
        Suggestions = @()
        QualityMetrics = @{}
        AlbumInfo = @{}
    }
    
    Write-Host "`n--- Track Sequence Analysis ---" -ForegroundColor Green
    
    # Analyze track numbering
    $tracksWithNumbers = $audioTags | Where-Object { $_.Track -gt 0 }
    $trackNumbers = $tracksWithNumbers | ForEach-Object { $_.Track } | Sort-Object
    
    if ($tracksWithNumbers.Count -eq 0) {
        $issues += "No track numbers found in any files"
        if ($SuggestFixes) {
            $analysis.Suggestions += "Use Set-AudioFileTags -FillMissingTrackNumbers to assign track numbers"
        }
    } else {
        # Check for gaps in sequence
        $expectedMax = if ($SpotifyAlbum -and $SpotifyAlbum.total_tracks) { $SpotifyAlbum.total_tracks } else { $audioTags.Count }
        $expectedSequence = 1..$expectedMax
        
        $missingTracks = $expectedSequence | Where-Object { $_ -notin $trackNumbers }
        $duplicateTracks = $trackNumbers | Group-Object | Where-Object { $_.Count -gt 1 }
        $extraTracks = $trackNumbers | Where-Object { $_ -gt $expectedMax }
        
        if ($missingTracks) {
            $missingList = $missingTracks -join ', '
            $issues += "Missing track numbers: $missingList"
            Write-Host "  ⚠️ Missing tracks: $missingList" -ForegroundColor Red
        }
        
        if ($duplicateTracks) {
            $duplicateList = $duplicateTracks.Name -join ', '
            $issues += "Duplicate track numbers: $duplicateList"
            Write-Host "  ⚠️ Duplicate tracks: $duplicateList" -ForegroundColor Red
        }
        
        if ($extraTracks) {
            $extraList = $extraTracks -join ', '
            $issues += "Unexpected track numbers: $extraList"
            Write-Host "  ⚠️ Extra tracks: $extraList" -ForegroundColor Yellow
        }
        
        if (-not $missingTracks -and -not $duplicateTracks -and -not $extraTracks) {
            Write-Host "  ✅ Track sequence is complete and valid" -ForegroundColor Green
        }
    }
    
    Write-Host "`n--- Metadata Consistency Analysis ---" -ForegroundColor Green
    
    # Album name consistency
    $albums = $audioTags | Where-Object { $_.Album } | Group-Object Album
    if ($albums.Count -gt 1) {
        $albumList = $albums.Name -join ', '
        $issues += "Inconsistent album names: $albumList"
        Write-Host "  ⚠️ Multiple album names: $albumList" -ForegroundColor Red
        if ($SuggestFixes) {
            $mostCommon = $albums | Sort-Object Count -Descending | Select-Object -First 1
            $analysis.Suggestions += "Consider standardizing to: '$($mostCommon.Name)'"
        }
    } else {
        $analysis.AlbumInfo.Album = $albums[0].Name
        Write-Host "  ✅ Album name consistent: $($albums[0].Name)" -ForegroundColor Green
    }
    
    # Artist consistency
    $artists = $audioTags | Where-Object { $_.Artist } | Group-Object Artist
    if ($artists.Count -gt 3) {  # Allow some variation for features/collaborations
        $artistList = $artists.Name | Select-Object -First 5 | Join-String -Separator ', '
        $issues += "Many different artists: $artistList..."
        Write-Host "  ⚠️ Multiple artists (compilation?): $artistList..." -ForegroundColor Yellow
    } else {
        $analysis.AlbumInfo.Artist = $artists | Sort-Object Count -Descending | Select-Object -First 1 | ForEach-Object { $_.Name }
        Write-Host "  ✅ Artist consistency good" -ForegroundColor Green
    }
    
    # Year consistency
    $years = $audioTags | Where-Object { $_.Year -gt 0 } | Group-Object Year
    if ($years.Count -gt 1) {
        $yearList = $years.Name -join ', '
        $issues += "Inconsistent years: $yearList"
        Write-Host "  ⚠️ Multiple years: $yearList" -ForegroundColor Red
    } elseif ($years.Count -eq 1) {
        $analysis.AlbumInfo.Year = $years[0].Name
        Write-Host "  ✅ Year consistent: $($years[0].Name)" -ForegroundColor Green
    } else {
        $issues += "No year information found"
        Write-Host "  ⚠️ No year information" -ForegroundColor Yellow
    }
    
    # Missing titles
    $missingTitles = $audioTags | Where-Object { [string]::IsNullOrWhiteSpace($_.Title) }
    if ($missingTitles.Count -gt 0) {
        $issues += "$($missingTitles.Count) files missing track titles"
        Write-Host "  ⚠️ $($missingTitles.Count) files missing titles" -ForegroundColor Red
        if ($SuggestFixes) {
            $analysis.Suggestions += "Use Set-AudioFileTags -FillMissingTitles to populate titles from filenames"
        }
    } else {
        Write-Host "  ✅ All tracks have titles" -ForegroundColor Green
    }
    
    # File naming analysis
    if ($CheckFileNaming) {
        Write-Host "`n--- File Naming Analysis ---" -ForegroundColor Green
        
        $namingPatterns = @()
        foreach ($file in $audioTags) {
            $filename = [System.IO.Path]::GetFileNameWithoutExtension($file.FileName)
            
            if ($filename -match '^\d{2,3}\s*[-\.]\s*.+') {
                $namingPatterns += "TrackNum-Title"
            } elseif ($filename -match '^\d{1,2}\s+.+') {
                $namingPatterns += "TrackNum Title"
            } elseif ($filename -match '^.+\s*[-\.]\s*.+') {
                $namingPatterns += "Artist-Title"
            } else {
                $namingPatterns += "Other"
            }
        }
        
        $patternGroups = $namingPatterns | Group-Object
        $dominantPattern = $patternGroups | Sort-Object Count -Descending | Select-Object -First 1
        
        if ($patternGroups.Count -gt 1) {
            $issues += "Inconsistent file naming patterns"
            Write-Host "  ⚠️ Mixed naming patterns:" -ForegroundColor Yellow
            foreach ($pattern in $patternGroups) {
                Write-Host "    $($pattern.Name): $($pattern.Count) files" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✅ Consistent naming pattern: $($dominantPattern.Name)" -ForegroundColor Green
        }
    }
    
    # Audio quality analysis
    if ($CheckAudioQuality) {
        Write-Host "`n--- Audio Quality Analysis ---" -ForegroundColor Green
        
        $bitrates = $audioTags | Where-Object { $_.Bitrate -gt 0 } | ForEach-Object { $_.Bitrate }
        $sampleRates = $audioTags | Where-Object { $_.SampleRate -gt 0 } | ForEach-Object { $_.SampleRate }
        $formats = $audioTags | Group-Object Format
        
        if ($bitrates.Count -gt 0) {
            $avgBitrate = [math]::Round(($bitrates | Measure-Object -Average).Average, 0)
            $minBitrate = ($bitrates | Measure-Object -Minimum).Minimum
            $maxBitrate = ($bitrates | Measure-Object -Maximum).Maximum
            
            $analysis.QualityMetrics.AverageBitrate = $avgBitrate
            $analysis.QualityMetrics.BitrateRange = "$minBitrate - $maxBitrate kbps"
            
            Write-Host "  Bitrate: $avgBitrate kbps average ($minBitrate - $maxBitrate)" -ForegroundColor Gray
            
            if ($maxBitrate - $minBitrate -gt 100) {
                $issues += "Large bitrate variation ($minBitrate - $maxBitrate kbps)"
                Write-Host "  ⚠️ Large bitrate variation" -ForegroundColor Yellow
            }
        }
        
        if ($sampleRates.Count -gt 0) {
            $uniqueSampleRates = $sampleRates | Sort-Object -Unique
            $analysis.QualityMetrics.SampleRates = $uniqueSampleRates -join ', '
            
            if ($uniqueSampleRates.Count -gt 1) {
                $issues += "Mixed sample rates: $($uniqueSampleRates -join ', ') Hz"
                Write-Host "  ⚠️ Mixed sample rates: $($uniqueSampleRates -join ', ') Hz" -ForegroundColor Yellow
            } else {
                Write-Host "  ✅ Consistent sample rate: $($uniqueSampleRates[0]) Hz" -ForegroundColor Green
            }
        }
        
        if ($formats.Count -gt 1) {
            $formatList = $formats.Name -join ', '
            $issues += "Mixed audio formats: $formatList"
            Write-Host "  ⚠️ Mixed formats: $formatList" -ForegroundColor Yellow
        } else {
            Write-Host "  ✅ Consistent format: $($formats[0].Name)" -ForegroundColor Green
        }
    }
    
    # Classical music specific checks
    $classicalTracks = $audioTags | Where-Object { $_.IsClassical -eq $true }
    if ($classicalTracks.Count -gt 0) {
        Write-Host "`n--- Classical Music Analysis ---" -ForegroundColor Green
        
        $composers = $classicalTracks | Where-Object { $_.Composer } | Group-Object Composer
        $conductors = $classicalTracks | Where-Object { $_.Conductor } | Group-Object Conductor
        
        if ($composers.Count -eq 0) {
            $issues += "Classical music detected but no composer information found"
            Write-Host "  ⚠️ No composer information" -ForegroundColor Red
            if ($SuggestFixes) {
                $analysis.Suggestions += "Use Set-AudioFileTags -OptimizeClassicalTags to enhance composer metadata"
            }
        } else {
            Write-Host "  ✅ Composer(s): $($composers.Name -join ', ')" -ForegroundColor Green
        }
        
        if ($conductors.Count -gt 0) {
            Write-Host "  ✅ Conductor(s): $($conductors.Name -join ', ')" -ForegroundColor Green
        }
    }
    
    # Spotify comparison if available
    if ($SpotifyAlbum) {
        Write-Host "`n--- Spotify Comparison ---" -ForegroundColor Green
        
        if ($SpotifyAlbum.total_tracks -ne $audioTags.Count) {
            $issues += "Track count mismatch: Local $($audioTags.Count) vs Spotify $($SpotifyAlbum.total_tracks)"
            Write-Host "  ⚠️ Track count: Local $($audioTags.Count) vs Spotify $($SpotifyAlbum.total_tracks)" -ForegroundColor Red
        } else {
            Write-Host "  ✅ Track count matches Spotify: $($audioTags.Count)" -ForegroundColor Green
        }
    }
    
    # Summary
    $analysis.Issues = $issues
    
    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "Files analyzed: $($audioTags.Count)" -ForegroundColor Gray
    Write-Host "Issues found: $($issues.Count)" -ForegroundColor $(if ($issues.Count -eq 0) { 'Green' } else { 'Red' })
    
    if ($issues.Count -eq 0) {
        Write-Host "🎉 No issues found! Album appears to be complete and well-organized." -ForegroundColor Green
    } else {
        Write-Host "`nIssues:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($SuggestFixes -and $analysis.Suggestions.Count -gt 0) {
        Write-Host "`nSuggested fixes:" -ForegroundColor Cyan
        foreach ($suggestion in $analysis.Suggestions) {
            Write-Host "  💡 $suggestion" -ForegroundColor White
        }
    }
    
    # Log results if requested
    if ($LogTo) {
        $logEntry = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Path = $Path
            Analysis = $analysis
        }
        $logEntry | ConvertTo-Json -Depth 10 | Add-Content -Path $LogTo
        Write-Host "`nAnalysis logged to: $LogTo" -ForegroundColor Yellow
    }
    
    return $analysis
}