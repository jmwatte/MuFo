# MuFo Scripts Folder

This folder contains example scripts and templates to help users learn how to build custom workflows using MuFo's core functionality.

## 📚 Purpose

The Scripts folder serves as a **teaching resource** for users who want to:
- Learn how to use MuFo core functions in custom workflows
- Build their own specialized music library management tools
- Understand PowerShell patterns for interactive music processing
- See examples of real-world MuFo usage scenarios

## 📁 Structure

```
/Scripts/
├── examples/           # Learning examples and demonstrations
│   ├── simple-artist-validation.ps1    # Basic artist analysis workflow
│   └── ...
├── templates/          # Templates for creating custom workflows
└── README.md          # This file
```

## 🎯 Examples Available

### `examples/simple-artist-validation.ps1`
**What it teaches:**
- Basic artist analysis using `Invoke-MuFo -Preview`
- Result categorization by confidence scores
- Interactive selection with `Out-GridView -PassThru`
- Processing selected items with `Invoke-MuFo -DoIt Automatic`

**Key patterns:**
```powershell
# Analysis pattern
$analysis = Invoke-MuFo -Path $artistPath -Preview -ArtistAt Here

# Result building pattern
$results += [PSCustomObject]@{
    LocalName = $artist.Name
    SpotifyMatch = $analysis.SelectedArtist.Name
    Confidence = $analysis.SelectedArtist.ConfidenceScore
    # ... other properties
}

# Interactive selection pattern
$selected = $results | Out-GridView -PassThru -Title "Select items to process"

# Processing pattern
foreach ($item in $selected) {
    Invoke-MuFo -Path $item.Path -DoIt Automatic
}
```

## 🚀 How to Use These Scripts

1. **Learn the patterns**: Study the example scripts to understand common MuFo workflows
2. **Modify and experiment**: Copy scripts and adapt them to your specific needs
3. **Build custom tools**: Use the patterns to create your own specialized workflows
4. **Share with community**: Contribute your own examples back to the MuFo project

## 💡 Common Patterns

### Analysis and Preview
```powershell
# Always use -Preview for analysis without changes
$result = Invoke-MuFo -Path $path -Preview -ArtistAt Here
```

### Interactive Selection
```powershell
# Use Out-GridView for user-friendly selection
$selected = $data | Out-GridView -PassThru -Title "Your Title"
```

### Safe Processing
```powershell
# Use -WhatIf for preview, then -DoIt for actual processing
Invoke-MuFo -Path $path -WhatIf  # Preview first
Invoke-MuFo -Path $path -DoIt Automatic  # Then process
```

### Error Handling
```powershell
try {
    $result = Invoke-MuFo -Path $path -Preview
    # Process result
} catch {
    Write-Warning "Analysis failed for $path: $($_.Exception.Message)"
    # Handle error appropriately
}
```

## 🔧 Building Your Own Workflows

### Step 1: Start with an Example
Copy one of the example scripts and modify it for your needs.

### Step 2: Identify Your Goal
- Artist validation?
- Album analysis?
- Track-level processing?
- Library health assessment?

### Step 3: Use MuFo Core Functions
- `Invoke-MuFo`: Main processing engine
- `Get-TrackTags`: Individual track analysis  
- `Set-TrackTags`: Direct tag modification
- `Compare-TrackDurations`: Duration validation

### Step 4: Add User Interface
- `Out-GridView`: Interactive selection
- `Write-Host`: Colored output
- `Write-Progress`: Progress bars
- `Read-Host`: User input

### Step 5: Handle Results
- Export to files (JSON, CSV, TXT)
- Generate reports
- Log processing results
- Provide next steps guidance

## 🎵 Integration with Core MuFo

These scripts work alongside the main MuFo functions:

- **`Invoke-MuFo`**: Core music library processing
- **`Get-MuFoArtistReport`**: Interactive artist validation workflow
- **`Invoke-ManualTrackMapping`**: Manual track order correction
- **Your custom scripts**: Specialized workflows for specific needs

## 📖 Learning Resources

1. **Start here**: `examples/simple-artist-validation.ps1`
2. **Read the main docs**: `../documentation/`
3. **Study the core functions**: `../Public/` and `../Private/`
4. **Experiment safely**: Always use `-Preview` and `-WhatIf` first

## 🤝 Contributing

If you create useful workflow scripts, consider contributing them back:
1. Add them to `examples/` with clear documentation
2. Include learning comments explaining the patterns
3. Test them with various music library structures
4. Submit a pull request to share with the community

Happy scripting! 🎵