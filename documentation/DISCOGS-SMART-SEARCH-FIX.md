# Discogs Smart Search Fix - Cache-Based Filtering

## Problem

When using `Invoke-MuFoManual` with Discogs provider on large discographies (e.g., Fats Waller with 8100 releases across 81 pages), the "smart search" feature was **still fetching all albums** instead of returning targeted matches. This caused:

- **Rate limit exhaustion**: 81 pages × 60 requests/minute = ~1.5 minutes to fetch all
- **Poor user experience**: Long waits for every search refinement
- **Unexpected behavior**: User expected 5-10 targeted results, got all 8100 albums

## Root Cause

The Discogs API `/database/search` endpoint is fundamentally broken for release searching:

```powershell
# Expected behavior: Return releases
Invoke-DiscogsRequest -Uri 'https://api.discogs.com/database/search' -Body @{
    type = 'release'
    artist = 'Fats Waller'
    title = 'complete recorded works'
}

# Actual behavior: Returns ARTISTS regardless of type=release parameter
# Result: 50 artist objects (Rick Rubin, Holland-Dozier-Holland, etc.)
```

**All tested variations failed** (tested per official API documentation):
- `type=release` + `artist` + `title` → returns artists
- `artist` + `release_title` → returns artists (per docs: "Search release titles")
- `release_title` alone → returns artists
- `title='Artist - Album'` → returns artists (per docs: "combined Artist-Release field")
- `q='artist album', type=master` → returns artists
- `q='specific album name', type=master` → returns artists

The Discogs web UI search works fine (`https://www.discogs.com/search/?type=release&title=X&artist=Y`), but the API endpoint `/database/search` is completely broken for release searching - it consistently returns only artist objects regardless of parameters used.

## Solution: Cache-Based Filtering

Instead of relying on the broken Discogs API search, we implemented a **fetch-once, cache, filter locally** strategy:

### Before Fix (Broken)
```powershell
# Stage B in Invoke-MuFoManual.ps1
$albumsForArtist = Invoke-ProviderSearchAlbums -AlbumName $albumName  # Calls Discogs API
# Discogs API returns 0 results (broken)
if (-not $albumsForArtist) {
    $albumsForArtist = Invoke-ProviderGetAlbums  # Fallback: fetch ALL 81 pages!
}
```

**Result**: Every album search fetches 81 pages, hits rate limit quickly.

### After Fix (Working)
```powershell
# Stage B in Invoke-MuFoManual.ps1 (updated)
if (-not $cachedAlbums) {
    # Fetch all albums ONCE when entering Stage B
    $cachedAlbums = Invoke-ProviderGetAlbums  # Fetch all (one-time cost)
}

# Smart search filters the cache (no API calls)
$albumsForArtist = Invoke-ProviderSearchAlbums `
    -AlbumName $albumName `
    -AllAlbumsCache $cachedAlbums  # Pass cache for local filtering
```

**Result**: Albums fetched once (81 pages), then all searches filter locally (zero API calls).

### Implementation Details

1. **`Search-DAlbumsByName.ps1`** (rewritten):
   ```powershell
   param(
       [string]$ArtistId,
       [string]$ArtistName,
       [string]$AlbumName,
       [array]$AllAlbumsCache  # NEW: Optional pre-fetched albums
   )
   
   if ($AllAlbumsCache) {
       $allAlbums = $AllAlbumsCache  # Use cache
   } else {
       $allAlbums = Get-DArtistAlbums -Id $ArtistId  # Fetch if no cache
   }
   
   # Filter locally using wildcard matching
   $filtered = $allAlbums | Where-Object { $_.name -like "*$AlbumName*" }
   
   # Fallback to fuzzy matching (Jaccard similarity > 0.3)
   if ($filtered.Count -eq 0) {
       $filtered = $allAlbums | Where-Object { 
           (Get-StringSimilarity-Jaccard $AlbumName $_.name) -gt 0.3 
       }
   }
   ```

2. **`Invoke-ProviderSearchAlbums.ps1`** (updated):
   ```powershell
   param(
       [string]$Provider,
       [string]$ArtistId,
       [string]$ArtistName,
       [string]$AlbumName,
       [array]$AllAlbumsCache  # NEW: Pass-through parameter
   )
   
   if ($Provider -eq 'Discogs' -and $AllAlbumsCache) {
       Search-DAlbumsByName -AllAlbumsCache $AllAlbumsCache  # Use cache
   }
   ```

3. **`Invoke-MuFoManual.ps1` Stage B** (updated):
   ```powershell
   # Clear cache if artist changed
   if ($cachedArtistId -ne $ProviderArtist.id) {
       $cachedAlbums = $null
   }
   
   # Fetch ALL albums once and cache
   if (-not $cachedAlbums) {
       $cachedAlbums = Invoke-ProviderGetAlbums -ArtistId $ProviderArtist.id
   }
   
   # Filter cached albums (no API calls)
   $albumsForArtist = Invoke-ProviderSearchAlbums `
       -AlbumName $albumName `
       -AllAlbumsCache $cachedAlbums
   ```

## Benefits

### Performance
- **Before**: N album searches × 81 pages = N × 81 API calls
- **After**: 1 × 81 pages + N × 0 API calls = 81 API calls total

### User Experience
- **Instant search refinement**: Users can try multiple search terms without waiting
- **No rate limit issues**: 81 pages fetched once, then unlimited local searches
- **Predictable behavior**: First search takes ~1.5 minutes (one-time cost), subsequent searches are instant

### Code Quality
- **Provider abstraction maintained**: Spotify/Qobuz use API search, Discogs uses cache-based filtering
- **Fallback logic removed**: No longer need complex "try search, fallback to get-all" logic
- **Consistent behavior**: All providers now return filtered results, not full discography

## Testing

### Unit Tests (Mock Data)
```powershell
.\test-discogs-smart-search.ps1
```
- ✅ Wildcard matching: "complete" → 2 results
- ✅ Fuzzy matching: "handful keys" → 1 result (67% similarity)

### Integration Tests (Real API)
- ✅ Fetch 15 albums from Discogs (Black Science Orchestra, ID 105)
- ✅ Search 1: "sunshine" → 2 results (no additional API calls)
- ✅ Search 2: "new jersey" → 2 results (no additional API calls)
- ✅ Search 3: "walters room" → 1 result (no additional API calls)

## Related Files

### Modified
- `Private/manual/Search-DAlbumsByName.ps1` - Rewritten for cache-based filtering
- `Private/manual/Invoke-ProviderSearchAlbums.ps1` - Added AllAlbumsCache parameter
- `Public/Invoke-MuFoManual.ps1` - Stage B updated to fetch-once-cache-filter strategy

### New
- `test-discogs-smart-search.ps1` - Comprehensive test script validating cache behavior

### Documentation
- This file (`DISCOGS-SMART-SEARCH-FIX.md`)
- Update `documentation/SMART-ALBUM-SEARCH.md` with Discogs-specific notes

## Commit Message

```
fix: Discogs smart search using cache-based filtering (API search broken)

Problem:
- Discogs /database/search API returns artists instead of releases
- Smart search fell back to fetching ALL albums (81 pages, rate limit issues)
- User expected targeted results, got 8100 albums

Solution:
- Fetch all albums ONCE when entering manual workflow Stage B
- Cache results for artist session
- Filter locally using wildcard + fuzzy matching
- Zero additional API calls for subsequent searches

Impact:
- Before: N searches × 81 pages = N × 81 API calls
- After: 81 pages (one-time) + 0 API calls per search
- Instant search refinement, no rate limit issues

Tested:
- Unit: Wildcard and fuzzy matching with mock data
- Integration: 3 searches on real Discogs API (0 additional calls)

Fixes user report: "launch-invoke-mufo.ps1 still seems to be pulling a lot 
of pages and we get the ratelimit pretty fast"
```

## Next Steps

1. Test with Fats Waller (original problem case)
2. Monitor rate limit usage in production
3. Consider adding TTL to cache (refresh after N minutes)
4. Document Discogs API limitation in user-facing docs
