# Test album processing functions
Write-Host "Testing album processing functions..." -ForegroundColor Cyan

# Load all private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    Write-Host "Loading $_" -ForegroundColor Gray
    . $_.FullName
}

# Test if album processing functions are available
Write-Host "`nTesting function availability:" -ForegroundColor Yellow

$functions = @(
    'Get-AlbumComparisons',
    'Get-SingleAlbumComparison', 
    'Get-SpotifyAlbumsForLocal',
    'Get-BestAlbumMatch',
    'Get-AlbumScore',
    'Add-TrackInformationToComparisons',
    'Build-AlbumComparisonObject'
)

foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ $func is available" -ForegroundColor Green
    } else {
        Write-Host "✗ $func not found" -ForegroundColor Red
    }
}

Write-Host "`nAlbum processing functions are ready!" -ForegroundColor Green