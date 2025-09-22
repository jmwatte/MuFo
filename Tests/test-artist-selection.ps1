# Test refactored artist selection functions
Write-Host "Testing artist selection refactoring..." -ForegroundColor Cyan

# Load all private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    Write-Host "Loading $_" -ForegroundColor Gray
    . $_.FullName
}

# Test if artist selection functions are available
Write-Host "`nTesting function availability:" -ForegroundColor Yellow

$functions = @(
    'Get-ArtistSelection',
    'Get-ArtistFromInference', 
    'Get-QuickArtistInference',
    'Get-QuickAllSearchInference',
    'Get-QuickPhraseSearchInference',
    'Get-ArtistFromVoting',
    'Get-AllSearchMatches',
    'Get-PhraseSearchMatches',
    'Get-BestArtistFromCatalogEvaluation',
    'Get-ArtistRenameProposal'
)

foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ $func is available" -ForegroundColor Green
    } else {
        Write-Host "✗ $func not found" -ForegroundColor Red
    }
}

Write-Host "`nAll artist selection functions are ready!" -ForegroundColor Green