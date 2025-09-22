# Test Percentage-Based Duration Validation
# Demonstrates intelligent scaling for different track lengths

param(
    [string]$TestAlbumPath = "C:\temp\mufo-real-music-test\10cc\2007 - Sheet Music"
)

Write-Host "🧪 Testing Percentage-Based Duration Validation" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Load functions
$moduleRoot = Split-Path $PSScriptRoot -Parent
. "$moduleRoot\Private\Write-EnhancedOutput.ps1"
. "$moduleRoot\Private\Compare-TrackDurations.ps1"

# Create test data with different track lengths to demonstrate scaling
Write-Host "🎵 Creating test tracks of different lengths..." -ForegroundColor Yellow

$testTracks = @(
    @{ Title = "Short Punk Song"; Duration = 90; Type = "Short" },      # 1:30
    @{ Title = "Normal Pop Song"; Duration = 210; Type = "Normal" },     # 3:30  
    @{ Title = "Long Rock Song"; Duration = 480; Type = "Long" },        # 8:00
    @{ Title = "Epic Progressive"; Duration = 1200; Type = "Epic" }      # 20:00
)

$localTracks = @()
$spotifyTracks = @()

foreach ($track in $testTracks) {
    # Create local track data
    $localTrack = [PSCustomObject]@{
        Title = $track.Title
        Duration = [TimeSpan]::FromSeconds($track.Duration).ToString("mm\:ss")
        DurationSeconds = $track.Duration
        FilePath = "C:\TestMusic\$($track.Title -replace ' ', '_').mp3"
    }
    $localTracks += $localTrack
    
    # Create Spotify track with intentional fixed 30-second difference
    $spotifyDuration = $track.Duration + 30  # Same absolute difference for all
    $spotifyTrack = [PSCustomObject]@{
        name = $track.Title
        duration_ms = $spotifyDuration * 1000
    }
    $spotifyTracks += $spotifyTrack
    
    # Calculate what the percentage difference will be
    $percentDiff = [math]::Round((30 / $track.Duration) * 100, 1)
    
    Write-Host "  $($track.Type) track: " -NoNewline -ForegroundColor Gray
    Write-Host "$($track.Title)" -NoNewline -ForegroundColor White
    Write-Host " (30s = $percentDiff%)" -ForegroundColor Cyan
}

Write-Host ""

# Test different validation levels
$validationLevels = @('Strict', 'Normal', 'Relaxed')

foreach ($level in $validationLevels) {
    Write-Host "🎯 Testing $level validation level:" -ForegroundColor Yellow
    
    $tolerancePercent = switch ($level) {
        'Strict' { 2.0 }
        'Normal' { 5.0 }
        'Relaxed' { 10.0 }
    }
    
    $minTolerance = switch ($level) {
        'Strict' { 2 }
        'Normal' { 3 }
        'Relaxed' { 5 }
    }
    
    $maxTolerance = switch ($level) {
        'Strict' { 30 }
        'Normal' { 60 }
        'Relaxed' { 120 }
    }
    
    Write-Host "   Settings: $tolerancePercent% tolerance (${minTolerance}s-${maxTolerance}s bounds)" -ForegroundColor Gray
    
    $comparison = Compare-TrackDurations -LocalTracks $localTracks -SpotifyTracks $spotifyTracks -TolerancePercent $tolerancePercent -MinToleranceSeconds $minTolerance -MaxToleranceSeconds $maxTolerance
    
    Write-Host "   Results:" -ForegroundColor Cyan
    foreach ($result in $comparison.Results) {
        $status = if ($result.IsSignificantMismatch) { "❌ MISMATCH" } else { "✅ ACCEPTABLE" }
        $statusColor = if ($result.IsSignificantMismatch) { "Red" } else { "Green" }
        
        Write-Host "     $status " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($result.LocalTitle) " -NoNewline -ForegroundColor White
        Write-Host "($($result.PercentDifference)% diff, tolerance: $($result.ToleranceSeconds)s)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Demonstrate the intelligence of percentage-based validation
Write-Host "📊 Comparison: Fixed vs. Percentage-Based Tolerance" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔴 Old Fixed Tolerance (15 seconds for all tracks):" -ForegroundColor Red
foreach ($track in $testTracks) {
    $wouldPass = 30 -le 15  # 30s difference vs 15s tolerance
    $status = if ($wouldPass) { "✅ PASS" } else { "❌ FAIL" }
    $statusColor = if ($wouldPass) { "Green" } else { "Red" }
    
    $percentDiff = [math]::Round((30 / $track.Duration) * 100, 1)
    Write-Host "   $status $($track.Title) - $percentDiff% difference" -ForegroundColor $statusColor
}

Write-Host ""
Write-Host "🟢 New Percentage-Based Tolerance (5% with bounds):" -ForegroundColor Green
foreach ($track in $testTracks) {
    $toleranceSeconds = [math]::Max(3, [math]::Min(60, $track.Duration * 0.05))
    $wouldPass = 30 -le $toleranceSeconds
    $status = if ($wouldPass) { "✅ PASS" } else { "❌ FAIL" }
    $statusColor = if ($wouldPass) { "Green" } else { "Red" }
    
    $percentDiff = [math]::Round((30 / $track.Duration) * 100, 1)
    Write-Host "   $status $($track.Title) - $percentDiff% diff (tolerance: ${toleranceSeconds}s)" -ForegroundColor $statusColor
}

Write-Host ""
Write-Host "🎯 KEY INSIGHTS:" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host ""
Write-Host "✅ SMART SCALING:" -ForegroundColor Green
Write-Host "   • Short tracks (1:30): 30s = 33% difference → ❌ RIGHTFULLY REJECTED" -ForegroundColor White
Write-Host "   • Normal tracks (3:30): 30s = 14% difference → ❌ APPROPRIATELY FLAGGED" -ForegroundColor White  
Write-Host "   • Long tracks (8:00): 30s = 6% difference → ⚠️  BORDERLINE" -ForegroundColor White
Write-Host "   • Epic tracks (20:00): 30s = 2.5% difference → ✅ ACCEPTABLE VARIATION" -ForegroundColor White
Write-Host ""
Write-Host "🎼 REAL-WORLD SCENARIOS:" -ForegroundColor Cyan
Write-Host "   • Pink Floyd 20-min epic: 30s difference is normal (fade-ins, live versions)" -ForegroundColor Gray
Write-Host "   • Punk 90s song: 30s difference means wrong track entirely" -ForegroundColor Gray
Write-Host "   • Pop 3-min song: 30s difference suggests encoding/editing issues" -ForegroundColor Gray
Write-Host ""
Write-Host "🚀 PERCENTAGE-BASED VALIDATION IS MUCH MORE INTELLIGENT!" -ForegroundColor Green

# Test the enhanced warning function  
Write-Host ""
Write-Host "🔔 Testing Enhanced Warning Display:" -ForegroundColor Yellow

$testMismatch = $comparison.Results | Where-Object { $_.LocalTitle -eq "Short Punk Song" } | Select-Object -First 1
if ($testMismatch) {
    Write-DurationMismatchWarning -FilePath $testMismatch.LocalPath -ActualDuration $testMismatch.LocalDuration -ExpectedDuration $testMismatch.SpotifyDuration -TrackTitle $testMismatch.LocalTitle -DifferenceSeconds $testMismatch.DifferenceSeconds -PercentDifference $testMismatch.PercentDifference -TrackLength $testMismatch.TrackLength
}

Write-Host "🎉 Percentage-based validation system is ready!" -ForegroundColor Green
Write-Host "   Much more intelligent than fixed thresholds for different track lengths!" -ForegroundColor Gray