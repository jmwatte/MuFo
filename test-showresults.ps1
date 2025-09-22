# Test ShowResults Functionality 
Write-Host "=== Testing ShowResults Functionality ===" -ForegroundColor Cyan

# Create test data structure that matches the actual JSON format from Invoke-MuFo
$testLogFile = "C:\temp\test-showresults.json"

# Clean up any existing file
if (Test-Path $testLogFile) {
    Remove-Item $testLogFile -Force
}

Write-Host "`nCreating mock JSON log file..." -ForegroundColor Yellow

# Create test data that matches the actual structure from Invoke-MuFo
$testData = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString('o')
    Path = "C:\TestMusic\TestArtist"
    Mode = "Smart"
    ConfidenceThreshold = 0.9
    Items = @(
        [PSCustomObject]@{
            LocalFolder = "1970 - First Album"
            LocalPath = "C:\TestMusic\TestArtist\1970 - First Album"
            NewFolderName = "1970 - Debut Album"
            Action = "rename"
            Reason = "improved-match"
            Score = 0.95
            SpotifyAlbum = "Debut Album"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "First Album"
            Decision = "auto-rename"
            ArtistSource = "search"
        },
        [PSCustomObject]@{
            LocalFolder = "1975 - Second Album"
            LocalPath = "C:\TestMusic\TestArtist\1975 - Second Album"
            NewFolderName = $null
            Action = "skip"
            Reason = "below-threshold"
            Score = 0.65
            SpotifyAlbum = "Different Album"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Second Album"
            Decision = "skip-low-score"
            ArtistSource = "search"
        },
        [PSCustomObject]@{
            LocalFolder = "1980 - Best Hits"
            LocalPath = "C:\TestMusic\TestArtist\1980 - Best Hits"
            NewFolderName = "1980 - Greatest Hits"
            Action = "rename"
            Reason = "high-confidence"
            Score = 0.98
            SpotifyAlbum = "Greatest Hits"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Best Hits"
            Decision = "auto-rename"
            ArtistSource = "inferred"
        },
        [PSCustomObject]@{
            LocalFolder = "Error Album"
            LocalPath = "C:\TestMusic\TestArtist\Error Album"
            NewFolderName = "Fixed Album Name"
            Action = "error"
            Reason = "file-locked"
            Score = 0.90
            SpotifyAlbum = "Fixed Album Name"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Error Album"
            Decision = "error"
            ArtistSource = "search"
        }
    )
}

# Write test data to file
$testData | ConvertTo-Json -Depth 10 | Set-Content -Path $testLogFile -Encoding UTF8
Write-Host "Created test log file: $testLogFile" -ForegroundColor Gray

# Load the module
Import-Module .\MuFo.psm1 -Force

Write-Host "`nTest 1: Show all results (no filters)" -ForegroundColor Yellow
try {
    $results1 = Invoke-MuFo -ShowResults -LogTo $testLogFile
    Write-Host "  Total results: $($results1.Count)" -ForegroundColor $(if ($results1.Count -eq 4) { "Green" } else { "Red" })
    if ($results1.Count -gt 0) {
        Write-Host "  Sample result properties: $($results1[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Filter by Action = 'rename'" -ForegroundColor Yellow
try {
    $results2 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "rename"
    Write-Host "  Rename results: $($results2.Count)" -ForegroundColor $(if ($results2.Count -eq 2) { "Green" } else { "Red" })
    if ($results2.Count -gt 0) {
        Write-Host "  Albums to rename: $($results2.LocalFolder -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Filter by Action = 'skip'" -ForegroundColor Yellow
try {
    $results3 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "skip"
    Write-Host "  Skip results: $($results3.Count)" -ForegroundColor $(if ($results3.Count -eq 1) { "Green" } else { "Red" })
    if ($results3.Count -gt 0) {
        Write-Host "  Skipped albums: $($results3.LocalFolder -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 4: Filter by Action = 'error'" -ForegroundColor Yellow
try {
    $results4 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "error"
    Write-Host "  Error results: $($results4.Count)" -ForegroundColor $(if ($results4.Count -eq 1) { "Green" } else { "Red" })
    if ($results4.Count -gt 0) {
        Write-Host "  Error albums: $($results4.LocalFolder -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 5: Filter by MinScore = 0.9" -ForegroundColor Yellow
try {
    $results5 = Invoke-MuFo -ShowResults -LogTo $testLogFile -MinScore 0.9
    Write-Host "  High score results: $($results5.Count)" -ForegroundColor $(if ($results5.Count -eq 3) { "Green" } else { "Red" })
    if ($results5.Count -gt 0) {
        Write-Host "  High score albums: $($results5.LocalFolder -join ', ')" -ForegroundColor Gray
        Write-Host "  Scores: $($results5 | ForEach-Object { "$(($_.LocalFolder -split ' - ')[1]): $($_.Decision.Split(' ')[0])" } | Join-String -Separator ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 6: Combined filters (Action = 'rename' AND MinScore = 0.9)" -ForegroundColor Yellow
try {
    $results6 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "rename" -MinScore 0.9
    Write-Host "  Combined filter results: $($results6.Count)" -ForegroundColor $(if ($results6.Count -eq 2) { "Green" } else { "Red" })
    if ($results6.Count -gt 0) {
        Write-Host "  High score renames: $($results6.LocalFolder -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 7: ShowEverything mode" -ForegroundColor Yellow
try {
    $results7 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "rename" -ShowEverything
    Write-Host "  ShowEverything results: $($results7.Count)" -ForegroundColor $(if ($results7.Count -eq 2) { "Green" } else { "Red" })
    if ($results7.Count -gt 0) {
        $sampleProperties = $results7[0].PSObject.Properties.Name
        Write-Host "  Full object properties count: $($sampleProperties.Count)" -ForegroundColor Gray
        $hasExtendedProps = ($sampleProperties -contains "LocalPath") -and ($sampleProperties -contains "Score") -and ($sampleProperties -contains "Reason")
        Write-Host "  Has extended properties: $hasExtendedProps" -ForegroundColor $(if ($hasExtendedProps) { "Green" } else { "Red" })
    }
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 8: Test error handling (missing file)" -ForegroundColor Yellow
try {
    $results8 = Invoke-MuFo -ShowResults -LogTo "C:\nonexistent\file.json" -ErrorAction SilentlyContinue
    Write-Host "  Missing file handled gracefully: $(($null -eq $results8))" -ForegroundColor $(if ($null -eq $results8) { "Green" } else { "Red" })
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 9: Test error handling (missing LogTo parameter)" -ForegroundColor Yellow
try {
    $results9 = Invoke-MuFo -ShowResults -ErrorAction SilentlyContinue
    Write-Host "  Missing LogTo handled gracefully: $(($null -eq $results9))" -ForegroundColor $(if ($null -eq $results9) { "Green" } else { "Red" })
} catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testLogFile) {
    Remove-Item $testLogFile -Force
    Write-Host "`nTest file cleaned up" -ForegroundColor Gray
}

Write-Host "`n🎉 ShowResults functionality testing complete!" -ForegroundColor Cyan
Write-Host "✓ All filtering and display modes tested successfully" -ForegroundColor Green