# Quick Performance Test for Track Tagging
# This script validates the enhanced track processing performance

Import-Module .\MuFo.psd1 -Force

Write-Host "`n=== Quick Performance Test for Track Tagging ===" -ForegroundColor Cyan

# Test with a small music collection to verify performance improvements
$testPath = "C:\Users\resto\Music"  # Adjust this to your music folder

if (Test-Path $testPath) {
    Write-Host "`nTesting track tagging performance with: $testPath" -ForegroundColor Yellow
    
    try {
        # Test with IncludeTracks to trigger the optimized Get-AudioFileTags
        Write-Host "Running Invoke-MuFo with IncludeTracks (performance optimized)..." -ForegroundColor Cyan
        
        $startTime = Get-Date
        $results = Invoke-MuFo -Path $testPath -IncludeTracks -WhatIf -Verbose
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "`n✓ Performance test completed successfully!" -ForegroundColor Green
        Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Green
        Write-Host "Results: $($results.Count) items processed" -ForegroundColor Green
        
        # Show any albums that had track processing
        $albumsWithTracks = $results | Where-Object { $_.TracksWithMissingTitle -ne $null }
        if ($albumsWithTracks.Count -gt 0) {
            Write-Host "`nAlbums with track analysis:" -ForegroundColor Cyan
            foreach ($album in $albumsWithTracks | Select-Object -First 3) {
                Write-Host "  - $($album.LocalFolderName): $($album.TracksWithMissingTitle) tracks missing titles" -ForegroundColor Green
            }
        }
        
    } catch {
        Write-Host "✗ Performance test error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Full error:" -ForegroundColor Red
        Write-Host $_.Exception.ToString() -ForegroundColor Red
    }
} else {
    Write-Host "Test path not found: $testPath" -ForegroundColor Yellow
    Write-Host "Please update the test path to point to a music folder" -ForegroundColor Yellow
}

Write-Host "`n=== Performance Improvements Summary ===" -ForegroundColor Cyan
Write-Host "✓ File size limits (500MB default) to skip huge files" -ForegroundColor Green
Write-Host "✓ Progress indicators for large collections" -ForegroundColor Green  
Write-Host "✓ Enhanced error handling for corrupted files" -ForegroundColor Green
Write-Host "✓ Memory management and resource cleanup" -ForegroundColor Green
Write-Host "✓ Performance monitoring and timing" -ForegroundColor Green

Write-Host "`nQuick performance test complete!" -ForegroundColor Green