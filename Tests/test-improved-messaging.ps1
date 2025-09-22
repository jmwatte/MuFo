# Test improved messaging for artist-only rename scenario
Write-Host "=== Testing Improved Artist-Only Rename Messaging ===" -ForegroundColor Cyan

# Create a test case similar to the ABBA scenario
$testPath = "C:\temp\TestMusic\abba"
$album1Path = "$testPath\1976 - Arrival"
$album2Path = "$testPath\1981 - The Visitors"

try {
    # Create test structure
    if (-not (Test-Path $testPath)) {
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        New-Item -ItemType Directory -Path $album1Path -Force | Out-Null  
        New-Item -ItemType Directory -Path $album2Path -Force | Out-Null
        Write-Host "Created test structure for lowercase 'abba'" -ForegroundColor Gray
    }
    
    Write-Host "`nTesting with lowercase 'abba' (should suggest ABBA)..." -ForegroundColor Yellow
    Import-Module .\MuFo.psm1 -Force -ErrorAction Stop
    
    $result = Invoke-MuFo -Path $testPath -WhatIf -ErrorAction Stop
    
    Write-Host "`nResult count: $($result.Count)" -ForegroundColor Gray
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}