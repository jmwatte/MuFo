# MuFo Track Tagging Documentation

## Overview
MuFo's track tagging system provides comprehensive metadata extraction with special support for classical music organization. This document explains how to use the track tagging features with practical examples.

## Basic Usage

### Reading Track Tags
```powershell
# Read tags from a single file
$tags = Get-AudioFileTags -Path "C:\Music\track.flac"

# Read tags from all audio files in a folder
$tags = Get-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina"

# Include classical music analysis
$tags = Get-AudioFileTags -Path "C:\Music\Classical" -IncludeComposer
```

### Supported Audio Formats
- MP3 (.mp3)
- FLAC (.flac) 
- M4A/AAC (.m4a)
- OGG Vorbis (.ogg)
- WAV (.wav)
- WMA (.wma)

## Classical Music Support

### Composer Detection
The system automatically detects composers using multiple methods:

1. **Direct Composer Tag**: Uses the standard COMPOSER tag
2. **Comment Field**: Extracts from "Composer: Name" in comments
3. **Known Artists**: Recognizes known composers like "Arvo Pärt"

```powershell
# Example output for classical music
$classicalTrack = Get-AudioFileTags -Path "Arvo_Part_Alina.flac" -IncludeComposer

# Results include:
# Composer: "Arvo Pärt"
# IsClassical: $true
# SuggestedAlbumArtist: "Arvo Pärt"
```

### Contributing Artist Analysis
The system categorizes artists by their role in classical music:

```powershell
# Example: Arvo Pärt - Alina performed by Vladimir Spivakov
$result = Get-AudioFileTags -Path $track -IncludeComposer

# ContributingArtists array contains:
# @(
#   @{ Type = "Conductor"; Name = "Vladimir Spivakov" }
#   @{ Type = "Orchestra"; Name = "Moscow Virtuosi" }
#   @{ Type = "Performer"; Name = "Soloist Name" }
# )
```

### Classical Music Detection
Tracks are identified as classical based on:

- Presence of composer information
- Genre tags containing "Classical"
- Album names with classical terms (symphony, concerto, sonata, etc.)
- Artist names containing orchestras, symphonies, ensembles

## Organization Strategies

### For Classical Music
The system suggests the **composer** as the primary album artist:

```
📁 Arvo Pärt/
   📁 1999 - Alina/
      🎵 01 - Gyorgy Kurtag - Flowers We Are.flac
      🎵 02 - Arvo Part - Alina.flac
```

### For Popular Music
Uses standard artist/album organization:

```
📁 Artist Name/
   📁 2023 - Album Title/
      🎵 01 - Track Name.flac
```

## Practical Examples

### Example 1: Analyzing a Classical Album
```powershell
# Analyze Arvo Pärt's "Alina" album
$tags = Get-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina" -IncludeComposer

# Display classical music information
$tags | Where-Object IsClassical | ForEach-Object {
    Write-Host "Track: $($_.Title)"
    Write-Host "  Composer: $($_.Composer)"
    Write-Host "  Suggested Organization: $($_.SuggestedAlbumArtist)/$($_.Album)"
    
    if ($_.ContributingArtists) {
        Write-Host "  Contributors:"
        $_.ContributingArtists | ForEach-Object {
            Write-Host "    $($_.Type): $($_.Name)"
        }
    }
}
```

### Example 2: Finding Tracks by Composer
```powershell
# Find all Arvo Pärt compositions in your library
$allTags = Get-AudioFileTags -Path "C:\Music" -IncludeComposer
$arvoPartTracks = $allTags | Where-Object { $_.Composer -like "*Arvo*" }

Write-Host "Found $($arvoPartTracks.Count) Arvo Pärt tracks across $($arvoPartTracks.Album | Sort-Object -Unique).Count albums"
```

### Example 3: Conductor Analysis
```powershell
# Find all recordings by a specific conductor
$allTags = Get-AudioFileTags -Path "C:\Music\Classical" -IncludeComposer
$spivakov = $allTags | Where-Object { $_.Conductor -like "*Spivakov*" }

$spivakov | Group-Object Album | ForEach-Object {
    Write-Host "Album: $($_.Name)"
    Write-Host "  Conductor: $($_.Group[0].Conductor)"
    Write-Host "  Composer(s): $($_.Group.Composer | Sort-Object -Unique | Join-String -Separator ', ')"
}
```

## Integration with MuFo

### Using with Invoke-MuFo
Track tagging integrates seamlessly with MuFo's main functionality:

```powershell
# Organize music with track tag awareness
Invoke-MuFo -Path "C:\Music\Unsorted" -Mode "Organize" -IncludeTrackTags

# This will:
# 1. Read track tags from audio files
# 2. Use composer information for classical music organization
# 3. Apply suggested album artists for better folder structure
```

### Logging and Debugging
```powershell
# Enable detailed logging for troubleshooting
$tags = Get-AudioFileTags -Path $folder -IncludeComposer -LogTo "tag-analysis.json"

# The log file contains detailed information about:
# - Tag extraction process
# - Classical music detection logic
# - Contributing artist analysis
# - Organization suggestions
```

## Performance Considerations

### Large Libraries
For large music libraries, consider processing in batches:

```powershell
# Process albums one at a time
$albums = Get-ChildItem "C:\Music" -Directory
foreach ($album in $albums) {
    $tags = Get-AudioFileTags -Path $album.FullName -IncludeComposer
    # Process tags for this album...
}
```

### TagLib-Sharp Installation
The track tagging feature requires TagLib-Sharp, which will be automatically detected and offered for installation:

```powershell
# When TagLib-Sharp is missing, MuFo will prompt:
# "TagLib-Sharp is required for track tag reading but is not installed."
# "Would you like to install TagLib-Sharp now? [Y/n]:"

# Manual installation options:
Install-Package TagLibSharp

# Or for current user only:
Install-Package TagLibSharp -Scope CurrentUser

# Alternative: Download and place TagLib-Sharp.dll in the MuFo module directory
```

**Automatic Installation**: MuFo will detect missing TagLib-Sharp and offer to install it automatically when running interactively. In non-interactive environments (CI, scripts), it will display installation instructions.

## Error Handling

### Common Issues and Solutions

1. **TagLib-Sharp Not Found**
   ```
   Warning: Failed to load TagLib-Sharp: Could not load file or assembly
   Solution: Install-Package TagLibSharp
   ```

2. **Unsupported File Format**
   ```
   Warning: Failed to read tags from 'file.xyz': Unsupported format
   Solution: Convert to supported format (MP3, FLAC, M4A, etc.)
   ```

3. **Corrupted Audio Files**
   ```
   Warning: Failed to read tags from 'track.mp3': File appears to be corrupted
   Solution: Re-encode the file or exclude from processing
   ```

## Best Practices

### For Classical Music Libraries
1. Ensure composer tags are properly set in your audio files
2. Use consistent naming for conductors and orchestras
3. Set appropriate genre tags ("Classical", "Chamber Music", etc.)

### For Mixed Libraries
1. Use the `-IncludeComposer` switch when processing folders that may contain classical music
2. Review suggested album artists before applying organization changes
3. Keep original folder structure backed up before reorganization

### Performance Optimization
1. Process specific albums rather than entire libraries when possible
2. Use logging to track processing progress on large collections
3. Consider excluding very large files that may cause memory issues

## Advanced Usage

### Custom Classical Music Detection
You can extend the classical music detection by checking the results:

```powershell
$tags = Get-AudioFileTags -Path $folder -IncludeComposer

# Add custom logic for edge cases
$tags | ForEach-Object {
    if ($_.Album -match "Bach|Mozart|Beethoven" -and -not $_.IsClassical) {
        # Force classical classification
        $_.IsClassical = $true
        $_.SuggestedAlbumArtist = $_.Composer ?? $_.Artist
    }
}
```

### Integration with Other Tools
Track tag information can be exported for use with other music management tools:

```powershell
# Export to CSV for analysis
$tags | Export-Csv -Path "music-library-analysis.csv" -NoTypeInformation

# Export classical music statistics
$classical = $tags | Where-Object IsClassical
$classical | Group-Object Composer | Sort-Object Count -Descending | 
    Select-Object @{N='Composer';E={$_.Name}}, @{N='Tracks';E={$_.Count}} |
    Export-Csv -Path "composers-by-track-count.csv"
```

This documentation provides comprehensive guidance for using MuFo's track tagging capabilities effectively with both popular and classical music libraries.