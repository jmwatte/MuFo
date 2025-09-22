# Quick test to check the improved messaging logic
Write-Host "=== Testing Artist Rename Detection Logic ===" -ForegroundColor Cyan

# Test the condition manually
$localArtist = "abba"
$selectedArtistName = "ABBA"

Write-Host "Local artist: '$localArtist'" -ForegroundColor Gray
Write-Host "Selected artist: '$selectedArtistName'" -ForegroundColor Gray
Write-Host "Are they different? $($localArtist -ne $selectedArtistName)" -ForegroundColor $(if ($localArtist -ne $selectedArtistName) { 'Green' } else { 'Red' })

# Test case sensitivity
Write-Host "Case-sensitive comparison: '$localArtist' -ne '$selectedArtistName' = $($localArtist -ne $selectedArtistName)" -ForegroundColor White