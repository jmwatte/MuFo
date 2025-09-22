# Focused debug for the 10cc artist search issue
Write-Host "=== Focused 10cc Search Debug ===" -ForegroundColor Cyan

try {
    Import-Module .\MuFo.psm1 -Force -ErrorAction Stop
    
    Write-Host "`n1. Direct Spotify Artist Search..." -ForegroundColor Yellow
    $searchResult = Search-Item -Type Artist -Query "10cc" -ErrorAction Stop
    
    Write-Host "Raw search result type: $($searchResult.GetType().FullName)" -ForegroundColor Gray
    
    if ($searchResult.Artists -and $searchResult.Artists.Items) {
        $items = $searchResult.Artists.Items
        Write-Host "Found $($items.Count) raw artist items:" -ForegroundColor Gray
        
        foreach ($item in $items | Select-Object -First 10) {
            $name = if ($item.Name -is [array]) { ($item.Name -join ' ') } else { [string]$item.Name }
            $popularity = if ($item.Popularity) { $item.Popularity } else { "N/A" }
            Write-Host "  - $name (popularity: $popularity)" -ForegroundColor White
        }
    } else {
        Write-Host "No artists found in search result" -ForegroundColor Red
    }
    
    Write-Host "`n2. Using Get-SpotifyArtist function..." -ForegroundColor Yellow
    $topMatches = Get-SpotifyArtist -ArtistName "10cc"
    
    if ($topMatches) {
        Write-Host "Get-SpotifyArtist returned $($topMatches.Count) matches:" -ForegroundColor Gray
        foreach ($match in $topMatches) {
            Write-Host "  - $($match.Artist.Name) (score: $([math]::Round($match.Score, 3)))" -ForegroundColor White
        }
        
        Write-Host "`n3. String similarity tests..." -ForegroundColor Yellow
        $testSimilarity1 = Get-StringSimilarity -String1 "10cc" -String2 "10cc"
        $testSimilarity2 = Get-StringSimilarity -String1 "10cc" -String2 "Daens, de musical"
        $testSimilarity3 = Get-StringSimilarity -String1 "10cc" -String2 $topMatches[0].Artist.Name
        
        Write-Host "  '10cc' vs '10cc': $testSimilarity1" -ForegroundColor White
        Write-Host "  '10cc' vs 'Daens, de musical': $testSimilarity2" -ForegroundColor White
        Write-Host "  '10cc' vs '$($topMatches[0].Artist.Name)': $testSimilarity3" -ForegroundColor White
        
    } else {
        Write-Host "Get-SpotifyArtist returned no matches" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}