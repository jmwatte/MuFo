# Manual Track Mapping - Quick Reference

## TL;DR Workflow

```powershell
# 1. Generate files
Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "fix"

# 2. Play fix.m3u and edit fix.txt to match what you hear

# 3. Preview changes  
Invoke-ManualTrackMapping -Action Import -MappingFile "fix.txt" -WhatIf

# 4. Apply changes
Invoke-ManualTrackMapping -Action Import -MappingFile "fix.txt" -RenameFiles
```

## Quick Commands

| Task | Command |
|------|---------|
| **Generate mapping** | `Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "fix"` |
| **Preview changes** | `Invoke-ManualTrackMapping -Action Import -MappingFile "fix.txt" -WhatIf` |
| **Apply with renaming** | `Invoke-ManualTrackMapping -Action Import -MappingFile "fix.txt" -RenameFiles` |
| **Tags only** | `Invoke-ManualTrackMapping -Action Import -MappingFile "fix.txt"` |

## File Formats

**Mapping file example:**
```
1. First Track    # This will be track 1
2. Second Track   # This will be track 2  
3. Third Track    # This will be track 3
```

**To reorder**: Just move the lines around to match what you hear!

## Common Use Cases

- 🎵 **Wrong track order**: Files named correctly but audio is in different order
- 🏷️ **Bad filename order**: Audio is correct but filenames are wrong  
- 🎼 **Classical albums**: Complex movement structures need manual verification
- 🎤 **Live recordings**: Bootlegs or concerts with uncertain track sequences
- 🔧 **Spotify failed**: When automatic matching can't determine correct order

## Safety Features

- ✅ **Automatic backups** (`.backup` files)
- ✅ **Preview with -WhatIf** before applying
- ✅ **Confirmation prompts** 
- ✅ **Error handling** for permissions/missing files

## Recovery

If something goes wrong:
```powershell
# Restore from backups
Get-ChildItem *.backup | ForEach-Object { 
    Move-Item $_ ($_.Name -replace '\.backup$','') 
}
```