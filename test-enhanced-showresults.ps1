# Test Enhanced ShowResults with Summary Statistics
Write-Host "=== Testing Enhanced ShowResults with Summary ===" -ForegroundColor Cyan

# Create test data
$testLogFile = "C:\temp\test-enhanced-showresults.json"

if (Test-Path $testLogFile) {
    Remove-Item $testLogFile -Force
}

# Create more comprehensive test data
$testData = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString('o')
    Path = "C:\Music\TestArtist"
    Mode = "Smart"
    ConfidenceThreshold = 0.85
    Items = @(
        [PSCustomObject]@{
            LocalFolder = "1970 - First Album"
            LocalPath = "C:\Music\TestArtist\1970 - First Album"
            NewFolderName = "1970 - Debut Album"
            Action = "rename"
            Reason = "high-confidence"
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
            LocalPath = "C:\Music\TestArtist\1975 - Second Album"
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
            LocalFolder = "1980 - Greatest Hits"
            LocalPath = "C:\Music\TestArtist\1980 - Greatest Hits"
            NewFolderName = "1980 - Best Of"
            Action = "rename"
            Reason = "exact-match"
            Score = 0.98
            SpotifyAlbum = "Best Of"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Greatest Hits"
            Decision = "auto-rename"
            ArtistSource = "inferred"
        },
        [PSCustomObject]@{
            LocalFolder = "1985 - Another Album"
            LocalPath = "C:\Music\TestArtist\1985 - Another Album"
            NewFolderName = $null
            Action = "skip"
            Reason = "user-declined"
            Score = 0.88
            SpotifyAlbum = "Another Album"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Another Album"
            Decision = "user-skip"
            ArtistSource = "search"
        },
        [PSCustomObject]@{
            LocalFolder = "Error Album"
            LocalPath = "C:\Music\TestArtist\Error Album"
            NewFolderName = "Fixed Album"
            Action = "error"
            Reason = "file-locked"
            Score = 0.90
            SpotifyAlbum = "Fixed Album"
            LocalArtist = "TestArtist"
            Artist = "Test Artist"
            LocalAlbum = "Error Album"
            Decision = "error"
            ArtistSource = "search"
        }
    )
}

$testData | ConvertTo-Json -Depth 10 | Set-Content -Path $testLogFile -Encoding UTF8

Import-Module .\MuFo.psm1 -Force

Write-Host "`nTest 1: Enhanced ShowResults with summary statistics" -ForegroundColor Yellow
$results1 = Invoke-MuFo -ShowResults -LogTo $testLogFile

Write-Host "`nTest 2: Enhanced ShowResults with Action filter" -ForegroundColor Yellow
$results2 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "rename"

Write-Host "`nTest 3: Enhanced ShowResults with MinScore filter" -ForegroundColor Yellow
$results3 = Invoke-MuFo -ShowResults -LogTo $testLogFile -MinScore 0.9

Write-Host "`nTest 4: Enhanced ShowResults with combined filters" -ForegroundColor Yellow
$results4 = Invoke-MuFo -ShowResults -LogTo $testLogFile -Action "skip" -MinScore 0.8

# Cleanup
if (Test-Path $testLogFile) {
    Remove-Item $testLogFile -Force
}

Write-Host "`n🎉 Enhanced ShowResults testing complete!" -ForegroundColor Cyan