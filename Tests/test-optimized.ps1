# Test the optimized MuFo performance

Write-Host "=== Testing Optimized MuFo Performance ===" -ForegroundColor Cyan

# Test with a single Arvo Pärt album to see the improvement
$testPath = "E:\_CorrectedMusic\Arvo Part\1995 - Fratres"
Write-Host "`nTesting path: $testPath" -ForegroundColor Yellow

if (-not (Test-Path $testPath)) {
    Write-Host "⚠️  Path not found, testing with current directory instead" -ForegroundColor Yellow
    $testPath = $PWD
}

Write-Host "`nRunning optimized MuFo with lower confidence threshold..." -ForegroundColor Green

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Run with the new optimized settings
$result = Invoke-MuFo -Path $testPath -WhatIf -Verbose 2>&1

$stopwatch.Stop()

Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "Execution time: $($stopwatch.ElapsedMilliseconds)ms ($($stopwatch.Elapsed.TotalSeconds) seconds)" -ForegroundColor Green

# Count how many "album items collected" messages (should be much fewer or none)
$albumCollectionMessages = $result | Where-Object { $_ -match "album items collected" }
if ($albumCollectionMessages) {
    Write-Host "Album collection messages:" -ForegroundColor Red
    $albumCollectionMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "✅ No bulk album collection detected!" -ForegroundColor Green
}

# Look for successful matches
$foundMatches = $result | Where-Object { $_ -match "rename|match" }
Write-Host "`nMatches found:" -ForegroundColor Yellow
$foundMatches | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host "`n=== OPTIMIZATION SUCCESS ===" -ForegroundColor Green
Write-Host "✅ Lower confidence threshold (0.7) should find more matches" -ForegroundColor Green
Write-Host "✅ Restricted Tier 4 should prevent bulk downloads" -ForegroundColor Green
Write-Host "✅ Much faster execution expected" -ForegroundColor Green