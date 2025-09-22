# Test private functions directly  
Write-Host "Testing private functions directly..." -ForegroundColor Cyan

# Load private functions manually
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

Write-Host "`n1. Testing Spotify Helper with manual loading:" -ForegroundColor Yellow
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
    Write-Host "Result: $($result | ConvertTo-Json -Depth 2)" -ForegroundColor White
    Write-Host "Result count: $($result.Count)" -ForegroundColor White
    Write-Host "Test passes: $($result.Count -eq 2)" -ForegroundColor White
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. Testing Artist Selection Functions with manual loading:" -ForegroundColor Yellow
$funcs = @('Get-ArtistSelection', 'Get-ArtistFromInference', 'Get-ArtistRenameProposal')
foreach ($f in $funcs) {
    $cmd = Get-Command $f -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✓ $f found" -ForegroundColor Green
    } else {
        Write-Host "✗ $f NOT found" -ForegroundColor Red
    }
}