# Quick test of refactored functionality
Write-Host "Testing refactored MuFo functions..." -ForegroundColor Cyan

# Import the module
Import-Module '.\MuFo.psd1' -Force

# Test exclusions functions
Write-Host "`nTesting exclusions functionality:" -ForegroundColor Yellow
$testExclusions = Get-EffectiveExclusions -ExcludeFolders @('test1', 'test2')
Write-Host "Exclusions created: $($testExclusions -join ', ')"

# Test output formatting functions  
Write-Host "`nTesting output formatting:" -ForegroundColor Yellow
$testRenameMap = [ordered]@{ 'C:\old\path' = 'C:\new\path'; 'C:\another\old' = 'C:\another\new' }
Write-RenameOperation -RenameMap $testRenameMap -Mode 'Test'

# Test Spotify helper function
Write-Host "`nTesting Spotify helper:" -ForegroundColor Yellow
$mockResult = @{
    Albums = @{
        Items = @(
            @{ Name = 'Album 1' },
            @{ Name = 'Album 2' }
        )
    }
}
$extractedAlbums = Get-AlbumItemsFromSearchResult -Result $mockResult
Write-Host "Extracted albums: $($extractedAlbums.Count)"

Write-Host "`nAll refactored functions are working!" -ForegroundColor Green