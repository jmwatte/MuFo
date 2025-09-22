# Test Spotify helper with debug info
Write-Host "Detailed debugging of Spotify helper..." -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

Write-Host "`nTesting different mock structures:" -ForegroundColor Yellow

# Test 1: Albums.Items structure
$mockResult1 = @{
    Albums = @{
        Items = @(
            @{ Name = 'Test Album 1' },
            @{ Name = 'Test Album 2' }
        )
    }
}
Write-Host "Test 1 - Albums.Items structure:" -ForegroundColor White
$result1 = Get-AlbumItemsFromSearchResult -Result $mockResult1
Write-Host "Result count: $($result1.Count)" -ForegroundColor White

# Test 2: Direct Items structure
$mockResult2 = @{
    Items = @(
        @{ Name = 'Test Album 1' },
        @{ Name = 'Test Album 2' }
    )
}
Write-Host "`nTest 2 - Direct Items structure:" -ForegroundColor White
$result2 = Get-AlbumItemsFromSearchResult -Result $mockResult2
Write-Host "Result count: $($result2.Count)" -ForegroundColor White

# Test 3: Array input
$mockResult3 = @(
    @{
        Albums = @{
            Items = @(
                @{ Name = 'Test Album 1' }
            )
        }
    },
    @{
        Items = @(
            @{ Name = 'Test Album 2' }
        )
    }
)
Write-Host "`nTest 3 - Array input:" -ForegroundColor White
$result3 = Get-AlbumItemsFromSearchResult -Result $mockResult3
Write-Host "Result count: $($result3.Count)" -ForegroundColor White