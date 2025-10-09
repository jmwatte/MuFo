# Discogs Smart Search Fix - API Search Working!

## Problem

When using `Invoke-MuFoManual` with Discogs provider on large discographies (e.g., Fats Waller with 8100 releases across 81 pages), the "smart search" feature was **still fetching all albums** instead of returning targeted matches. This caused:

- **Rate limit exhaustion**: 81 pages would take ~1.5 minutes and consume 81 of 60 req/min quota
- **Poor user experience**: Long waits for every search refinement
- **Unexpected behavior**: User expected 5-10 targeted results, got all 8100 albums

## Root Cause

The **real problem** was in `Invoke-DiscogsRequest` - it was converting the `Body` parameter to JSON for ALL requests, but Discogs `/database/search` expects **URL query parameters**, not JSON body.

```powershell
# BEFORE (broken):
if ($Body) {
    $requestParams['Body'] = ($Body | ConvertTo-Json -Depth 10)  # Wrong for GET!
    $requestParams['ContentType'] = 'application/json'
}
```

This caused all search requests to fail silently, returning artists instead of releases.

## Solution: Fix Invoke-DiscogsRequest

The fix was simple - only use JSON body for POST/PUT requests, pass Body as query parameters for GET:

```powershell
# AFTER (fixed):
if ($Body) {
    if ($Method -eq 'Get') {
        $requestParams['Body'] = $Body  # Query parameters for GET
    } else {
        $requestParams['Body'] = ($Body | ConvertTo-Json -Depth 10)  # JSON for POST/PUT
        $requestParams['ContentType'] = 'application/json'
    }
}
```

## Implementation

### 1. Fixed `Invoke-DiscogsRequest.ps1`
- Changed Body handling to respect HTTP method
- GET requests now properly send query parameters
- POST/PUT still use JSON body as expected

### 2. Updated `Search-DAlbumsByName.ps1`
Now uses **two approaches**:

**A. API Search (primary, fast)**:
```powershell
# Use Discogs API with title and artist parameters
$searchParams = @{
    artist = 'Fats Waller'
    title = 'complete recorded works'
    type = 'release'  # or 'master' if MastersOnly
}
$searchResult = Invoke-DiscogsRequest -Uri '/database/search' -Body $searchParams
```

**B. Cache-based filtering (fallback)**:
```powershell
# If cache provided or API fails, filter locally
if ($AllAlbumsCache) {
    $filtered = $AllAlbumsCache | Where-Object { $_.name -like "*$AlbumName*" }
}
```

### 3. Updated `Invoke-MuFoManual.ps1` Stage B
- **Removed** pre-fetching all albums
- Now calls API search directly (1 API call per search)
- Cache only used if explicitly provided

## Performance Impact

### Before Fix
- Every search: 81 pages × API calls = **81 requests**
- Multiple searches: 81 × N = **rate limit hell**
- Time per search: ~1.5 minutes

### After Fix  
- Every search: **1 targeted API call**
- Multiple searches: N × 1 = **N requests** (manageable)
- Time per search: **~500ms**

### Example
```
User searches for "handful of keys": 1 API call → 46 results
User refines to "piano solos": 1 API call → 40 results
Total: 2 API calls vs. 162 pages (before fix)
```

## Testing

### Test Results
```powershell
.\test-discogs-api-search.ps1
```

✅ **Test 1 - API Search**: Found 6 "Complete Recorded Works" albums (1 API call)  
✅ **Test 2 - Cache Filtering**: Wildcard and fuzzy matching work correctly  
✅ **Test 3 - Real World**: "handful of keys" → 46 results (1 API call)  
✅ **Test 4 - Multiple Searches**: "piano solos" → 40 results (1 API call)

**Success**: API search works correctly, no rate limit issues!

## Discovery Credit

User provided test script (`testWaller.ps1`) that directly called `Invoke-RestMethod` with proper query parameters, which revealed the bug in `Invoke-DiscogsRequest`. The Discogs API works fine - our wrapper was broken.

## Files Modified

### Fixed
- `Private/manual/Invoke-DiscogsRequest.ps1` - Fixed Body parameter handling for GET requests

### Updated
- `Private/manual/Search-DAlbumsByName.ps1` - Now uses API search (with cache fallback)
- `Public/Invoke-MuFoManual.ps1` - Removed unnecessary pre-fetching logic
- `Private/manual/Invoke-ProviderSearchAlbums.ps1` - Passes through to API search

### New
- `test-discogs-api-search.ps1` - Comprehensive test validating API search works
- `Private/manual/testWaller.ps1` - User's test script that helped discover the bug

### Documentation
- This file (`DISCOGS-API-SEARCH-FIX.md`)
- ~~`DISCOGS-SMART-SEARCH-FIX.md`~~ (obsolete - was based on wrong diagnosis)

## Commit Message

```
fix: Discogs API search by correcting Body parameter handling in GET requests

Problem:
- Invoke-DiscogsRequest converted Body to JSON for all HTTP methods
- Discogs /database/search expects URL query parameters, not JSON body
- Result: All searches failed silently, returning artists instead of releases
- Workaround attempted: Cache-based filtering (slow, 81 pages pre-fetch)

Root Cause:
- Invoke-DiscogsRequest treated GET same as POST/PUT (JSON body)
- PowerShell Invoke-RestMethod needs hashtable for query params in GET

Solution:
- Fixed Invoke-DiscogsRequest: Use Body as query params for GET, JSON for POST/PUT
- Updated Search-DAlbumsByName: Use API search (primary), cache (fallback)
- Removed unnecessary pre-fetching from Invoke-MuFoManual Stage B

Impact:
- Before: 81 pages × N searches = rate limit hell, ~1.5 min per search
- After: 1 API call per search, ~500ms, targeted results

Testing:
- ✅ "complete recorded works" → 6 results (1 API call)
- ✅ "handful of keys" → 46 results (1 API call)
- ✅ "piano solos" → 40 results (1 API call)
- ✅ Multiple searches: No rate limit issues

Credit: User's testWaller.ps1 script revealed the bug by working correctly
where our wrapper failed.
```

## Next Steps

1. ✅ Test with Fats Waller in actual `Invoke-MuFoManual` workflow
2. Remove obsolete `DISCOGS-SMART-SEARCH-FIX.md` (wrong solution)
3. Update `SMART-ALBUM-SEARCH.md` with correct Discogs implementation
4. Consider adding caching for repeated identical searches (optional optimization)
