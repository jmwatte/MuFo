# MuFo Codebase Analysis & Improvements

## Fixed Issues

### 1. Year Matching Problem ✅ **FIXED**
**Issue:** Albums matched by name similarity only, causing incorrect year selection (e.g., Arvo Pärt "Tabula Rasa" 2018 instead of 1984).

**Solution Implemented:**
- Added year-aware scoring with +0.3 bonus for release year matches
- Added `-Year` parameter to `Get-SpotifyAlbumMatches` 
- Implemented Spotify `year:` field filter in searches
- Extract year from folder names for targeted queries

**Impact:** Should now correctly prefer original 1984 release over 2018 remaster.

## Identified Improvement Areas

### 2. Performance Optimizations

**Current Issues:**
- Multiple redundant API calls in inference logic
- Sequential searches instead of parallel where possible
- No caching of Spotify responses

**Recommendations:**
```powershell
# Add response caching
$script:SpotifyCache = @{}

# Parallel search pattern
$jobs = @()
$jobs += Start-Job { Search-Item -Type Album -Query $query1 }
$jobs += Start-Job { Search-Item -Type Artist -Query $query2 }
$results = $jobs | Receive-Job -Wait
```

### 3. Configuration & Thresholds

**Current Issues:**
- Hardcoded thresholds (0.8, 0.3, etc.)
- Magic numbers scattered throughout code
- No user-configurable similarity weights

**Recommendations:**
```powershell
# Add configuration parameter set
[Parameter(Mandatory = $false)]
[hashtable]$ScoringConfig = @{
    ArtistSimilarityThreshold = 0.8
    AlbumSimilarityThreshold = 0.3
    YearMatchBonus = 0.3
    TrackMatchThreshold = 0.8
}
```

### 4. Error Handling & Resilience

**Current Issues:**
- Some API calls lack comprehensive error boundaries
- Limited retry logic for transient failures
- Inconsistent error messaging

**Recommendations:**
```powershell
function Invoke-SpotifyApiWithRetry {
    param($ScriptBlock, $MaxRetries = 3)
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            return & $ScriptBlock
        } catch [System.Net.Http.HttpRequestException] {
            if ($i -eq $MaxRetries - 1) { throw }
            Start-Sleep -Seconds (2 * ($i + 1))
        }
    }
}
```

### 5. Album Type Handling

**Current Issues:**
- Limited support for various album types (EP, single, compilation)
- No special handling for box sets vs regular albums
- Remaster detection could be improved

**Recommendations:**
```powershell
# Enhanced album type scoring
function Get-AlbumTypeScore {
    param($AlbumType, $LocalFolderHints)
    switch ($AlbumType.ToLower()) {
        'album' { return 1.0 }
        'compilation' { return if ($LocalFolderHints -match 'best|greatest|collection') { 1.0 } else { 0.7 } }
        'ep' { return if ($LocalFolderHints -match 'ep') { 1.0 } else { 0.5 } }
        'single' { return 0.3 }
    }
}
```

### 6. Memory & Resource Management

**Current Issues:**
- Large album collections could consume significant memory
- No streaming/pagination for very large datasets
- TagLib-Sharp resources not explicitly disposed

**Recommendations:**
```powershell
# Implement streaming for large collections
function Get-AlbumsInBatches {
    param($Path, $BatchSize = 50)
    $albums = Get-ChildItem $Path -Directory
    for ($i = 0; $i -lt $albums.Count; $i += $BatchSize) {
        $batch = $albums[$i..([Math]::Min($i + $BatchSize - 1, $albums.Count - 1))]
        yield $batch
    }
}
```

### 7. Search Strategy Enhancement

**Current Issues:**
- Single search strategy doesn't adapt to results quality
- No fallback mechanisms when primary search fails
- Limited use of Spotify's advanced search operators

**Recommendations:**
```powershell
# Adaptive search strategy
function Search-AlbumAdaptive {
    param($Artist, $Album, $Year)
    
    # Try exact match first
    $exact = Search-Item -Query "`"$Artist`" `"$Album`" year:$Year"
    if ($exact -and $exact.Count -gt 0) { return $exact }
    
    # Try without quotes
    $loose = Search-Item -Query "$Artist $Album year:$Year"
    if ($loose -and $loose.Count -gt 0) { return $loose }
    
    # Try without year
    return Search-Item -Query "$Artist $Album"
}
```

### 8. Validation & Testing

**Current Issues:**
- Limited integration test coverage
- No performance benchmarks
- No validation against known good datasets

**Recommendations:**
```powershell
# Add validation test suite
Describe 'MuFo Accuracy Tests' {
    Context 'Known Album Matches' {
        It 'Should correctly identify Beatles albums' {
            $result = Invoke-MuFo -Path 'TestData/The Beatles' -Preview
            $result | Where-Object LocalFolder -eq '1963 - Please Please Me' | 
                Should -Have -Property SpotifyArtist -EQ 'The Beatles'
        }
    }
}
```

## Architectural Improvements

### 9. Modular Design
Split large functions into focused, testable units:
- `Get-ArtistCandidates`
- `Get-AlbumMatches` 
- `Invoke-AlbumScoring`
- `Resolve-ArtistFromAlbums`

### 10. Pipeline Support
Enhance pipeline compatibility:
```powershell
Get-ChildItem 'C:\Music' -Directory | 
    ForEach-Object { [PSCustomObject]@{ Path = $_.FullName; Artist = $_.Name } } |
    Invoke-MuFo -PassThru
```

## Future Prompt Optimization

**For your Arvo Pärt issue, you could have specified:**
```
"Fix year matching in MuFo so it prefers albums with release years matching the local folder year prefix (e.g., '1984 - Tabula Rasa' should match 1984 Spotify release, not 2018 remaster). Add year-aware scoring and include year filters in Spotify searches."
```

**For codebase improvements:**
```
"Analyze MuFo codebase for performance issues, error handling gaps, and architectural improvements. Focus on: API call optimization, configurable thresholds, better album type handling, and modular design patterns."
```

## Priority Implementation Order

1. **High Priority:** Configuration system for thresholds
2. **High Priority:** Enhanced error handling with retries  
3. **Medium Priority:** Performance optimizations (caching, parallel calls)
4. **Medium Priority:** Improved album type scoring
5. **Low Priority:** Streaming support for large collections
6. **Low Priority:** Advanced search strategies

The year matching fix should resolve your immediate Arvo Pärt issue. Test with:
```powershell
Invoke-MuFo -Path "E:\_CorrectedMusic\Arvo Part" -WhatIf -Verbose
```