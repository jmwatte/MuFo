# Test the red "Expected" display and CreateMissingFilesLog functionality
Write-Host "Testing red Expected display and missing files log creation..." -ForegroundColor Cyan

# Load private functions
Write-Host "Loading private functions..." -ForegroundColor Yellow
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    Write-Host "Loading $($_.Name)" -ForegroundColor Gray
    . $_.FullName
}

# Test Set-AudioFileTags function availability
Write-Host "`nTesting Set-AudioFileTags function..." -ForegroundColor Yellow
if (Get-Command Set-AudioFileTags -ErrorAction SilentlyContinue) {
    Write-Host "✓ Set-AudioFileTags function is available" -ForegroundColor Green

    # Check if it has the CreateMissingFilesLog parameter
    $cmd = Get-Command Set-AudioFileTags
    if ($cmd.Parameters['CreateMissingFilesLog']) {
        Write-Host "✓ Set-AudioFileTags has CreateMissingFilesLog parameter" -ForegroundColor Green
    } else {
        Write-Host "✗ Set-AudioFileTags missing CreateMissingFilesLog parameter" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Set-AudioFileTags function not found" -ForegroundColor Red
}

# Test the red Expected display by creating a mock scenario
Write-Host "`nTesting red Expected display simulation..." -ForegroundColor Yellow

# Create a mock album object with completeness analysis
$mockAlbum = [PSCustomObject]@{
    LocalPath = "C:\Test\MockAlbum"
    LocalAlbum = "Mock Album"
    SpotifyAlbum = [PSCustomObject]@{
        tracks = [PSCustomObject]@{
            items = @(
                [PSCustomObject]@{ name = "Track 1"; track_number = 1 },
                [PSCustomObject]@{ name = "Track 2"; track_number = 2 },
                [PSCustomObject]@{ name = "Track 3"; track_number = 3 }
            )
        }
    }
}

# Add mock completeness analysis
$mockCompleteness = [PSCustomObject]@{
    Summary = [PSCustomObject]@{
        TracksFound = 2
        ExpectedTracks = 3
        MissingTracks = @("Track 3")
    }
    MissingTracks = @(
        [PSCustomObject]@{ TrackName = "Track 3"; TrackNumber = 3 }
    )
}

$mockAlbum | Add-Member -NotePropertyName CompletenessAnalysis -NotePropertyValue $mockCompleteness

# Test the display logic (simulate what happens in Set-AudioFileTags)
Write-Host "Simulating album analysis display:" -ForegroundColor Cyan
$analysis = $mockAlbum.CompletenessAnalysis
if ($analysis -and $analysis.Summary) {
    $found = $analysis.Summary.TracksFound
    $expected = $analysis.Summary.ExpectedTracks

    # This should show "Tracks Found: 2 / Expected: 3" with Expected in red
    Write-Host "Tracks Found: $found / " -NoNewline
    Write-Host "Expected: $expected" -ForegroundColor Red
}

# Test missing files log creation
Write-Host "`nTesting missing files log creation..." -ForegroundColor Yellow
$testLogPath = "test-missing-tracks-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

try {
    # Simulate log creation logic
    $logContent = @"
Missing Tracks Report
Generated: $(Get-Date)
Album: $($mockAlbum.LocalAlbum)
Path: $($mockAlbum.LocalPath)

Summary:
- Tracks Found: $($analysis.Summary.TracksFound)
- Expected Tracks: $($analysis.Summary.ExpectedTracks)
- Missing Tracks: $($analysis.Summary.MissingTracks.Count)

Missing Tracks:
$($analysis.MissingTracks | ForEach-Object { "  $($_.TrackNumber). $($_.TrackName)" } | Out-String)
"@

    $logContent | Set-Content -Path $testLogPath -Encoding UTF8
    Write-Host "✓ Created missing files log: $testLogPath" -ForegroundColor Green

    # Show log content
    Write-Host "`nLog content:" -ForegroundColor Cyan
    Get-Content $testLogPath | Write-Host -ForegroundColor Gray

    # Clean up
    Remove-Item $testLogPath -ErrorAction SilentlyContinue

} catch {
    Write-Host "✗ Failed to create missing files log: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Cyan