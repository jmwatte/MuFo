# Manual Track Mapping Workflow Documentation

## Overview

The Manual Track Mapping workflow is designed for edge cases where automatic Spotify matching fails or when you need forensic-level control over track ordering. This two-step process allows you to manually verify and correct track sequences by listening to the actual audio.

## When to Use Manual Workflow

Use the manual workflow when:
- Track numbers in tags don't match actual audio order
- Filename order doesn't correspond to album sequence  
- Automatic Spotify matching can't determine correct order
- You need to manually verify track order by listening
- Complex albums with non-standard track arrangements
- Classical music with movement-based track organization
- Live albums or bootlegs with uncertain track sequences

## Complete Workflow Guide

### Step 1: Generate Mapping Files

```powershell
# Navigate to the problem album folder
cd "C:\Music\Artist\Problem Album"

# Generate playlist and mapping files
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "album-fix"
```

**This creates two files:**
- `album-fix.m3u` - Playlist file for your media player
- `album-fix.txt` - Editable text file for track reordering

### Step 2: Listen and Edit

1. **Play the playlist**: Open `album-fix.m3u` in your media player (VLC, Windows Media Player, etc.)
2. **Note the actual order**: Listen to each track and note what you actually hear
3. **Edit the mapping file**: Open `album-fix.txt` in any text editor (Notepad, VS Code, vim, etc.)

**Example mapping file:**
```
# MuFo Track Mapping File
# Instructions:
#   1. Play the album-fix.m3u file in your media player
#   2. Edit this file to match the order you hear
#   3. Move lines up/down to match actual track order
#   4. Edit track numbers and titles as needed
#   5. Save and use: Import-TrackMapping -MappingFile 'album-fix.txt'

1. Opening Track
2. Second Song  
3. Third Track
4. Final Song
```

**To reorder**: Simply move the lines around to match what you hear:
```
1. Third Track    # This was originally track 3, now it's first
2. Opening Track  # This was originally track 1, now it's second  
3. Final Song     # This was originally track 4, now it's third
4. Second Song    # This was originally track 2, now it's fourth
```

### Step 3: Preview Changes

```powershell
# Preview what will be changed (safe - no modifications)
Invoke-ManualTrackMapping -Action Import -MappingFile "album-fix.txt" -WhatIf
```

**Example preview output:**
```
📁 01-Opening Track.mp3
   🔢 Track: 1 → 2
   🏷️  Title: 'Opening Track' → 'Opening Track'
   📝 Rename: 02 - Opening Track.mp3

📁 02-Second Song.mp3  
   🔢 Track: 2 → 4
   🏷️  Title: 'Second Song' → 'Second Song'
   📝 Rename: 04 - Second Song.mp3
```

### Step 4: Apply Changes

```powershell
# Apply changes with file renaming
Invoke-ManualTrackMapping -Action Import -MappingFile "album-fix.txt" -RenameFiles

# Or apply changes without renaming files (tags only)
Invoke-ManualTrackMapping -Action Import -MappingFile "album-fix.txt"
```

**Safety features:**
- ✅ **Automatic backups** created before any changes
- ✅ **Confirmation prompt** before applying changes
- ✅ **WhatIf preview** to see changes before applying
- ✅ **Graceful error handling** for file permission issues

## Command Reference

### Invoke-ManualTrackMapping

**Generate mapping files:**
```powershell
Invoke-ManualTrackMapping -Path <folder> -Action Generate -OutputName <name> [-SortBy <method>]
```

**Import edited mappings:**
```powershell
Invoke-ManualTrackMapping -Action Import -MappingFile <file> [-RenameFiles] [-WhatIf]
```

**Parameters:**
- `Path` - Folder containing audio files (Generate only)
- `Action` - Either "Generate" or "Import"
- `OutputName` - Base name for generated files (Generate only)
- `MappingFile` - Path to edited mapping file (Import only)
- `RenameFiles` - Also rename files to match new order (Import only)
- `SortBy` - Initial sort method: FileName, TrackNumber, Title (Generate only)
- `WhatIf` - Preview changes without applying (Import only)

## Advanced Usage

### Different Initial Sorting

```powershell
# Sort by existing track numbers in tags
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "fix" -SortBy TrackNumber

# Sort alphabetically by title
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "fix" -SortBy Title

# Sort by filename (default)
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "fix" -SortBy FileName
```

### Tags Only (No File Renaming)

```powershell
# Update track numbers and titles but keep original filenames
Invoke-ManualTrackMapping -Action Import -MappingFile "mapping.txt"
```

### Complete Example Workflow

```powershell
# Complete example: Fix a classical album with wrong track order
cd "C:\Music\Classical\Beethoven\Symphony No. 9"

# Step 1: Generate files sorted by current track numbers
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "beethoven-fix" -SortBy TrackNumber

# Step 2: Play beethoven-fix.m3u and listen to actual order
# Step 3: Edit beethoven-fix.txt to match what you hear:
#   1. I. Allegro ma non troppo
#   2. II. Molto vivace  
#   3. III. Adagio molto e cantabile
#   4. IV. Finale: Presto - Ode to Joy

# Step 4: Preview changes
Invoke-ManualTrackMapping -Action Import -MappingFile "beethoven-fix.txt" -WhatIf

# Step 5: Apply with file renaming for clean organization
Invoke-ManualTrackMapping -Action Import -MappingFile "beethoven-fix.txt" -RenameFiles
```

## File Naming Conventions

When using `-RenameFiles`, files are renamed to:
```
01 - First Track.mp3
02 - Second Track.mp3  
03 - Third Track.mp3
04 - Fourth Track.mp3
```

Original files are backed up as:
```
01-original-name.mp3.backup
02-original-name.mp3.backup
```

## Troubleshooting

### Common Issues

**"Audio path not found"**
- Ensure you're in the correct directory or specify full paths
- Check that the mapping file is in the same folder as audio files

**"No valid track mappings found"**
- Ensure mapping file has the correct format: `1. Title`, `2. Title`, etc.
- Check that lines aren't commented out accidentally

**"Mismatch: X audio files but Y mappings"**
- Verify all audio files are accounted for in mapping file
- Check for hidden files or additional audio files

**"TagLib not available"**
- File renaming will work, but tag updates require TagLib-Sharp
- Use `Install-TagLibSharp` to install the dependency

### Recovery

**If something goes wrong:**
1. Check for `.backup` files in the album folder
2. Restore originals: `Get-ChildItem *.backup | ForEach-Object { Move-Item $_ ($_.Name -replace '\.backup$','') }`
3. Start over with a fresh mapping file

## Integration with Main MuFo Workflow

The manual workflow complements the main MuFo validation:

```powershell
# Standard MuFo validation
Invoke-MuFo -ArtistAt "C:\Music" -DoIt Smart

# For albums that need manual intervention
cd "C:\Music\Artist\Problem Album"  
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "manual-fix"
# Edit manual-fix.txt as needed
Invoke-ManualTrackMapping -Action Import -MappingFile "manual-fix.txt" -RenameFiles

# Re-run MuFo to validate the fixes
Invoke-MuFo -ArtistAt "C:\Music\Artist\Problem Album" -DoIt Auto
```

## Performance Notes

- **Fast execution**: Mapping generation typically completes in <50ms for most albums
- **Memory efficient**: Minimal memory usage even for large albums
- **Background friendly**: Won't interfere with music playback during editing
- **Cross-platform**: Works on Windows, Mac, and Linux PowerShell

## File Format Specifications

### Playlist Format (.m3u)
```
#EXTM3U
#EXTINF:-1,Track Title
C:\Full\Path\To\Track.mp3
#EXTINF:-1,Another Track
C:\Full\Path\To\Another.mp3
```

### Mapping Format (.txt)
```
# Comments start with #
# Blank lines are ignored
1. First Track Title
2. Second Track Title  
3. Third Track Title
```

**Rules:**
- Each track line must start with `<number>.` 
- Track numbers should be sequential (1, 2, 3, etc.)
- Titles can contain any characters except line breaks
- Order of lines determines final track sequence

## Security Considerations

- ✅ **Backup creation**: Original files always preserved
- ✅ **Confirmation prompts**: No silent destructive operations  
- ✅ **Path validation**: Prevents accidental operations outside target folder
- ✅ **Error handling**: Graceful failure with informative messages
- ✅ **Permission checks**: Validates write access before attempting changes

The manual workflow provides the ultimate safety net for complex or edge-case albums that require human verification and intervention.