# Test a single album to see detailed verbose output

Write-Host "=== Testing Single Album: Fratres ===" -ForegroundColor Cyan

# Run just on the Fratres album folder
$result = Invoke-MuFo -Path "E:\_CorrectedMusic\Arvo Part\1995 - Fratres" -WhatIf -Verbose -ConfidenceThreshold 0.6 2>&1

# Show full output
$result | ForEach-Object { 
    if ($_ -match "Search-Item Album query|Score|Album compare|best|match") {
        Write-Host $_ -ForegroundColor Yellow
    } else {
        Write-Host $_ -ForegroundColor White
    }
}