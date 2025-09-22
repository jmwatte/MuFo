# Debug the specific failing tests
Write-Host "Debugging failing tests..." -ForegroundColor Cyan

# Import module to make functions available
Import-Module './MuFo.psd1' -Force

Write-Host "`n1. Testing Spotify Helper Logic:" -ForegroundColor Yellow
$mockResult = @{
    Albums = @{
        Items = @(
            @{ Name = 'Test Album 1' },
            @{ Name = 'Test Album 2' }
        )
    }
}
try {
    $result = Get-AlbumItemsFromSearchResult -Result $mockResult
    Write-Host "Result count: $($result.Count)" -ForegroundColor White
    Write-Host "Expected count: 2" -ForegroundColor White
    Write-Host "Test passes: $($result.Count -eq 2)" -ForegroundColor White
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. Testing Artist Selection Functions:" -ForegroundColor Yellow
$funcs = @('Get-ArtistSelection', 'Get-ArtistFromInference', 'Get-ArtistRenameProposal')
foreach ($f in $funcs) {
    $cmd = Get-Command $f -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✓ $f found" -ForegroundColor Green
    } else {
        Write-Host "✗ $f NOT found" -ForegroundColor Red
    }
}

Write-Host "`nAll functions available:" -ForegroundColor Yellow
Get-Command -Module MuFo | Sort-Object Name | ForEach-Object { 
    Write-Host "  $($_.Name)" -ForegroundColor Gray 
}