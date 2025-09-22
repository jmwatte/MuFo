#!/usr/bin/env pwsh
#Requires -Version 7.3

<#
.SYNOPSIS
    Test data-driven duration validation against real music library analysis results.

.DESCRIPTION
    Validates the new data-driven tolerance functionality using empirical thresholds
    derived from real music library analysis. Tests against albums with known
    track length characteristics (short, normal, long, epic).

.NOTES
    Author: jmw
    Version: 1.0
    Date: 2025-01-11
    Tests: Data-driven validation thresholds and confidence scoring
#>

[CmdletBinding()]
param(
    [string]$TestMusicPath = "D:\_CorrectedMusic"
)

# Import MuFo module functions for testing
$moduleRoot = Split-Path $PSScriptRoot -Parent
Push-Location $moduleRoot

try {
    # Load the specific functions we're testing
    . ".\Private\Compare-TrackDurations.ps1"
    . ".\Private\Get-TrackTags.ps1"
    
    Write-Host "🧪 TESTING DATA-DRIVEN DURATION VALIDATION" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    # Test 1: Verify data-driven tolerances are applied correctly
    Write-Host "🔬 Test 1: Data-Driven Tolerance Application" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    
    # Create mock tracks for each category
    $shortTrack = [PSCustomObject]@{
        Title = "Short Track"
        FilePath = "test-short.mp3"
        Duration = "01:30"
        DurationSeconds = 90
    }
    
    $normalTrack = [PSCustomObject]@{
        Title = "Normal Track"
        FilePath = "test-normal.mp3"
        Duration = "04:15"
        DurationSeconds = 255
    }
    
    $longTrack = [PSCustomObject]@{
        Title = "Long Track"  
        FilePath = "test-long.mp3"
        Duration = "08:30"
        DurationSeconds = 510
    }
    
    $epicTrack = [PSCustomObject]@{
        Title = "Epic Track"
        FilePath = "test-epic.mp3"
        Duration = "15:45"
        DurationSeconds = 945
    }
    
    # Mock Spotify tracks with slight differences
    $spotifyShort = @{ name = "Short Track"; duration_ms = 88000 }    # 2s difference
    $spotifyNormal = @{ name = "Normal Track"; duration_ms = 245000 }  # 10s difference
    $spotifyLong = @{ name = "Long Track"; duration_ms = 520000 }      # 10s difference
    $spotifyEpic = @{ name = "Epic Track"; duration_ms = 985000 }      # 40s difference
    
    # Test data-driven validation vs percentage-based
    Write-Host "📊 Comparing validation methods..." -ForegroundColor White
    
    $testCases = @(
        @{ Local = $shortTrack; Spotify = $spotifyShort; Category = "Short"; ExpectedDiff = 2 }
        @{ Local = $normalTrack; Spotify = $spotifyNormal; Category = "Normal"; ExpectedDiff = 10 }
        @{ Local = $longTrack; Spotify = $spotifyLong; Category = "Long"; ExpectedDiff = 10 }
        @{ Local = $epicTrack; Spotify = $spotifyEpic; Category = "Epic"; ExpectedDiff = 40 }
    )
    
    foreach ($case in $testCases) {
        $localTracks = @($case.Local)
        $spotifyTracks = @($case.Spotify)
        
        # Test with percentage-based (Normal level)
        $percentageResult = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks -TolerancePercent 5.0
        
        # Test with data-driven
        $dataDrivenResult = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks -UseDataDrivenTolerance
        
        Write-Host "   $($case.Category) track ($($case.ExpectedDiff)s difference):" -ForegroundColor Cyan
        Write-Host "      Percentage-based tolerance: $($percentageResult.Results[0].ToleranceSeconds)s" -ForegroundColor Gray
        Write-Host "      Data-driven tolerance: $($dataDrivenResult.Results[0].ToleranceSeconds)s" -ForegroundColor Gray
        Write-Host "      Percentage mismatch: $($percentageResult.Results[0].IsSignificantMismatch)" -ForegroundColor Gray
        Write-Host "      Data-driven mismatch: $($dataDrivenResult.Results[0].IsSignificantMismatch)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Test 2: Real album validation with data-driven mode
    if (Test-Path $TestMusicPath) {
        Write-Host "🔬 Test 2: Real Album Validation" -ForegroundColor Yellow
        Write-Host "===============================" -ForegroundColor Yellow
        
        # Find an album with mixed track lengths
        $testAlbum = Get-ChildItem -Path $TestMusicPath -Directory -Recurse | 
                     Where-Object { (Get-ChildItem $_.FullName -File -Filter "*.mp3").Count -ge 5 } |
                     Select-Object -First 1
        
        if ($testAlbum) {
            Write-Host "📀 Testing with album: $($testAlbum.FullName)" -ForegroundColor White
            
            # Extract local track data
            $audioFiles = Get-ChildItem -Path $testAlbum.FullName -File -Filter "*.mp3" | Sort-Object Name | Select-Object -First 5
            $localTracks = @()
            
            foreach ($file in $audioFiles) {
                try {
                    $tags = Get-TrackTags -Path $file.FullName
                    $localTracks += $tags
                } catch {
                    Write-Warning "Could not read tags from: $($file.Name)"
                }
            }
            
            if ($localTracks.Count -ge 3) {
                # Create mock Spotify data with realistic variations
                $spotifyTracks = @()
                foreach ($track in $localTracks) {
                    # Add random variation: ±5-30 seconds
                    $variation = Get-Random -Minimum -30 -Maximum 31
                    $newDuration = [math]::Max(10, $track.DurationSeconds + $variation)
                    
                    $spotifyTracks += @{
                        name = $track.Title
                        duration_ms = $newDuration * 1000
                    }
                }
                
                # Test both validation methods
                $percentageValidation = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks -TolerancePercent 5.0
                $dataDrivenValidation = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks -UseDataDrivenTolerance
                
                Write-Host "📊 Validation Results Comparison:" -ForegroundColor Cyan
                Write-Host "   Percentage-based mismatches: $($percentageValidation.Summary.SignificantMismatches)" -ForegroundColor White
                Write-Host "   Data-driven mismatches: $($dataDrivenValidation.Summary.SignificantMismatches)" -ForegroundColor White
                Write-Host "   Percentage-based avg confidence: $($percentageValidation.Summary.AverageConfidence)%" -ForegroundColor White
                Write-Host "   Data-driven avg confidence: $($dataDrivenValidation.Summary.AverageConfidence)%" -ForegroundColor White
                Write-Host ""
                
                # Show track length distribution
                $trackBreakdown = $dataDrivenValidation.Summary.TrackLengthBreakdown
                Write-Host "📈 Track Length Distribution:" -ForegroundColor Cyan
                Write-Host "   Short (0-2min): $($trackBreakdown.Short) tracks" -ForegroundColor Gray
                Write-Host "   Normal (2-7min): $($trackBreakdown.Normal) tracks" -ForegroundColor Gray
                Write-Host "   Long (7-10min): $($trackBreakdown.Long) tracks" -ForegroundColor Gray
                Write-Host "   Epic (10min+): $($trackBreakdown.Epic) tracks" -ForegroundColor Gray
                Write-Host ""
                
            } else {
                Write-Warning "Not enough readable tracks in test album"
            }
        } else {
            Write-Warning "No suitable test album found in $TestMusicPath"
        }
    } else {
        Write-Warning "Test music path not found: $TestMusicPath"
    }
    
    # Test 3: Edge case validation
    Write-Host "🔬 Test 3: Edge Case Validation" -ForegroundColor Yellow
    Write-Host "==============================" -ForegroundColor Yellow
    
    # Test with extreme differences
    $extremeTests = @(
        @{
            Name = "Huge difference on short track"
            Local = [PSCustomObject]@{ Title = "Test"; FilePath = "test.mp3"; Duration = "01:30"; DurationSeconds = 90 }
            Spotify = @{ name = "Test"; duration_ms = 150000 }  # 60s difference
            ExpectedDataDrivenFail = $true
            ExpectedPercentageFail = $true
        }
        @{
            Name = "Small difference on epic track"
            Local = [PSCustomObject]@{ Title = "Test Epic"; FilePath = "epic.mp3"; Duration = "20:00"; DurationSeconds = 1200 }
            Spotify = @{ name = "Test Epic"; duration_ms = 1260000 }  # 60s difference
            ExpectedDataDrivenPass = $true
            ExpectedPercentagePass = $false  # 5% of 1200s = 60s, so it's borderline
        }
    )
    
    foreach ($test in $extremeTests) {
        Write-Host "   Testing: $($test.Name)" -ForegroundColor Cyan
        
        $percentageResult = Compare-TrackDurations -LocalTracks @($test.Local) -SpotifyTracks @($test.Spotify) -TolerancePercent 5.0
        $dataDrivenResult = Compare-TrackDurations -LocalTracks @($test.Local) -SpotifyTracks @($test.Spotify) -UseDataDrivenTolerance
        
        $percentageMismatch = $percentageResult.Results[0].IsSignificantMismatch
        $dataDrivenMismatch = $dataDrivenResult.Results[0].IsSignificantMismatch
        
        Write-Host "      Difference: $($percentageResult.Results[0].DifferenceSeconds)s" -ForegroundColor Gray
        Write-Host "      Percentage tolerance: $($percentageResult.Results[0].ToleranceSeconds)s (mismatch: $percentageMismatch)" -ForegroundColor Gray
        Write-Host "      Data-driven tolerance: $($dataDrivenResult.Results[0].ToleranceSeconds)s (mismatch: $dataDrivenMismatch)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "✅ Data-driven validation testing complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Key Benefits of Data-Driven Validation:" -ForegroundColor Cyan
    Write-Host "   • Based on analysis of 149 real tracks from 15 albums" -ForegroundColor White
    Write-Host "   • Category-specific tolerances (Short/Normal/Long/Epic)" -ForegroundColor White
    Write-Host "   • Empirically-derived thresholds from actual music library" -ForegroundColor White
    Write-Host "   • More accurate for edge cases (Pink Floyd epics, punk shorts)" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Usage in MuFo:" -ForegroundColor Cyan
    Write-Host "   Test-AlbumDurationConsistency -ValidationLevel DataDriven" -ForegroundColor Yellow
    Write-Host ""

} catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
} finally {
    Pop-Location
}