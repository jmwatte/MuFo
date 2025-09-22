# MuFo Complete Parameter Reference

## Overview
This document provides comprehensive documentation for all MuFo parameters with practical examples, classical music use cases, and performance optimization guidance.

## Invoke-MuFo Parameters

### Core Parameters

#### `-Path` (string)
**Purpose**: Specifies the root directory to scan for music library validation.
**Default**: Current directory (`.`)
**Required**: No

```powershell
# Scan current directory
Invoke-MuFo

# Scan specific path
Invoke-MuFo -Path "C:\Music"

# Scan classical music collection
Invoke-MuFo -Path "D:\Classical\Composers"
```

**Performance Tip**: Use specific paths rather than scanning entire drives to improve performance.

#### `-DoIt` (string)
**Purpose**: Controls how changes are applied.
**Values**: `Automatic`, `Manual`, `Smart`
**Default**: Prompts for user decision

```powershell
# Manual confirmation for each change
Invoke-MuFo -Path "C:\Music" -DoIt Manual

# Smart mode - apply confident matches automatically
Invoke-MuFo -Path "C:\Music" -DoIt Smart

# Automatic mode - apply all suggestions (use with caution)
Invoke-MuFo -Path "C:\Music" -DoIt Automatic
```

**Classical Music Recommendation**: Use `Smart` mode for classical libraries as composer names are usually more consistent.

### Matching & Validation Parameters

#### `-ConfidenceThreshold` (double)
**Purpose**: Minimum similarity score [0..1] to consider a match "confident".
**Default**: 0.9
**Used by**: Smart mode and album colorization

```powershell
# High confidence (fewer false positives)
Invoke-MuFo -Path "C:\Music" -ConfidenceThreshold 0.95

# Lower confidence (more matches, some may be incorrect)
Invoke-MuFo -Path "C:\Music" -ConfidenceThreshold 0.7

# Classical music optimization (recommended)
Invoke-MuFo -Path "C:\Classical" -ConfidenceThreshold 0.8
```

**Performance Impact**: Lower thresholds trigger more Spotify API calls but find more matches.

#### `-ArtistAt` (string)
**Purpose**: Specifies where to find the artist folder in the directory structure.
**Values**: `Here`, `1U`, `2U`, `1D`, `2D`
**Default**: `Here`

```powershell
# Artist folder is the current path
Invoke-MuFo -Path "C:\Music\Arvo Pärt" -ArtistAt Here

# Artist folders are one level up from current path
Invoke-MuFo -Path "C:\Music\Arvo Pärt\1999 - Alina" -ArtistAt 1U

# Artist folders are one level down from current path
Invoke-MuFo -Path "C:\Music" -ArtistAt 1D

# Complex classical library structure
Invoke-MuFo -Path "C:\Classical\Composers\Baroque" -ArtistAt 2D
```

**Classical Music Example**:
```
C:\Classical\
├── Composers\          ← Run with -ArtistAt 1D
│   ├── Arvo Pärt\
│   └── Bach\
└── Periods\
```

### Filtering & Exclusion Parameters

#### `-ExcludeFolders` (string[])
**Purpose**: Folders to exclude from scanning. Supports wildcards.
**Default**: None

```powershell
# Exclude specific folders
Invoke-MuFo -Path "C:\Music" -ExcludeFolders "Bonus", "Live"

# Exclude with wildcards
Invoke-MuFo -Path "C:\Music" -ExcludeFolders "E_*", "*_Live", "Album?"

# Classical music exclusions
Invoke-MuFo -Path "C:\Classical" -ExcludeFolders "Bonus*", "*Demo*", "Work_*"
```

**Classical Music Patterns**:
- `"*_Draft"` - Exclude draft recordings
- `"Rehearsal*"` - Exclude rehearsal recordings  
- `"*_Alternative"` - Exclude alternative versions

### Output & Logging Parameters

#### `-LogTo` (string)
**Purpose**: Path to log file for detailed results and debugging.
**Default**: No logging

```powershell
# Basic logging
Invoke-MuFo -Path "C:\Music" -LogTo "mufo-results.log"

# JSON logging for analysis
Invoke-MuFo -Path "C:\Classical" -LogTo "classical-analysis.json"

# Timestamped logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Invoke-MuFo -Path "C:\Music" -LogTo "mufo-$timestamp.log"
```

**Performance Monitoring**: Use logging to track API usage and optimization opportunities.

### Content Type Parameters

#### `-IncludeSingles` (switch)
**Purpose**: Include single releases when fetching albums from Spotify.
**Default**: Excluded

```powershell
# Include singles in matching
Invoke-MuFo -Path "C:\Music" -IncludeSingles

# Classical music with standalone pieces
Invoke-MuFo -Path "C:\Classical\Singles" -IncludeSingles
```

**Classical Music Note**: Many classical recordings are released as singles (individual movements, études).

#### `-IncludeCompilations` (switch)
**Purpose**: Include compilation releases when fetching albums.
**Default**: Excluded

```powershell
# Include compilations
Invoke-MuFo -Path "C:\Music" -IncludeCompilations

# Classical music collections and "best of" albums
Invoke-MuFo -Path "C:\Classical" -IncludeCompilations
```

**Classical Music Use Case**: Essential for "Greatest Hits" or "Complete Works" collections.

### Advanced Analysis Parameters

#### `-IncludeTracks` (switch)
**Purpose**: Enable track tag inspection and classical music analysis.
**Default**: Disabled

```powershell
# Enable track tagging analysis
Invoke-MuFo -Path "C:\Music" -IncludeTracks

# Classical music with composer detection
Invoke-MuFo -Path "C:\Classical" -IncludeTracks -LogTo "classical-tags.json"
```

**Classical Music Features Enabled**:
- Composer detection and extraction
- Conductor identification
- Contributing artist categorization (orchestra, soloist, etc.)
- Organization suggestions (composer-first vs. artist-first)
- Classical music classification

**Performance Impact**: Requires TagLib-Sharp and reads all audio file metadata.

#### `-BoxMode` (switch)
**Purpose**: Treat subfolders as discs of a box set.
**Default**: Disabled

```powershell
# Multi-disc classical box sets
Invoke-MuFo -Path "C:\Classical\Bach Complete Works" -BoxMode

# Opera with multiple acts
Invoke-MuFo -Path "C:\Classical\Wagner\Ring Cycle" -BoxMode -IncludeTracks
```

**Classical Music Example**:
```
Bach Complete Works\
├── Disc 1 - Preludes\
├── Disc 2 - Fugues\
└── Disc 3 - Inventions\
```

### Preview & Analysis Parameters

#### `-Preview` (switch)
**Purpose**: Perform analysis only without prompting or renaming.
**Default**: Interactive mode

```powershell
# Analysis only (no changes)
Invoke-MuFo -Path "C:\Music" -Preview

# Classical music analysis with track tagging
Invoke-MuFo -Path "C:\Classical" -Preview -IncludeTracks

# Performance analysis
Invoke-MuFo -Path "C:\LargeLibrary" -Preview -LogTo "performance.json"
```

**Use Cases**:
- Testing configuration before making changes
- Generating reports for library analysis
- Performance benchmarking

#### `-Detailed` (switch)
**Purpose**: Enable verbose output with detailed matching information.
**Default**: Concise output

```powershell
# Detailed matching information
Invoke-MuFo -Path "C:\Music" -Detailed

# Classical music detailed analysis
Invoke-MuFo -Path "C:\Classical" -Detailed -IncludeTracks
```

## Classical Music Optimization Guide

### Recommended Parameter Combinations

#### Basic Classical Music Scan
```powershell
Invoke-MuFo -Path "C:\Classical" -ConfidenceThreshold 0.8 -IncludeTracks
```

#### Classical Music Box Sets
```powershell
Invoke-MuFo -Path "C:\Classical\Box Sets" -BoxMode -IncludeTracks -IncludeCompilations
```

#### Classical Music Organization Analysis
```powershell
Invoke-MuFo -Path "C:\Classical" -Preview -IncludeTracks -Detailed -LogTo "classical-org.json"
```

#### Large Classical Library Processing
```powershell
Invoke-MuFo -Path "C:\Classical" -DoIt Smart -ConfidenceThreshold 0.85 -IncludeTracks -ExcludeFolders "*Demo*", "*Draft*" -LogTo "classical-batch.log"
```

### Classical Music Workflow

1. **Analysis Phase**:
   ```powershell
   Invoke-MuFo -Path "C:\Classical" -Preview -IncludeTracks -Detailed
   ```

2. **Validation Phase**:
   ```powershell
   Invoke-MuFo -Path "C:\Classical" -DoIt Smart -ConfidenceThreshold 0.9
   ```

3. **Organization Phase**:
   ```powershell
   # Use track tagging suggestions for composer-first organization
   ```

## Performance Optimization

### Memory and Speed Optimization

#### Large Libraries (>10,000 albums)
```powershell
# Process in batches
Get-ChildItem "C:\Music" -Directory | ForEach-Object {
    Invoke-MuFo -Path $_.FullName -DoIt Smart -LogTo "batch-$($_.Name).log"
}
```

#### API Rate Limiting
```powershell
# Lower confidence threshold reduces API calls
Invoke-MuFo -Path "C:\Music" -ConfidenceThreshold 0.7

# Preview mode for planning (no API calls for changes)
Invoke-MuFo -Path "C:\Music" -Preview
```

#### Network Optimization
```powershell
# Exclude problematic folders to reduce API calls
Invoke-MuFo -Path "C:\Music" -ExcludeFolders "*Temp*", "*Download*", "*New*"
```

## Error Handling and Troubleshooting

### Common Issues and Solutions

#### TagLib-Sharp Missing
```powershell
# Automatic installation prompt will appear
Invoke-MuFo -Path "C:\Music" -IncludeTracks

# Manual installation
Install-TagLibSharp
```

#### Spotify API Limits
```powershell
# Use higher confidence threshold
Invoke-MuFo -Path "C:\Music" -ConfidenceThreshold 0.95

# Process smaller batches
```

#### Memory Issues with Large Libraries
```powershell
# Exclude unnecessary folders
Invoke-MuFo -Path "C:\Music" -ExcludeFolders "*Backup*", "*Old*"

# Use Preview mode for analysis
Invoke-MuFo -Path "C:\Music" -Preview
```

## Best Practices

### For Classical Music Libraries
1. **Use track tagging**: Always include `-IncludeTracks` for composer detection
2. **Lower confidence threshold**: Use 0.8-0.85 for classical music
3. **Include compilations**: Many classical releases are compilations
4. **Use BoxMode**: For multi-disc sets and complete works
5. **Exclude rehearsals**: Use `-ExcludeFolders` for demo/rehearsal content

### For Large Libraries
1. **Process in batches**: Don't scan entire libraries at once
2. **Use Preview mode**: Analyze before making changes
3. **Enable logging**: Track progress and performance
4. **Exclude temporary folders**: Reduce unnecessary processing

### For Mixed Libraries
1. **Separate classical and popular**: Process different genres separately
2. **Use appropriate confidence levels**: Higher for popular, lower for classical
3. **Customize exclusions**: Different patterns for different genres

## Integration Examples

### With Other Tools
```powershell
# Generate library report
$results = Invoke-MuFo -Path "C:\Music" -Preview -IncludeTracks
$results | Export-Csv -Path "library-analysis.csv"

# Classical music composer analysis
$classical = Invoke-MuFo -Path "C:\Classical" -Preview -IncludeTracks
$classical | Where-Object { $_.ClassicalTracks -gt 0 } | 
    Group-Object PrimaryComposer | 
    Sort-Object Count -Descending
```

### Automation Scripts
```powershell
# Weekly library maintenance
$timestamp = Get-Date -Format "yyyyMMdd"
Invoke-MuFo -Path "C:\Music\New" -DoIt Smart -LogTo "weekly-$timestamp.log"

# Classical music organization
Invoke-MuFo -Path "C:\Classical" -Preview -IncludeTracks | 
    Where-Object { $_.SuggestedClassicalArtist } |
    ForEach-Object { 
        Write-Host "Suggest: $($_.LocalFolder) → $($_.SuggestedClassicalArtist)"
    }
```

This comprehensive parameter reference ensures users can effectively utilize all MuFo features for their specific music library needs, with special attention to classical music requirements and performance optimization.