# Test script to debug Qobuz artist extraction
# Usage: .\test-qobuz-artist-debug.ps1 -ArtistFolder "C:\Music\Artist\Album" -Verbose
# Or:    .\test-qobuz-artist-debug.ps1 -ArtistFolder "C:\Music\Artist" -Verbose

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtistFolder
)

Write-Host "`n=== Qobuz Artist Extraction Debug Test ===" -ForegroundColor Cyan
Write-Host "Artist Folder: $ArtistFolder`n" -ForegroundColor Gray

# Validate folder exists
if (-not (Test-Path $ArtistFolder)) {
    Write-Host "✗ Folder not found: $ArtistFolder" -ForegroundColor Red
    exit 1
}

try {
    # Import the module
    Import-Module .\MuFo.psd1 -Force -ErrorAction Stop
    
    Write-Host "Starting Invoke-MuFoManual with Qobuz provider..." -ForegroundColor Yellow
    Write-Host "(Watch for === TRACK XX DEBUG === output showing artist extraction)`n" -ForegroundColor Gray
    Write-Host "The debug output will show for EACH TRACK:" -ForegroundColor Cyan
    Write-Host "  - Raw performerInfo text" -ForegroundColor Gray
    Write-Host "  - Parsed results (Performers, Composers, etc.)" -ForegroundColor Gray
    Write-Host "  - Built artists array" -ForegroundColor Gray
    Write-Host "  - GTM fallback attempts`n" -ForegroundColor Gray
    
    # Run MuFo in WhatIf mode to see the track extraction without making changes
    # Use -goA -goB -goC to auto-select first matches and see the track output
    Invoke-MuFoManual -Provider Qobuz -Path $ArtistFolder -WhatIf -goA -goB -goC -Verbose
    
    Write-Host "`n`n=== ANALYSIS ===" -ForegroundColor Cyan
    Write-Host "Review the === TRACK XX DEBUG === sections above to see:" -ForegroundColor Yellow
    Write-Host "  1. What 'Raw performerInfo' shows (is it empty or populated?)" -ForegroundColor Gray
    Write-Host "  2. What 'Parsed results' shows (Performers, Composers, Conductor)" -ForegroundColor Gray
    Write-Host "  3. How many artists were built into the array" -ForegroundColor Gray
    Write-Host "  4. Whether GTM fallback was attempted (if artists=0)" -ForegroundColor Gray
    
    Write-Host "`nCommon issues:" -ForegroundColor Yellow
    Write-Host "  • If performerInfo is empty: HTML selector may need updating" -ForegroundColor Gray
    Write-Host "  • If parsed but no Performers: ParsePerformer logic may need adjustment" -ForegroundColor Gray
    Write-Host "  • If GTM fallback fails: Check data-gtm structure on Qobuz" -ForegroundColor Gray
    Write-Host "  • If all empty: Qobuz HTML structure may have changed`n" -ForegroundColor Gray
    
} catch {
    Write-Host "`n✗ ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
