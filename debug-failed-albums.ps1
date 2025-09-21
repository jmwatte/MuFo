# Test the failing albums with different search strategies

Write-Host "=== Testing Failed Albums with Manual Search Strategies ===" -ForegroundColor Cyan

$failedAlbums = @(
    @{ Name = "arvo part  cello concerto  bamberg symphony orchestra Neeme Jarvi"; Year = "1989" },
    @{ Name = "Collage neeme Jarvi"; Year = "1993" },
    @{ Name = "Alina -Vladimir Spivakov"; Year = "1999" },
    @{ Name = "I am the True Vine Paul Hillier"; Year = "1999" },
    @{ Name = "Tabula Rasa Symphonie nr 3 Ulster Orchestra"; Year = "2001" }
)

foreach ($album in $failedAlbums) {
    Write-Host "`n" + "="*70 -ForegroundColor Gray
    Write-Host "Testing: $($album.Name)" -ForegroundColor Yellow
    
    # Test 1: Current MuFo approach (what's failing)
    $mufoQuery = "artist:`"Arvo Pärt`" album:`"$($album.Name)`" year:$($album.Year)"
    Write-Host "`n1. Current MuFo Query:" -ForegroundColor Red
    Write-Host "   $mufoQuery" -ForegroundColor White
    try {
        $mufoResult = Search-Item -Type Album -Query $mufoQuery -ErrorAction Stop
        $mufoCount = if ($mufoResult.Albums.Items) { $mufoResult.Albums.Items.Count } else { 0 }
        Write-Host "   Results: $mufoCount" -ForegroundColor White
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $mufoCount = 0
    }
    
    # Test 2: Direct album name (what you do manually)
    Write-Host "`n2. Direct Album Search (Your Manual Method):" -ForegroundColor Green
    Write-Host "   `"$($album.Name)`"" -ForegroundColor White
    try {
        $directResult = Search-Item -Type Album -Query "`"$($album.Name)`"" -ErrorAction Stop
        $directCount = if ($directResult.Albums.Items) { $directResult.Albums.Items.Count } else { 0 }
        Write-Host "   Results: $directCount" -ForegroundColor White
        if ($directCount -gt 0) {
            # Look for Arvo Pärt matches
            $relevantResults = $directResult.Albums.Items | Where-Object { 
                $_.Artists | Where-Object { $_.Name -like "*Arvo*" -or $_.Name -like "*Pärt*" -or $_.Name -like "*Part*" }
            }
            Write-Host "   Arvo Pärt matches: $($relevantResults.Count)" -ForegroundColor Cyan
            $relevantResults | Select-Object -First 3 | ForEach-Object {
                Write-Host "   - $($_.Name) ($($_.ReleaseDate)) by $($_.Artists[0].Name)" -ForegroundColor White
            }
        }
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $directCount = 0
    }
    
    # Test 3: Simple artist + album
    $simpleQuery = "Arvo Pärt $($album.Name)"
    Write-Host "`n3. Simple Combined Search:" -ForegroundColor Blue
    Write-Host "   $simpleQuery" -ForegroundColor White
    try {
        $simpleResult = Search-Item -Type Album -Query $simpleQuery -ErrorAction Stop
        $simpleCount = if ($simpleResult.Albums.Items) { $simpleResult.Albums.Items.Count } else { 0 }
        Write-Host "   Results: $simpleCount" -ForegroundColor White
        if ($simpleCount -gt 0) {
            $simpleResult.Albums.Items | Select-Object -First 3 | ForEach-Object {
                Write-Host "   - $($_.Name) ($($_.ReleaseDate))" -ForegroundColor White
            }
        }
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $simpleCount = 0
    }
    
    # Test 4: Just key words from album name
    $keywords = ($album.Name -split '\s+' | Where-Object { $_.Length -gt 3 -and $_ -notmatch '^(part|arvo|neeme|vladimir|paul)$' }) -join ' '
    if ($keywords) {
        $keywordQuery = "Arvo Pärt $keywords"
        Write-Host "`n4. Keyword Search:" -ForegroundColor Magenta
        Write-Host "   $keywordQuery" -ForegroundColor White
        try {
            $keywordResult = Search-Item -Type Album -Query $keywordQuery -ErrorAction Stop
            $keywordCount = if ($keywordResult.Albums.Items) { $keywordResult.Albums.Items.Count } else { 0 }
            Write-Host "   Results: $keywordCount" -ForegroundColor White
            if ($keywordCount -gt 0) {
                $keywordResult.Albums.Items | Select-Object -First 3 | ForEach-Object {
                    Write-Host "   - $($_.Name) ($($_.ReleaseDate))" -ForegroundColor White
                }
            }
        } catch {
            Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Analysis
    Write-Host "`n5. ANALYSIS:" -ForegroundColor Cyan
    if ($mufoCount -eq 0 -and $directCount -gt 0) {
        Write-Host "   🎯 SOLUTION: Use direct album name search!" -ForegroundColor Green
    } elseif ($mufoCount -eq 0 -and $simpleCount -gt 0) {
        Write-Host "   🎯 SOLUTION: Use simple artist + album search!" -ForegroundColor Green
    } elseif ($mufoCount -eq 0) {
        Write-Host "   ⚠️  Album might have very different name on Spotify" -ForegroundColor Yellow
    } else {
        Write-Host "   ❓ MuFo query should work - check scoring threshold" -ForegroundColor Orange
    }
}

Write-Host "`n" + "="*70 -ForegroundColor Gray
Write-Host "RECOMMENDATION:" -ForegroundColor Cyan
Write-Host "Add more search strategies to Get-SpotifyAlbumMatches:" -ForegroundColor White
Write-Host "1. Direct album name search (what you do manually)" -ForegroundColor Green
Write-Host "2. Simple 'Artist Album' search without prefixes" -ForegroundColor Green
Write-Host "3. Keyword extraction for complex album names" -ForegroundColor Green