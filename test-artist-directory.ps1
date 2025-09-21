# Test MuFo with correct usage - run on parent artist directory, not individual albums

Write-Host "=== Testing MuFo on Artist Directory ===" -ForegroundColor Cyan

# Run on the artist directory (correct usage)
Write-Host "Running MuFo on: E:\_CorrectedMusic\Arvo Part" -ForegroundColor Yellow

# Get just a few albums with verbose to see the matching process
$result = Invoke-MuFo -Path "E:\_CorrectedMusic\Arvo Part" -WhatIf -Verbose -ConfidenceThreshold 0.6 2>&1

# Filter for album search and scoring information
Write-Host "`n=== Album Search Queries ===" -ForegroundColor Green
$result | Where-Object { $_ -match "Search-Item Album query" } | ForEach-Object {
    Write-Host $_ -ForegroundColor White
}

Write-Host "`n=== Scoring and Matches ===" -ForegroundColor Blue
$result | Where-Object { $_ -match "Score|compare|best|match|similarity" } | ForEach-Object {
    Write-Host $_ -ForegroundColor White
}

Write-Host "`n=== Final Results ===" -ForegroundColor Magenta
$result | Where-Object { $_ -like "*LocalAlbum*" -or $_ -like "*SpotifyAlbum*" -or $_ -like "*Decision*" } | ForEach-Object {
    Write-Host $_ -ForegroundColor White
}