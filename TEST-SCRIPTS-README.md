# Provider Artist Extraction Test Scripts

Three handy test scripts for debugging artist extraction from music metadata providers.

## Features
- ✅ **No interactive loops** - Runs once and exits
- ✅ **No Clear-Host** - All debug output stays visible  
- ✅ **Direct API calls** - Bypasses complex workflows
- ✅ **Album metadata** - Shows album, artist, year, genre
- ✅ **Track summary** - Lists all tracks with artist counts
- ✅ **Diagnostics** - Highlights missing artists

---

## 1. Qobuz Test Script

**File:** `test-qobuz-artist-extraction.ps1`

### Usage
```powershell
.\test-qobuz-artist-extraction.ps1 -AlbumUrl "/be-fr/album/album-name/id" -Verbose
```

### Example
```powershell
.\test-qobuz-artist-extraction.ps1 -AlbumUrl "/be-fr/album/gorecki-symphonie-n-3/0822189003333" -Verbose
```

### What It Shows
- Raw `performerInfo` text from HTML
- Parsed results (Performers, Composers, Conductor, Ensemble)
- Album metadata: Album, Artist, Year, Genre, Label, Quality
- Track-by-track artist extraction with debug output
- Tracks missing artists (if any)

### How to Find Album URL
1. Go to Qobuz website: https://www.qobuz.com
2. Search for album
3. Copy the URL path after the domain (e.g., `/be-fr/album/...`)

---

## 2. Spotify Test Script

**File:** `test-spotify-artist-extraction.ps1`

### Usage
```powershell
.\test-spotify-artist-extraction.ps1 -AlbumId "spotify_album_id"
```

### Example
```powershell
.\test-spotify-artist-extraction.ps1 -AlbumId "6DEjYFkNZh67HP7R9PSZvv"
```

### What It Shows
- Album metadata: Album, Artist, Year, Genre, Label, Popularity
- Track-by-track artist extraction
- Artist counts per track
- Duration, disc number
- Tracks missing artists (if any)

### How to Find Album ID
1. Open Spotify and find the album
2. Click "..." → Share → Copy Spotify URI
3. Extract the ID from URI: `spotify:album:6DEjYFkNZh67HP7R9PSZvv` → `6DEjYFkNZh67HP7R9PSZvv`

Or use the web player URL:
- URL: `https://open.spotify.com/album/6DEjYFkNZh67HP7R9PSZvv`
- ID: `6DEjYFkNZh67HP7R9PSZvv`

---

## 3. Discogs Test Script

**File:** `test-discogs-artist-extraction.ps1`

### Usage
```powershell
.\test-discogs-artist-extraction.ps1 -ReleaseId "12345"
```

### Example
```powershell
.\test-discogs-artist-extraction.ps1 -ReleaseId "249504"
```

### What It Shows
- Album metadata: Album, Artist, Year, Genre, Style, Label, Country, Format
- Track-by-track artist extraction
- Position numbers (Discogs-specific)
- Artist counts per track
- Tracks missing artists (may inherit from album artist)

### How to Find Release ID
1. Go to Discogs website: https://www.discogs.com
2. Search for the release
3. Check the URL: `https://www.discogs.com/release/249504-...`
4. The number after `/release/` is the Release ID: `249504`

---

## Common Output Sections

All three scripts show:

### 1. Album Metadata
```
--- Album Metadata ---
Album: Górecki: Symphony No. 3
Album Artist: Dawn Upshaw
Year: 1992
Genre: Classical
```

### 2. First Track Example
```
--- First Track Example ---
Track: 01 - Lento - Sostenuto tranquillo ma cantabile
  artists.Count: 2
    - Dawn Upshaw (type: main)
    - London Sinfonietta (type: artist)
  Artist String: Dawn Upshaw; London Sinfonietta
```

### 3. All Tracks Overview
```
Track  Title                     Artists  Artist String
-----  -----                     -------  -------------
01     Symphony No. 3: I         2        Dawn Upshaw; London Sinfonietta
02     Symphony No. 3: II        1        London Sinfonietta
```

---

## Troubleshooting

### Qobuz: No Artists Extracted
- Check the `=== TRACK XX DEBUG ===` sections
- Look at "Raw performerInfo" - is it empty?
- If empty, the HTML selector may need updating
- Try visiting the album URL on Qobuz to verify it exists

### Spotify: Module Not Found
```powershell
Install-Module Spotishell -Scope CurrentUser
```

### Discogs: Authentication Error
Ensure you have Discogs credentials configured in the module.

---

## Why These Scripts Are Handy

1. **Quick Testing** - Test provider APIs without running full MuFo workflow
2. **Debug Output** - See exactly what data is being extracted
3. **No Side Effects** - Read-only operations, no file changes
4. **Portable** - Copy these scripts to test any album quickly
5. **Development** - Essential for debugging new provider features

---

## See Also
- Main MuFo documentation: `documentation/README.md`
- Provider implementation: `documentation/QOBUZ-RICH-METADATA.md`
- Configuration guide: `documentation/CONFIGURATION-GUIDE.md`
