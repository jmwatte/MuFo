# Test the fixed Spotify helper function
Write-Host "Testing fixed Spotify helper function..." -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

# Test with hashtable (our test case)
$mockResult1 = @{
    Albums = @{
        Items = @(
            @{ Name = 'Test Album 1' },
            @{ Name = 'Test Album 2' }
        )
    }
}

Write-Host "Test 1 - Hashtable Albums.Items structure:" -ForegroundColor Yellow
$result1 = Get-AlbumItemsFromSearchResult -Result $mockResult1
Write-Host "Result count: $($result1.Count)" -ForegroundColor White
Write-Host "Success: $($result1.Count -eq 2)" -ForegroundColor $(if ($result1.Count -eq 2) { 'Green' } else { 'Red' })

# Test with PSCustomObject
$mockResult2 = [PSCustomObject]@{
    Albums = [PSCustomObject]@{
        Items = @(
            [PSCustomObject]@{ Name = 'Test Album 1' },
            [PSCustomObject]@{ Name = 'Test Album 2' }
        )
    }
}

Write-Host "`nTest 2 - PSCustomObject Albums.Items structure:" -ForegroundColor Yellow
$result2 = Get-AlbumItemsFromSearchResult -Result $mockResult2
Write-Host "Result count: $($result2.Count)" -ForegroundColor White
Write-Host "Success: $($result2.Count -eq 2)" -ForegroundColor $(if ($result2.Count -eq 2) { 'Green' } else { 'Red' })

# Test with direct Items
$mockResult3 = @{
    Items = @(
        @{ Name = 'Test Album 1' },
        @{ Name = 'Test Album 2' }
    )
}

Write-Host "`nTest 3 - Direct Items structure:" -ForegroundColor Yellow
$result3 = Get-AlbumItemsFromSearchResult -Result $mockResult3
Write-Host "Result count: $($result3.Count)" -ForegroundColor White
Write-Host "Success: $($result3.Count -eq 2)" -ForegroundColor $(if ($result3.Count -eq 2) { 'Green' } else { 'Red' })