# Test script to verify tag saving works correctly
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\..\MuFo.psd1" -Force

# Manually load private functions needed for test
. "$PSScriptRoot\..\Private\manual\Save-TagsForFile.ps1"
. "$PSScriptRoot\..\Private\Test-FileLocked.ps1"
. "$PSScriptRoot\..\Private\Wait-ForFileUnlock.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TAG SAVING TEST" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Test file
$testFile = "E:\Japan\1979 - Quiet Life\09 - All Tomorrow's Parties (1983 Remix).mp3"

Write-Host "Testing file: $testFile`n" -ForegroundColor Yellow

# Create test tags with multiple artists and genres
$testTags = @{
    Title = 'All Tomorrow''s Parties (Steve Nye Extended Remix)'
    Track = '09'
    Disc = '01'
    Performers = 'Japan; Lou Reed; Nico'  # Multiple artists separated by semicolon
    Genres = @('pop-rock', 'new wave', 'art rock')  # Array of genres
    Album = 'Quiet Life'
    AlbumArtist = 'Japan'
    Date = '1979'
    Composers = 'Lou Reed'
}

Write-Host "Test tags to save:" -ForegroundColor Cyan
$testTags.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $val = if ($_.Value -is [array]) { $_.Value -join ', ' } else { $_.Value }
    Write-Host "  $($_.Key): $val" -ForegroundColor White
}

Write-Host "`nBEFORE save - Current file tags:" -ForegroundColor Yellow
$before = Get-AudioFileTags $testFile
Write-Host "  Artists: $($before.Artists -join ', ')" -ForegroundColor White
Write-Host "  Genres: $($before.Genres -join ', ')" -ForegroundColor White
Write-Host "  Composer: $($before.Composer)" -ForegroundColor White

Write-Host "`nSaving tags..." -ForegroundColor Cyan
$result = Save-TagsForFile -FilePath $testFile -TagValues $testTags
Write-Host "Save result: Success=$($result.Success)" -ForegroundColor $(if ($result.Success) { 'Green' } else { 'Red' })

Write-Host "`nAFTER save - Updated file tags:" -ForegroundColor Yellow
$after = Get-AudioFileTags $testFile
Write-Host "  Artists: $($after.Artists -join ', ')" -ForegroundColor White
Write-Host "  Genres: $($after.Genres -join ', ')" -ForegroundColor White
Write-Host "  Composer: $($after.Composer)" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$success = $true

# Check artists (should have all 3)
if ($after.Artists.Count -ge 3) {
    Write-Host "✓ Multiple artists saved correctly ($($after.Artists.Count) artists)" -ForegroundColor Green
} else {
    Write-Host "✗ Artists not saved correctly (expected 3, got $($after.Artists.Count))" -ForegroundColor Red
    $success = $false
}

# Check genres (should have all 3)
if ($after.Genres.Count -ge 3) {
    Write-Host "✓ Multiple genres saved correctly ($($after.Genres.Count) genres)" -ForegroundColor Green
} else {
    Write-Host "✗ Genres not saved correctly (expected 3, got $($after.Genres.Count))" -ForegroundColor Red
    $success = $false
}

# Check composer
if ($after.Composer -eq 'Lou Reed') {
    Write-Host "✓ Composer saved correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Composer not saved correctly" -ForegroundColor Red
    $success = $false
}

Write-Host "`n========================================" -ForegroundColor Cyan
if ($success) {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan
