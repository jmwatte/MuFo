# Debug why Get-SpotifyAlbumMatches is not returning results even though Search-Item works

Write-Host "=== Debugging Get-SpotifyAlbumMatches ===" -ForegroundColor Cyan

# Test the exact same query that MuFo uses
$query = 'artist:"Arvo Pärt" album:"Fratres" year:1995'
$albumName = "Fratres"

Write-Host "Testing query: $query" -ForegroundColor Yellow
Write-Host "Album name for scoring: $albumName" -ForegroundColor Yellow

# Step 1: Test raw Search-Item
Write-Host "`n1. Raw Search-Item:" -ForegroundColor Green
try {
    $rawResult = Search-Item -Type Album -Query $query -ErrorAction Stop
    Write-Host "   Success! Result type: $($rawResult.GetType().Name)" -ForegroundColor White
    if ($rawResult.Albums -and $rawResult.Albums.Items) {
        Write-Host "   Found $($rawResult.Albums.Items.Count) albums" -ForegroundColor White
        $rawResult.Albums.Items | Select-Object -First 3 | ForEach-Object {
            Write-Host "   - $($_.Name)" -ForegroundColor White
        }
    } else {
        Write-Host "   No Albums.Items found" -ForegroundColor Red
    }
} catch {
    Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 2: Test Get-SpotifyAlbumMatches
Write-Host "`n2. Get-SpotifyAlbumMatches:" -ForegroundColor Green
try {
    $matchResult = Get-SpotifyAlbumMatches -Query $query -AlbumName $albumName -Verbose
    Write-Host "   Result count: $($matchResult.Count)" -ForegroundColor White
    if ($matchResult.Count -gt 0) {
        $matchResult | ForEach-Object {
            Write-Host "   - $($_.AlbumName) (Score: $([math]::Round($_.Score, 2)))" -ForegroundColor White
        }
    } else {
        Write-Host "   No matches returned!" -ForegroundColor Red
    }
} catch {
    Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Test string similarity directly
Write-Host "`n3. String Similarity Test:" -ForegroundColor Blue
$testNames = @(
    "Arvo Pärt: Fratres",
    "Fratres", 
    "Pärt: Fratres",
    "Part: Fratres, Festina lente & Summa"
)

foreach ($testName in $testNames) {
    try {
        $score = Get-StringSimilarity -String1 $albumName -String2 $testName
        $passesThreshold = if ($score -ge 0.7) { "✅ PASS" } else { "❌ FAIL" }
        Write-Host "   '$albumName' vs '$testName' = $([math]::Round($score, 2)) $passesThreshold" -ForegroundColor White
    } catch {
        Write-Host "   String similarity failed for '$testName': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 4: Test with lower threshold
Write-Host "`n4. Testing with 0.5 threshold:" -ForegroundColor Magenta
try {
    $lowThresholdResult = Get-SpotifyAlbumMatches -Query $query -AlbumName $albumName -Top 10
    Write-Host "   Result count: $($lowThresholdResult.Count)" -ForegroundColor White
    $lowThresholdResult | ForEach-Object {
        $passesNew = if ($_.Score -ge 0.7) { "✅" } else { "❌" }
        Write-Host "   $passesNew $($_.AlbumName) (Score: $([math]::Round($_.Score, 2)))" -ForegroundColor White
    }
} catch {
    Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSIS ===" -ForegroundColor Cyan
Write-Host "The issue might be:" -ForegroundColor White
Write-Host "1. String similarity scoring too strict" -ForegroundColor Yellow
Write-Host "2. Album names on Spotify have extra text (artist prefix, etc.)" -ForegroundColor Yellow  
Write-Host "3. The 0.7 threshold still too high for these matches" -ForegroundColor Yellow
Write-Host "4. Need to strip artist names from album titles before scoring" -ForegroundColor Yellow