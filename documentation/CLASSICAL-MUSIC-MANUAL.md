# MuFo Classical Music User's Manual

## 🎼 Overview

MuFo includes comprehensive support for classical music, handling the complex metadata relationships and organizational patterns unique to classical recordings. This manual covers all classical music features and best practices.

## 🎻 Classical Music Detection

MuFo automatically identifies classical music tracks using multiple criteria:

### Detection Triggers
- **Genre tags**: Contains "Classical" or "classical"
- **Album titles**: Keywords like "symphony", "concerto", "sonata", "requiem", "mass", "oratorio", "opera", "suite", "quartet", "trio", "duo", "solo", "recital"
- **Artist names**: Classical terminology like "orchestra", "philharmonic", "chamber", "symphony"

### Analysis Output
When processing classical albums, MuFo provides:
- `IsClassical`: Boolean indicating classical detection
- `PrimaryComposer`: Most frequent composer across tracks
- `PrimaryConductor`: Most frequent conductor across tracks
- `ClassicalTracks`: Count of classical-identified tracks
- `SuggestedClassicalArtist`: Recommended album artist

## 🎼 Composer & Artist Handling

### Composer Detection
MuFo extracts composer information from:
- **TagLib Composer field**: Primary source
- **Comment field**: Pattern `Composer: Name`
- **Filename patterns**: Intelligent parsing
- **Artist field fallbacks**: When explicitly marked

### Classical Artist Hierarchy
Classical music has a unique artist hierarchy that MuFo respects:

```
Composer (Album Artist) → Primary creative force
Conductor (Track Artist) → Performance interpretation
Orchestra/Ensemble (Track Artist) → Performing group
Soloists (Track Artist) → Individual performers
```

### Tag Optimization (`-OptimizeClassicalTags`)

When enabled, MuFo automatically:
- Sets composer as album artist when missing
- Preserves conductor/performer information in track artists
- Adds conductor info to comment fields
- Maintains proper classical music metadata hierarchy

## 🔄 Classical Music Workflows

### Basic Classical Album Processing
```powershell
# Standard classical album analysis
Invoke-MuFo -Path "C:\Music\Classical\Beethoven" -IncludeTracks -WhatIf

# With classical tag optimization
Invoke-MuFo -Path "C:\Music\Classical" -IncludeTracks -FixTags -OptimizeClassicalTags -WhatIf
```

### Safe Classical Tag Enhancement
```powershell
# Preserve existing track artists (conductors/performers)
Invoke-MuFo -Path "C:\Classical" -FixTags -DontFix "TrackArtists" -OptimizeClassicalTags

# Full classical optimization
Invoke-MuFo -Path "C:\Classical" -FixTags -OptimizeClassicalTags
```

### Classical Album Matching
```powershell
# Include compilations (many classical releases are "Various Artists")
Invoke-MuFo -Path "C:\Classical" -IncludeCompilations -IncludeTracks -WhatIf

# With duration validation for track ordering
Invoke-MuFo -Path "C:\Classical" -IncludeTracks -ValidateDurations -DurationValidationLevel DataDriven
```

## 🎵 Track Numbering & Organization

### Classical Track Numbering Challenges
Classical music often uses:
- **Multi-movement works**: Single "work" spans multiple tracks
- **"00 - Title" naming**: Movement titles instead of sequential numbers
- **Complex numbering**: Disc 1/Track 1, Disc 2/Track 1, etc.

### Intelligent Track Numbering
MuFo provides special handling for classical track numbering:

1. **Spotify matching**: Matches by title similarity
2. **Duration-based fallback**: Uses track lengths for correct sequencing
3. **Data-driven tolerances**: Different accuracy levels for track lengths:
   - **Short tracks** (0-2 min): ±42 seconds tolerance
   - **Normal tracks** (2-7 min): ±107 seconds tolerance
   - **Long tracks** (7-10 min): ±89 seconds tolerance
   - **Epic tracks** (10+ min): ±331 seconds tolerance

### Box Set Handling (`-BoxMode`)
For multi-disc classical works:
```powershell
Invoke-MuFo -Path "C:\Classical\Beethoven\Complete\BoxSet" -BoxMode -IncludeTracks -WhatIf
```

## 🏗️ Classical Music Folder Structures

MuFo handles these common classical organization patterns:

### Composer-Centric
```
Beethoven/
├── Piano Sonatas/
├── Symphonies/
└── String Quartets/
```

### Performer-Centric
```
Karajan/
├── Beethoven - Symphony No. 5
├── Mozart - Requiem
└── Brahms - German Requiem
```

### Work-Centric
```
Symphony No. 5 (Beethoven)/
Piano Concerto No. 1 (Tchaikovsky)/
```

## 🔧 Troubleshooting Classical Music

### Common Issues & Solutions

#### "No matches found on Spotify"
**Problem**: Classical albums often appear as "Various Artists" compilations
**Solution**: Use `-IncludeCompilations`
```powershell
Invoke-MuFo -Path "C:\Classical" -IncludeCompilations -WhatIf
```

#### Wrong Artist Matches
**Problem**: MuFo matches to performers instead of composers
**Solution**: Use manual artist selection or check confidence scores
```powershell
# Check available matches first
Invoke-MuFo -Path "C:\Classical\Beethoven" -WhatIf

# Use manual selection if needed
Invoke-ManualTrackMapping -Path "C:\Classical\Beethoven"
```

#### Missing Composer Information
**Problem**: Classical tracks lack composer metadata
**Solution**: Use `-OptimizeClassicalTags` to extract from comments/filenames
```powershell
Invoke-MuFo -Path "C:\Classical" -FixTags -OptimizeClassicalTags
```

#### Track Ordering Issues
**Problem**: Classical albums with "00 - Movement" naming get wrong track numbers
**Solution**: Use duration-based matching
```powershell
Invoke-MuFo -Path "C:\Classical" -IncludeTracks -ValidateDurations -DurationValidationLevel DataDriven
```

#### Conductor Information Lost
**Problem**: Tag optimization overwrites conductor information
**Solution**: Exclude track artists from fixing
```powershell
Invoke-MuFo -Path "C:\Classical" -FixTags -DontFix "TrackArtists" -OptimizeClassicalTags
```

## 📋 Best Practices for Classical Music

### 1. Always Use Compilation Mode
```powershell
# Essential for classical music
Invoke-MuFo -Path "C:\Classical" -IncludeCompilations
```

### 2. Enable Classical Optimization
```powershell
# For proper composer/performer separation
Invoke-MuFo -Path "C:\Classical" -OptimizeClassicalTags
```

### 3. Preserve Performer Information
```powershell
# Keep conductors and soloists in track artists
Invoke-MuFo -Path "C:\Classical" -DontFix "TrackArtists"
```

### 4. Use Duration Validation
```powershell
# For correct track sequencing in complex works
Invoke-MuFo -Path "C:\Classical" -ValidateDurations -DurationValidationLevel DataDriven
```

### 5. Check Analysis Output
Review these fields in the analysis:
- `PrimaryComposer`: Should match expected composer
- `PrimaryConductor`: Important for performance identification
- `ClassicalTracks`: Should match total tracks for pure classical albums

## 🎼 Advanced Classical Features

### Duration-Based Track Matching
MuFo uses empirical data from 149 classical tracks to set appropriate tolerances:
- **Short movements**: Tighter tolerances (±42s)
- **Standard movements**: Normal tolerances (±107s)
- **Long movements**: Relaxed tolerances (±89s)
- **Epic works**: Very relaxed tolerances (±331s)

### Classical Genre Enhancement
Automatically adds "Classical" genre when:
- Composer detected
- Classical terminology in titles
- Orchestra/ensemble artists identified

### Multi-Artist Classical Works
Properly handles complex classical metadata:
- **Composer**: Album artist (primary creative force)
- **Conductor**: Track artist (performance interpretation)
- **Orchestra**: Track artist (performing ensemble)
- **Soloists**: Track artist (featured performers)

## 📖 Classical Music Resources

### Recommended Folder Structures
- **By Composer**: `Composer/Work/Recording`
- **By Performer**: `Conductor/Composer - Work`
- **By Era**: `Baroque/Composer/Work`

### Tag Standards for Classical
- **Album Artist**: Composer name
- **Track Artist**: Conductor/Performer information
- **Genre**: "Classical"
- **Composer**: Explicitly tagged
- **Comment**: Additional performance notes

### Performance Tips
- Process classical collections in batches by composer
- Use `-WhatIf` first to review changes
- Check `PrimaryComposer` in analysis output
- Use `-DontFix "TrackArtists"` to preserve conductor info
- Enable `-ValidateDurations` for track ordering verification

---

*This manual covers MuFo's comprehensive classical music support. For general MuFo usage, see the main README.md.*</content>
<parameter name="filePath">c:\Users\resto\Documents\PowerShell\Modules\MuFo\documentation\CLASSICAL-MUSIC-MANUAL.md