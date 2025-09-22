# Test script to analyze Spotify API rate limiting behavior
# This helps us understand current throttling and improve it if needed

Write-Host "=== Spotify API Rate Limiting Analysis ===" -ForegroundColor Green
Write-Host ""

# Test rapid sequential searches
Write-Host "🔍 Testing rapid sequential artist searches..." -ForegroundColor Cyan
$searchTerms = @("Beatles", "Led Zeppelin", "Pink Floyd", "Rolling Stones", "Bob Dylan", "Elvis", "Queen", "David Bowie", "U2", "Madonna")

$startTime = Get-Date
$results = @()

foreach ($term in $searchTerms) {
    $callStart = Get-Date
    try {
        $result = Search-Item -Type Artist -Query $term -ErrorAction Stop
        $callEnd = Get-Date
        $duration = ($callEnd - $callStart).TotalMilliseconds
        
        $results += [PSCustomObject]@{
            SearchTerm = $term
            Success = $true
            Duration = $duration
            ResultCount = $result.artists.items.Count
            HttpStatus = "OK"
        }
        
        Write-Host "✅ $term ($([math]::Round($duration))ms)" -ForegroundColor Green
        
    } catch {
        $callEnd = Get-Date
        $duration = ($callEnd - $callStart).TotalMilliseconds
        
        $results += [PSCustomObject]@{
            SearchTerm = $term
            Success = $false
            Duration = $duration
            ResultCount = 0
            HttpStatus = $_.Exception.Message
        }
        
        Write-Host "❌ $term ($([math]::Round($duration))ms) - $($_.Exception.Message)" -ForegroundColor Red
        
        # Check if it's a rate limit error (429)
        if ($_.Exception.Message -match "429|rate|limit") {
            Write-Host "🚫 RATE LIMIT DETECTED!" -ForegroundColor Yellow
            break
        }
    }
}

$totalTime = (Get-Date) - $startTime

Write-Host ""
Write-Host "📊 Results Summary:" -ForegroundColor Yellow
Write-Host "Total time: $([math]::Round($totalTime.TotalSeconds, 2)) seconds"
Write-Host "Average per call: $([math]::Round(($results | Measure-Object Duration -Average).Average)) ms"
Write-Host "Successful calls: $(($results | Where-Object Success).Count) / $($results.Count)"

# Check if we have any rate limiting patterns
$slowCalls = $results | Where-Object Duration -gt 1000
if ($slowCalls) {
    Write-Host ""
    Write-Host "⚠️ Slow calls detected (>1000ms):" -ForegroundColor Yellow
    $slowCalls | Format-Table SearchTerm, Duration, HttpStatus -AutoSize
}

# Test what happens with immediate retry after potential rate limit
Write-Host ""
Write-Host "🔄 Testing immediate retry behavior..." -ForegroundColor Cyan
try {
    $retry1 = Measure-Command { Search-Item -Type Artist -Query "TestArtist1" -ErrorAction Stop }
    $retry2 = Measure-Command { Search-Item -Type Artist -Query "TestArtist2" -ErrorAction Stop }
    $retry3 = Measure-Command { Search-Item -Type Artist -Query "TestArtist3" -ErrorAction Stop }
    
    Write-Host "Retry timings: $([math]::Round($retry1.TotalMilliseconds))ms, $([math]::Round($retry2.TotalMilliseconds))ms, $([math]::Round($retry3.TotalMilliseconds))ms"
    
} catch {
    Write-Host "Retry test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 Rate Limiting Analysis Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Spotify API Limits (from documentation):" -ForegroundColor Cyan
Write-Host "   • Web API: Varied by endpoint, typically 100-1000 requests per minute"
Write-Host "   • Premium users: No specific advantages for API rate limits"
Write-Host "   • Rate limit responses: HTTP 429 with Retry-After header"
Write-Host ""
Write-Host "🚀 Potential Optimizations:" -ForegroundColor Yellow
Write-Host "   1. Add delays between rapid calls (100-500ms)"
Write-Host "   2. Implement retry logic with backoff"
Write-Host "   3. Use batch endpoints where available (Get-Track supports 50 IDs)"
Write-Host "   4. Cache results to reduce redundant calls"
Write-Host "   5. Respect Retry-After headers in 429 responses"