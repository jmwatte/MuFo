# Simple test to load and verify functions are available
Write-Host "Testing module loading..." -ForegroundColor Cyan

# Load the private functions directly
Write-Host "Loading private functions..." -ForegroundColor Yellow
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    Write-Host "Loading $_" -ForegroundColor Gray
    . $_.FullName
}

# Test if functions are now available
Write-Host "`nTesting function availability:" -ForegroundColor Yellow

if (Get-Command Get-EffectiveExclusions -ErrorAction SilentlyContinue) {
    Write-Host "✓ Get-EffectiveExclusions is available" -ForegroundColor Green
} else {
    Write-Host "✗ Get-EffectiveExclusions not found" -ForegroundColor Red
}

if (Get-Command Write-RenameOperation -ErrorAction SilentlyContinue) {
    Write-Host "✓ Write-RenameOperation is available" -ForegroundColor Green
} else {
    Write-Host "✗ Write-RenameOperation not found" -ForegroundColor Red
}

if (Get-Command Get-AlbumItemsFromSearchResult -ErrorAction SilentlyContinue) {
    Write-Host "✓ Get-AlbumItemsFromSearchResult is available" -ForegroundColor Green
} else {
    Write-Host "✗ Get-AlbumItemsFromSearchResult not found" -ForegroundColor Red
}

Write-Host "`nDone!" -ForegroundColor Cyan