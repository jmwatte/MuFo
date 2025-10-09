# Discogs Release Filtering Guide

## The Problem

Discogs returns **ALL** releases for an artist, which can include:
- **Master Releases** - Canonical versions (e.g., "The Beatles - Abbey Road")
- **Individual Releases** - Specific pressings (e.g., "1969 UK Vinyl", "1987 CD Remaster", "2009 Remaster")
- **Singles** - Individual tracks
- **Compilations** - Best-of collections
- **Appearances** - Guest spots on other artists' albums

For popular artists, this can be **hundreds or thousands** of entries!

### Example: Fats Waller
- **589 total releases** (default filtering)
- **228 master releases** (canonical versions only)
- Many different pressings of the same album!

## Filtering Options

### Default Behavior (`-MastersOnly` = $true)

**Recommended for most use cases**

```powershell
Get-DArtistAlbums -Id 253482
```

**Returns**: Master releases only (canonical album versions)
**Excludes**: Individual pressings, singles, compilations, appearances
**Best for**: Music library management - avoids duplicate albums

### Get All Releases (`-MastersOnly:$false`)

```powershell
Get-DArtistAlbums -Id 253482 -MastersOnly:$false
```

**Returns**: All individual releases (every pressing, variant, edition)
**Good for**: Collectors tracking specific pressings
**Warning**: Can return hundreds of releases for popular artists!

### Include Singles

```powershell
Get-DArtistAlbums -Id 253482 -IncludeSingles
```

**Adds**: Singles to the results
**Use when**: You want individual tracks in addition to albums

### Include Compilations

```powershell
Get-DArtistAlbums -Id 253482 -IncludeCompilations
```

**Adds**: Best-of collections, greatest hits, etc.
**Use when**: You have compilation albums in your library

### Include Appearances

```powershell
Get-DArtistAlbums -Id 253482 -IncludeAppearances
```

**Adds**: Guest appearances on other artists' albums
**Use when**: Tracking all contributions, not just main artist releases

### Everything

```powershell
Get-DArtistAlbums -Id 253482 -MastersOnly:$false -IncludeSingles -IncludeCompilations -IncludeAppearances
```

**Returns**: Absolutely everything
**Warning**: Can be 1000+ releases for popular artists!
**Rate limit**: May hit 60 req/min limit during pagination

## What Are "Master Releases"?

Discogs uses a hierarchical structure:

```
Master Release: "The Beatles - Abbey Road"
├── Release: 1969 UK Apple Vinyl
├── Release: 1969 US Capitol Vinyl  
├── Release: 1987 UK CD
├── Release: 2009 Remastered CD
├── Release: 2019 50th Anniversary Edition
└── ... dozens more
```

**Master Release** = The conceptual album
**Release** = A specific physical/digital edition

For music library management, you almost always want **Master Releases** only!

## Usage in Invoke-MuFoManual

The default behavior is applied automatically:

```powershell
# Uses MastersOnly by default (recommended)
Invoke-MuFoManual "E:\fats waller" -Provider Discogs -WhatIf

# To get all releases (not recommended - slow!)
# (would need to modify Invoke-MuFoManual to expose this parameter)
```

## Performance Considerations

### With MastersOnly (Default)
- **Fats Waller**: 228 releases ÷ 100 per page = 3 pages = ~3 seconds
- **Rate limit safe**: 3 requests, well under 60/min limit

### Without MastersOnly
- **Fats Waller**: 589 releases ÷ 100 per page = 6 pages = ~6 seconds  
- **Popular artists**: Can be 1000+ releases = 10+ pages = 10+ requests
- **Risk**: May hit rate limit or timeout

## Recommendation

✅ **Always use default** (MastersOnly = true) unless you have a specific reason

This gives you:
- One entry per album (not dozens of pressings)
- Faster performance
- Cleaner matching with your local library
- No rate limit issues

## Examples by Use Case

### Music Library Management (Most Common)
```powershell
Get-DArtistAlbums -Id $artistId  # Default - perfect!
```

### Vinyl Collector Tracking Specific Pressings
```powershell
Get-DArtistAlbums -Id $artistId -MastersOnly:$false
```

### DJ with Singles Collection
```powershell
Get-DArtistAlbums -Id $artistId -IncludeSingles
```

### Completionist (All Contributions)
```powershell
Get-DArtistAlbums -Id $artistId -IncludeAppearances
```

## Summary

| Option | Fats Waller Count | Speed | Use Case |
|--------|------------------|-------|----------|
| **Default (MastersOnly)** | 228 | Fast | ✅ Music library |
| All Releases | 589 | Slower | Collectors |
| + Singles | 600+ | Slower | DJs |
| + Compilations | 650+ | Slow | Completionists |
| + Appearances | 700+ | Very Slow | Archivists |

**Bottom line**: The default (MastersOnly) is perfect for matching your local music library with Discogs metadata!
