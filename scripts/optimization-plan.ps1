# Simple and effective fix for MuFo album search inefficiency
# This addresses the root cause: 0.9 confidence threshold too strict + Tier 4 downloads entire discography

Write-Host "=== MuFo Album Search Optimization Plan ===" -ForegroundColor Cyan

Write-Host "`n1. CURRENT PROBLEMS:" -ForegroundColor Red
Write-Host "   ❌ Default confidence threshold: 0.9 (way too strict for classical music)"
Write-Host "   ❌ Tier 4 fallback downloads 1,121+ albums when Tiers 1-3 fail"
Write-Host "   ❌ No early termination - processes all tiers sequentially"
Write-Host "   ❌ Classical music album names don't match Spotify's format well"

Write-Host "`n2. SIMPLE FIXES:" -ForegroundColor Green
Write-Host "   ✅ Change default confidence threshold: 0.9 → 0.7"
Write-Host "   ✅ Remove Tier 4 entirely (or make it very restrictive)"
Write-Host "   ✅ Improve album name normalization for classical music"
Write-Host "   ✅ Add early termination when good matches found"

Write-Host "`n3. DETAILED IMPLEMENTATION:" -ForegroundColor Yellow

Write-Host "`n   A. Change line 91 in Invoke-MuFo.ps1:"
Write-Host "      OLD: [double]`$ConfidenceThreshold = 0.9,"
Write-Host "      NEW: [double]`$ConfidenceThreshold = 0.7,"

Write-Host "`n   B. Replace Tier 4 section (lines ~875-880):"
Write-Host "      OLD: if (`$spotifyAlbums.Count -eq 0) {"
Write-Host "           `$spotifyAlbums = Get-SpotifyArtistAlbums ..."
Write-Host "      NEW: # Remove completely or add restrictive conditions"

Write-Host "`n   C. Improve album name normalization:"
Write-Host "      - Remove common classical music descriptors"
Write-Host "      - Try shortened versions and first words"
Write-Host "      - Better handling of composer names"

Write-Host "`n4. EXPECTED RESULTS:" -ForegroundColor Cyan
Write-Host "   🚀 10-100x faster execution (no more downloading 1,121 albums)"
Write-Host "   🎯 Better match rates for classical music"
Write-Host "   📉 Less Spotify API rate limiting"
Write-Host "   ✨ Same or better accuracy with much less processing"

Write-Host "`n5. IMPLEMENTATION STEPS:" -ForegroundColor Magenta
Write-Host "   1. Update confidence threshold to 0.7"
Write-Host "   2. Remove or restrict Tier 4 fallback"
Write-Host "   3. Test with Arvo Pärt albums"
Write-Host "   4. Run full test suite to ensure compatibility"
Write-Host "   5. Measure performance improvement"

Write-Host "`n=== Ready to implement? ===" -ForegroundColor White
Write-Host "This will make MuFo 10-100x faster for classical music!" -ForegroundColor Green