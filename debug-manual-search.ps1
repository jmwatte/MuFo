# Test manual Spotify searches to see why MuFo isn't finding what you can find manually

Write-Host "=== Manual Spotify Search Analysis ===" -ForegroundColor Cyan

# Import the modules and connect if needed
try {
    $null = Get-SpotifyAccessToken -ErrorAction Stop
    Write-Host "✓ Already connected to Spotify" -ForegroundColor Green
} catch {
    Write-Host "Connecting to Spotify..." -ForegroundColor Yellow
    Connect-Spotify -ErrorAction Stop
}

# Test the exact queries MuFo is using vs simpler queries
$testAlbums = @(
    @{ Name = "Tabula Rasa"; Year = "1984" },
    @{ Name = "Fratres"; Year = "1995" },
    @{ Name = "Te Deum"; Year = "1993" },
    @{ Name = "Passio"; Year = "1988" },
    @{ Name = "Miserere"; Year = "1991" }
)

foreach ($test in $testAlbums) {
    Write-Host "`n" + "="*60 -ForegroundColor Gray
    Write-Host "Testing: $($test.Name) ($($test.Year))" -ForegroundColor Yellow
    
    # Test 1: Exact MuFo query (what's failing)
    $mufoQuery = "artist:`"Arvo Pärt`" album:`"$($test.Name)`" year:$($test.Year)"
    Write-Host "`n1. MuFo Query: $mufoQuery" -ForegroundColor Red
    try {
        $mufoResult = Search-Item -Type Album -Query $mufoQuery -ErrorAction Stop
        $mufoCount = if ($mufoResult.Albums.Items) { $mufoResult.Albums.Items.Count } else { 0 }
        Write-Host "   Results: $mufoCount" -ForegroundColor White
        if ($mufoCount -gt 0) {
            $mufoResult.Albums.Items | Select-Object -First 3 | ForEach-Object {
                Write-Host "   - $($_.Name) ($($_.ReleaseDate))" -ForegroundColor White
            }
        }
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $mufoCount = 0
    }
    
    # Test 2: Simple query (what you probably use manually)
    $simpleQuery = "Arvo Pärt $($test.Name)"
    Write-Host "`n2. Simple Query: $simpleQuery" -ForegroundColor Green
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
    
    # Test 3: Just album name
    $albumQuery = $test.Name
    Write-Host "`n3. Album Only: $albumQuery" -ForegroundColor Blue
    try {
        $albumResult = Search-Item -Type Album -Query $albumQuery -ErrorAction Stop
        $albumCount = if ($albumResult.Albums.Items) { $albumResult.Albums.Items.Count } else { 0 }
        Write-Host "   Results: $albumCount" -ForegroundColor White
        if ($albumCount -gt 0) {
            # Look for Arvo Pärt in results
            $relevantResults = $albumResult.Albums.Items | Where-Object { 
                $_.Artists | Where-Object { $_.Name -like "*Arvo*" -or $_.Name -like "*Pärt*" }
            }
            Write-Host "   Arvo Pärt matches: $($relevantResults.Count)" -ForegroundColor Cyan
            $relevantResults | Select-Object -First 3 | ForEach-Object {
                Write-Host "   - $($_.Name) ($($_.ReleaseDate)) by $($_.Artists[0].Name)" -ForegroundColor White
            }
        }
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Analysis
    Write-Host "`n4. ANALYSIS:" -ForegroundColor Magenta
    if ($mufoCount -eq 0 -and $simpleCount -gt 0) {
        Write-Host "   🔍 MuFo query too restrictive - simple query works!" -ForegroundColor Green
    } elseif ($mufoCount -eq 0 -and $simpleCount -eq 0) {
        Write-Host "   ⚠️  Both queries failed - album might have different name on Spotify" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ MuFo query should work" -ForegroundColor Green
    }
}

Write-Host "`n" + "="*60 -ForegroundColor Gray
Write-Host "CONCLUSION:" -ForegroundColor Cyan
Write-Host "If simple queries work but MuFo queries fail, we need to:" -ForegroundColor White
Write-Host "1. Use simpler, less restrictive query formats" -ForegroundColor Green
Write-Host "2. Remove or modify the 'artist:' and 'album:' prefixes" -ForegroundColor Green
Write-Host "3. Try multiple query variations automatically" -ForegroundColor Green