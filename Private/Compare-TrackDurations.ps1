function Compare-TrackDurations {
<#
.SYNOPSIS
    Compare track durations between files and Spotify data for validation.

.DESCRIPTION
    Analyzes duration discrepancies to detect potential track order issues,
    file corruption, or mismatched tracks. Uses percentage-based tolerance
    that scales with track length (short songs vs. long epics).

.PARAMETER LocalTracks
    Array of track objects with file information and durations.

.PARAMETER SpotifyTracks  
    Array of Spotify track objects with expected durations.

.PARAMETER TolerancePercent
    Maximum acceptable difference as percentage of track length.
    Default: 5% (e.g., 3s for 1min track, 30s for 10min track).

.PARAMETER WarnThresholdPercent
    Threshold percentage for showing warnings. Default: 3%.

.PARAMETER MinToleranceSeconds
    Minimum absolute tolerance in seconds (for very short tracks).
    Default: 3 seconds.

.PARAMETER MaxToleranceSeconds
    Maximum absolute tolerance in seconds (for very long tracks).
    Default: 60 seconds.

.EXAMPLE
    Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks

.EXAMPLE
    Compare-TrackDurations -LocalTracks $tracks -SpotifyTracks $spotify -TolerancePercent 8

.NOTES
    Author: jmw
    Part of MuFo duration-based validation system.
    Uses intelligent scaling: short tracks have tight tolerances, long tracks have looser ones.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$LocalTracks,
        
        [Parameter(Mandatory = $true)] 
        [array]$SpotifyTracks,
        
        [double]$TolerancePercent = 5.0,
        
        [double]$WarnThresholdPercent = 3.0,
        
        [int]$MinToleranceSeconds = 3,
        
        [int]$MaxToleranceSeconds = 60,
        
        [Parameter()]
        [switch]$UseDataDrivenTolerance
    )
    
    # Data-driven tolerance settings based on real-world music library analysis
    # Source: Real music collection analysis of 149 tracks from 15 albums
    $dataDrivenTolerances = @{
        Short = @{   # 0-2min tracks (avg: 01:34, ±28.2s)
            Strict = 28    # 29.8% of std dev
            Normal = 42    # 44.7% of std dev  
            Relaxed = 70   # 74.5% of std dev
        }
        Normal = @{  # 2-7min tracks (avg: 03:37, ±71.4s)
            Strict = 71    # 32.8% of std dev
            Normal = 107   # 49.2% of std dev
            Relaxed = 178  # 82% of std dev
        }
        Long = @{    # 7-10min tracks (avg: 08:21, ±59.1s)
            Strict = 59    # 11.8% of std dev
            Normal = 89    # 17.7% of std dev
            Relaxed = 148  # 29.5% of std dev
        }
        Epic = @{    # 10min+ tracks (avg: 13:52, ±220.5s)
            Strict = 220   # 26.5% of std dev
            Normal = 331   # 39.8% of std dev
            Relaxed = 551  # 66.2% of std dev
        }
    }
    
    if ($UseDataDrivenTolerance) {
        Write-Verbose "Using data-driven tolerances from real music library analysis"
    } else {
        Write-Verbose "Comparing durations with $TolerancePercent% tolerance (min: ${MinToleranceSeconds}s, max: ${MaxToleranceSeconds}s)"
    }
    
    $convertToSeconds = {
        param($value)

        if ($null -eq $value) {
            return $null
        }

        if ($value -is [double] -or $value -is [single] -or $value -is [decimal] -or $value -is [int] -or $value -is [long]) {
            return [double]$value
        }

        $stringValue = $value.ToString()
        if ([string]::IsNullOrWhiteSpace($stringValue)) {
            return $null
        }

        $parsedValue = 0.0
        if ([double]::TryParse($stringValue, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedValue)) {
            return $parsedValue
        }

        return $null
    }

    $results = @()
    $mismatches = @()
    
    # Try to match tracks by position first, then by title similarity
    for ($i = 0; $i -lt [Math]::Min($LocalTracks.Count, $SpotifyTracks.Count); $i++) {
        $localTrack = $LocalTracks[$i]
        $spotifyTrack = $SpotifyTracks[$i]
        
        # Get durations in seconds - ensure numeric conversion
        $localDurationValue = & $convertToSeconds $localTrack.DurationSeconds
        if ($null -eq $localDurationValue) {
            Write-Verbose "Could not parse local track duration for '$($localTrack.Title)'"
            $localDurationValue = 0.0
        }

        $localDurationSec = $localDurationValue
        
        $spotifyDurationSec = if ($spotifyTrack.duration_ms) { 
            [double]$spotifyTrack.duration_ms / 1000.0 
        } else { 
            0.0 
        }
        
        $difference = [math]::Abs($localDurationSec - $spotifyDurationSec)
        
        # Calculate average duration for track categorization and percentage calculations
        $avgDuration = ($localDurationSec + $spotifyDurationSec) / 2
        
        # Determine track length category for data-driven tolerances
        $trackCategory = if ($avgDuration -lt 120) { "Short" }
                        elseif ($avgDuration -lt 420) { "Normal" }
                        elseif ($avgDuration -lt 600) { "Long" }
                        else { "Epic" }
        
        if ($UseDataDrivenTolerance) {
            # Use empirically-derived tolerances from real music library analysis
            $toleranceSeconds = $dataDrivenTolerances[$trackCategory].Normal
            $warnThresholdSeconds = $dataDrivenTolerances[$trackCategory].Strict
        } else {
            # Calculate percentage-based tolerances (original logic)
            $toleranceSeconds = [math]::Max($MinToleranceSeconds, 
                                          [math]::Min($MaxToleranceSeconds, 
                                                     $avgDuration * ($TolerancePercent / 100)))
            
            $warnThresholdSeconds = [math]::Max($MinToleranceSeconds, 
                                              [math]::Min($MaxToleranceSeconds, 
                                                         $avgDuration * ($WarnThresholdPercent / 100)))
        }
        
        # Calculate percentage difference for reporting
        $percentDifference = if ($avgDuration -gt 0) { 
            [math]::Round(($difference / $avgDuration) * 100, 1) 
        } else { 
            0 
        }
        
        $result = [PSCustomObject]@{
            TrackNumber = $i + 1
            LocalTitle = $localTrack.Title
            SpotifyTitle = $spotifyTrack.name
            LocalPath = $localTrack.FilePath
            LocalDuration = if ($localDurationSec -gt 0) { 
                try { [TimeSpan]::FromSeconds($localDurationSec).ToString("mm\:ss") } catch { "00:00" }
            } else { "00:00" }
            LocalDurationSeconds = [math]::Round($localDurationSec, 3)
            SpotifyDuration = [TimeSpan]::FromSeconds($spotifyDurationSec).ToString("mm\:ss")
            SpotifyDurationSeconds = [math]::Round($spotifyDurationSec, 3)
            DifferenceSeconds = [math]::Round($difference, 3)
            PercentDifference = $percentDifference
            ToleranceSeconds = [math]::Round($toleranceSeconds)
            TolerancePercent = $TolerancePercent
            IsSignificantMismatch = $difference -gt $toleranceSeconds
            ShouldWarn = $difference -gt $warnThresholdSeconds
            Confidence = if ($difference -eq 0) { 100 } 
                        elseif ($percentDifference -le 1) { 95 }
                        elseif ($percentDifference -le 2) { 90 }
                        elseif ($percentDifference -le 3) { 85 }
                        elseif ($percentDifference -le 5) { 75 }
                        elseif ($percentDifference -le 8) { 60 }
                        elseif ($percentDifference -le 15) { 40 }
                        else { 20 }
            TrackLength = if ($avgDuration -lt 120) { "Short" }
                         elseif ($avgDuration -lt 420) { "Normal" }
                         elseif ($avgDuration -lt 600) { "Long" }
                         else { "Epic" }
        }
        
        $results += $result
        
        if ($result.IsSignificantMismatch) {
            $mismatches += $result
        }
    }
    
    # Summary statistics
    $summary = [PSCustomObject]@{
        TotalTracks = $results.Count
        PerfectMatches = ($results | Where-Object { $_.DifferenceSeconds -eq 0 }).Count
        CloseMatches = ($results | Where-Object { $_.PercentDifference -le 1 -and $_.DifferenceSeconds -gt 0 }).Count
        AcceptableMatches = ($results | Where-Object { $_.PercentDifference -le $TolerancePercent -and $_.PercentDifference -gt 1 }).Count
        SignificantMismatches = $mismatches.Count
        AverageConfidence = [math]::Round(($results | Measure-Object -Property Confidence -Average).Average, 1)
        AveragePercentDifference = [math]::Round(($results | Measure-Object -Property PercentDifference -Average).Average, 1)
        WorstMismatch = ($results | Sort-Object PercentDifference -Descending | Select-Object -First 1)
        TrackLengthBreakdown = @{
            Short = ($results | Where-Object { $_.TrackLength -eq "Short" }).Count
            Normal = ($results | Where-Object { $_.TrackLength -eq "Normal" }).Count  
            Long = ($results | Where-Object { $_.TrackLength -eq "Long" }).Count
            Epic = ($results | Where-Object { $_.TrackLength -eq "Epic" }).Count
        }
    }
    
    return [PSCustomObject]@{
        Results = $results
        Mismatches = $mismatches
        Summary = $summary
        ToleranceSettings = @{
            TolerancePercent = $TolerancePercent
            WarnThresholdPercent = $WarnThresholdPercent
            MinToleranceSeconds = $MinToleranceSeconds
            MaxToleranceSeconds = $MaxToleranceSeconds
        }
    }
}

function Test-AlbumDurationConsistency {
<#
.SYNOPSIS
    Validate album track durations against Spotify for consistency checking.

.DESCRIPTION
    Comprehensive duration validation that checks for track order issues,
    file problems, and provides actionable feedback with clickable file paths.

.PARAMETER AlbumPath
    Path to the album folder containing audio files.

.PARAMETER SpotifyAlbumData
    Spotify album data object with track information.

.PARAMETER ShowWarnings
    Display warnings for duration mismatches. Default: $true.

.PARAMETER ValidationLevel
    Validation strictness: Strict, Normal, Relaxed. Default: Normal.

.EXAMPLE
    Test-AlbumDurationConsistency -AlbumPath "C:\Music\Artist\Album" -SpotifyAlbumData $spotifyData

.NOTES
    Author: jmw
    Requires Write-EnhancedOutput functions for clickable file paths.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlbumPath,
        
        [Parameter(Mandatory = $true)]
        [PSObject]$SpotifyAlbumData,
        
        [bool]$ShowWarnings = $true,
        
        [ValidateSet('Strict', 'Normal', 'Relaxed', 'DataDriven')]
        [string]$ValidationLevel = 'Normal'
    )
    
    # Set tolerance based on validation level
    $useDataDriven = ($ValidationLevel -eq 'DataDriven')
    
    if ($useDataDriven) {
        Write-Host "   Validation level: DataDriven (empirical thresholds from real music analysis)" -ForegroundColor Gray
    } else {
        # Set tolerance based on validation level (percentage-based)
        $tolerancePercent = switch ($ValidationLevel) {
            'Strict' { 2.0 }    # 2% tolerance (tight for critical matching)
            'Normal' { 5.0 }    # 5% tolerance (good balance)
            'Relaxed' { 10.0 }  # 10% tolerance (loose for live recordings, etc.)
        }
        
        $warnThresholdPercent = switch ($ValidationLevel) {
            'Strict' { 1.0 }    # 1% warning threshold
            'Normal' { 3.0 }    # 3% warning threshold  
            'Relaxed' { 6.0 }   # 6% warning threshold
        }
        
        # Absolute bounds (prevents extremes)
        $minToleranceSeconds = switch ($ValidationLevel) {
            'Strict' { 2 }      # Minimum 2 seconds even for short tracks
            'Normal' { 3 }      # Minimum 3 seconds
            'Relaxed' { 5 }     # Minimum 5 seconds
        }
        
        $maxToleranceSeconds = switch ($ValidationLevel) {
            'Strict' { 30 }     # Maximum 30 seconds even for epics
            'Normal' { 60 }     # Maximum 60 seconds
            'Relaxed' { 120 }   # Maximum 2 minutes for live recordings
        }
        
        Write-Host "   Validation level: $ValidationLevel ($tolerancePercent% tolerance, ${minToleranceSeconds}-${maxToleranceSeconds}s bounds)" -ForegroundColor Gray
    }
    
    Write-Host "🎵 Validating album durations..." -ForegroundColor Cyan
    Write-Host "   Album: $AlbumPath" -ForegroundColor Gray
    Write-Host ""
    
    # Get local audio files
    $audioExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')
    $audioFiles = Get-ChildItem -Path $AlbumPath -File | Where-Object { 
        $_.Extension.ToLower() -in $audioExtensions 
    } | Sort-Object Name
    
    if ($audioFiles.Count -eq 0) {
        Write-Warning "No audio files found in: $AlbumPath"
        return
    }
    
    # Extract track information with durations
    $localTracks = @()
    foreach ($file in $audioFiles) {
        try {
            $tags = Get-TrackTags -Path $file.FullName -ErrorAction Stop
            $localTracks += $tags
        } catch {
            Write-Warning "Could not read tags from: $($file.Name) - $($_.Exception.Message)"
        }
    }
    
    if ($localTracks.Count -eq 0) {
        Write-Warning "Could not read tags from any audio files"
        return
    }
    
    # Compare with Spotify data
    if ($useDataDriven) {
        $comparison = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $SpotifyAlbumData.tracks.items -UseDataDrivenTolerance
    } else {
        $comparison = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $SpotifyAlbumData.tracks.items -TolerancePercent $tolerancePercent -WarnThresholdPercent $warnThresholdPercent -MinToleranceSeconds $minToleranceSeconds -MaxToleranceSeconds $maxToleranceSeconds
    }
    
    # Display results
    Write-Host "📊 Duration Analysis Results:" -ForegroundColor Cyan
    Write-Host "   Total tracks: $($comparison.Summary.TotalTracks)" -ForegroundColor White
    Write-Host "   Perfect matches: $($comparison.Summary.PerfectMatches)" -ForegroundColor Green
    Write-Host "   Close matches: $($comparison.Summary.CloseMatches)" -ForegroundColor Yellow
    Write-Host "   Acceptable: $($comparison.Summary.AcceptableMatches)" -ForegroundColor Cyan
    Write-Host "   Significant mismatches: $($comparison.Summary.SignificantMismatches)" -ForegroundColor Red
    Write-Host "   Average confidence: $($comparison.Summary.AverageConfidence)%" -ForegroundColor White
    Write-Host ""
    
    # Show warnings for significant mismatches
    if ($ShowWarnings -and $comparison.Mismatches.Count -gt 0) {
        Write-Host "⚠️  DURATION MISMATCHES DETECTED" -ForegroundColor Yellow
        Write-Host "=================================" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($mismatch in $comparison.Mismatches) {
            Write-DurationMismatchWarning -FilePath $mismatch.LocalPath -ActualDuration $mismatch.LocalDuration -ExpectedDuration $mismatch.SpotifyDuration -TrackTitle $mismatch.LocalTitle -DifferenceSeconds $mismatch.DifferenceSeconds
        }
        
        Write-Host "🔧 Recommended Actions:" -ForegroundColor Yellow
        Write-Host "   • Click file paths above to inspect problem files" -ForegroundColor Gray
        Write-Host "   • Use manual workflow for track reordering: " -NoNewline -ForegroundColor Gray
        Write-Host "Invoke-ManualTrackMapping" -ForegroundColor Cyan
        Write-Host "   • Check for file corruption or encoding issues" -ForegroundColor Gray
        Write-Host "   • Verify these are the correct album tracks" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Show detailed results for verbose mode
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "📋 Detailed Track Comparison:" -ForegroundColor Cyan
        $comparison.Results | Format-Table TrackNumber, LocalTitle, LocalDuration, SpotifyDuration, DifferenceSeconds, Confidence -AutoSize
    }
    
    return $comparison
}

function Add-DurationValidation {
<#
.SYNOPSIS
    Add duration validation to existing MuFo album processing workflow.

.DESCRIPTION
    Integrates duration-based validation into the main MuFo workflow,
    providing enhanced accuracy for track matching and order validation.

.PARAMETER AlbumPath
    Path to album folder.

.PARAMETER SpotifyMatches
    Spotify album match results.

.PARAMETER ValidationFlags
    Hash table of validation settings.

.EXAMPLE
    Add-DurationValidation -AlbumPath $albumPath -SpotifyMatches $matches -ValidationFlags @{ Level = 'Normal'; ShowWarnings = $true }

.NOTES
    Author: jmw
    Designed to integrate with existing Get-SpotifyAlbumMatches-Fast function.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AlbumPath,
        
        [Parameter(Mandatory = $true)]
        [array]$SpotifyMatches,
        
        [hashtable]$ValidationFlags = @{}
    )
    
    # Default validation settings
    $defaults = @{
        Level = 'Normal'
        ShowWarnings = $true
        RequireValidation = $false
        EnhanceConfidence = $true
    }
    
    $settings = $defaults + $ValidationFlags
    
    Write-Verbose "Adding duration validation with level: $($settings.Level)"
    
    $enhancedMatches = @()
    
    foreach ($match in $SpotifyMatches) {
        try {
            # Perform duration validation
            $durationAnalysis = Test-AlbumDurationConsistency -AlbumPath $AlbumPath -SpotifyAlbumData $match -ShowWarnings $settings.ShowWarnings -ValidationLevel $settings.Level
            
            # Enhance match confidence based on duration analysis
            if ($settings.EnhanceConfidence -and $durationAnalysis) {
                $originalConfidence = if ($match.confidence) { $match.confidence } else { 50 }
                $durationConfidence = $durationAnalysis.Summary.AverageConfidence
                
                # Weighted combination: 70% original, 30% duration
                $enhancedConfidence = [math]::Round(($originalConfidence * 0.7) + ($durationConfidence * 0.3), 1)
                
                $match | Add-Member -NotePropertyName 'DurationValidation' -Value $durationAnalysis -Force
                $match | Add-Member -NotePropertyName 'OriginalConfidence' -Value $originalConfidence -Force
                $match | Add-Member -NotePropertyName 'EnhancedConfidence' -Value $enhancedConfidence -Force
                $match.confidence = $enhancedConfidence
            }
            
        } catch {
            Write-Warning "Duration validation failed for album: $($match.name) - $($_.Exception.Message)"
            # Keep original match without duration validation
        }
        
        $enhancedMatches += $match
    }
    
    return $enhancedMatches
}