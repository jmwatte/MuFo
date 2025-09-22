# Check hashtable property access
Write-Host "Testing hashtable property access..." -ForegroundColor Cyan

$mockResult = @{
    Albums = @{
        Items = @(
            @{ Name = 'Test Album 1' },
            @{ Name = 'Test Album 2' }
        )
    }
}

Write-Host "Direct property access:" -ForegroundColor Yellow
Write-Host "mockResult.Albums: $($mockResult.Albums)" -ForegroundColor White
Write-Host "mockResult.Albums.Items: $($mockResult.Albums.Items)" -ForegroundColor White
Write-Host "mockResult.Albums.Items.Count: $($mockResult.Albums.Items.Count)" -ForegroundColor White

Write-Host "`nProperty checks:" -ForegroundColor Yellow
Write-Host "ContainsKey('Albums'): $($mockResult.ContainsKey('Albums'))" -ForegroundColor White
Write-Host "Albums property exists: $($null -ne $mockResult.Albums)" -ForegroundColor White
Write-Host "Albums.Items exists: $($null -ne $mockResult.Albums.Items)" -ForegroundColor White

# The issue is that the PSObject.Properties.Match won't work properly with hashtables
# Let's test a better approach
Write-Host "`nTesting PSCustomObject:" -ForegroundColor Yellow
$customResult = [PSCustomObject]@{
    Albums = [PSCustomObject]@{
        Items = @(
            [PSCustomObject]@{ Name = 'Test Album 1' },
            [PSCustomObject]@{ Name = 'Test Album 2' }
        )
    }
}

Write-Host "PSCustomObject properties: $($customResult.PSObject.Properties.Name -join ', ')" -ForegroundColor White
Write-Host "Albums.PSObject properties: $($customResult.Albums.PSObject.Properties.Name -join ', ')" -ForegroundColor White