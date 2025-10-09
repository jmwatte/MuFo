# Multi-Album Selection Feature

**Implementation Date:** October 5, 2025  
**Branch:** refactor/invoke-mufo-modularization

## Feature Overview
Allows selection of multiple albums in Stage B to combine their tracks into a single matching operation. Perfect for box sets, compilations, and complete collections split across multiple Spotify albums.

## Usage

### Stage B - Album Selection
```
Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), ...

Examples:
  1          → Single album (existing behavior)
  1,3,5      → Albums 1, 3, and 5
  1-5        → Albums 1 through 5
  1-3,7,9-12 → Albums 1, 2, 3, 7, 9, 10, 11, 12
```

### What Happens
1. **Fetches tracks** from all selected albums
2. **Combines** into single bucket of provider tracks
3. **Matches** against all audio files in folder (single operation)
4. **Displays** in Stage C as one combined album set
5. **Saves** all tags in one pass

## Implementation Details

### Stage B Changes (`Invoke-MuFoManual.ps1` lines 228-312)

**Input Parsing:**
- Regex: `^[\d,\-\s]+$` matches numbers, commas, hyphens, spaces
- Splits on comma: `1,3,5` → `[1, 3, 5]`
- Expands ranges: `5-8` → `[5, 6, 7, 8]`
- Validates all indices against album list

**Multi-Album Processing:**
```powershell
foreach ($idx in $validIndices) {
    $currentAlbum = $albumsForArtist[$idx - 1]
    $tracks = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $currentAlbum.id
    $combinedTracks += $tracks
}
```

**Creates Synthetic Album Object:**
```powershell
$ProviderAlbum = [PSCustomObject]@{
    id = "combined_$($validIndices -join '_')"
    name = "$($albumNames[0]) + $($validIndices.Count - 1) more albums"
    release_date = $firstAlbum.release_date
    _isCombined = $true              # Flag for Stage C
    _albumCount = $validIndices.Count
    _albumNames = $albumNames         # Array of all album names
    _selectedIndices = $validIndices  # Original selection
    _tracks = $combinedTracks         # Pre-fetched tracks
}
```

### Stage C Changes (`Invoke-MuFoManual.ps1` lines 331-378)

**Header Display:**
```powershell
if ($ProviderAlbum._isCombined) {
    Write-Host "Processing COMBINED album set:" -ForegroundColor Yellow
    Write-Host "  Albums: $($ProviderAlbum._albumCount)"
    Write-Host "  Tracks: $($ProviderAlbum._tracks.Count)"
    foreach ($albumName in $ProviderAlbum._albumNames) {
        Write-Host "    - $albumName"
    }
}
```

**Track Loading:**
```powershell
if ($ProviderAlbum._isCombined) {
    $tracksForAlbum = $ProviderAlbum._tracks  # Use pre-fetched
} else {
    $tracksForAlbum = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $ProviderAlbum.id
}
```

**Rest of Stage C is unchanged** - matching, display, and saving work the same!

## Use Cases

### Box Sets
```
Artist: Bach
Albums in Spotify:
  1. Complete Cantatas Vol 1 (22 tracks)
  2. Complete Cantatas Vol 2 (24 tracks)
  3. Complete Cantatas Vol 3 (20 tracks)

Local folder: "Bach - Complete Cantatas" (66 audio files)

Selection: 1-3
Result: All 66 Spotify tracks matched against 66 local files in one operation
```

### Complete Collections
```
Artist: Fats Waller
Albums in Spotify:
  5. Complete Edition Disc 1
  6. Complete Edition Disc 2
  7. Complete Edition Disc 3
  8. Complete Edition Disc 4

Local folder: "Fats Waller/Complete Edition/" (multiple disc folders)

Selection: 5-8
Result: All discs combined and matched together
```

### Split Compilations
```
Artist: Various Artists
Albums in Spotify:
  2. Now That's What I Call Music Vol 1 (CD1)
  3. Now That's What I Call Music Vol 1 (CD2)

Local folder: "Now That's What I Call Music Vol 1" (all tracks in one folder)

Selection: 2,3
Result: Both CDs combined into single track list
```

## Benefits

✅ **Eliminates repetition** - Process entire box set at once instead of album-by-album  
✅ **Better matching** - All tracks available for matching algorithms  
✅ **Cleaner workflow** - One Stage C session instead of multiple  
✅ **Handles splits** - Works when Spotify splits album but local files are combined  
✅ **Backwards compatible** - Single album selection still works as before

## Technical Notes

### Deduplication
The enhanced matching methods (byDuration, byTitle, byName) already prevent duplicate matches, so combined albums work seamlessly.

### Error Handling
- Validates all album indices before processing
- Shows progress per album during track fetching
- Reports failed albums but continues with successful ones
- Requires at least one album to have tracks

### Performance
- Fetches all albums sequentially (not parallel)
- Shows progress feedback during fetching
- No performance degradation for single album selection

### Limitations
- Cannot mix with `id:<id>` direct ID input
- Filter operations reset to full album list (by design)
- Album names truncated in header if more than 2 albums selected

## Future Enhancements

Possible improvements:
- [ ] Parallel track fetching for faster loading
- [ ] Remember last multi-selection for retry
- [ ] Show disc/album source in track display
- [ ] Export combined album metadata
- [ ] Support for `-AutoSelect` with multi-album patterns

## Testing

Test scenarios:
1. Single album selection (backwards compatibility)
2. Simple range: `1-3`
3. Mixed selection: `1,3,5-8,12`
4. Invalid ranges (out of bounds)
5. Failed album fetch (partial success)
6. All albums failed (error handling)
7. Box set with 10+ albums
8. Combined with different providers (Spotify, Qobuz)

## Files Modified

- `Public/Invoke-MuFoManual.ps1`
  - Lines 193: Updated prompt text
  - Lines 228-312: Multi-album parsing and combination
  - Lines 331-378: Combined album detection and track loading
