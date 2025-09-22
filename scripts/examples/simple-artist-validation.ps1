#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple artist validation example - demonstrates basic MuFo workflow patterns.

.DESCRIPTION
    This script shows how to build custom workflows using MuFo core functions.
    It's a simplified version of Get-MuFoArtistReport for learning purposes.

.NOTES
    Author: jmw
    Purpose: Teaching example for MuFo Scripts folder
    Shows: Basic analysis, categorization, and Out-GridView usage
#>

param(
    [string]$LibraryPath = "C:\Music"
)

Write-Host "📚 LEARNING EXAMPLE: Simple Artist Validation" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script demonstrates basic MuFo workflow patterns:" -ForegroundColor Yellow
Write-Host "1. How to analyze artists using Invoke-MuFo core" -ForegroundColor White
Write-Host "2. How to categorize results by confidence" -ForegroundColor White
Write-Host "3. How to use Out-GridView for interactive selection" -ForegroundColor White
Write-Host "4. How to process selected items" -ForegroundColor White
Write-Host ""

# Check if library path exists
if (-not (Test-Path $LibraryPath)) {
    Write-Warning "Library path not found: $LibraryPath"
    Write-Host "Please modify the script or provide a valid path as parameter." -ForegroundColor Yellow
    exit
}

# Step 1: Get artist folders
Write-Host "🔍 Step 1: Finding artist folders..." -ForegroundColor Cyan
$artistFolders = Get-ChildItem -Path $LibraryPath -Directory
Write-Host "   Found: $($artistFolders.Count) artist folders" -ForegroundColor Green

# Step 2: Analyze each artist (simplified version)
Write-Host ""
Write-Host "🔍 Step 2: Analyzing artists..." -ForegroundColor Cyan
$results = @()

foreach ($artist in $artistFolders | Select-Object -First 5) {  # Limit to 5 for demo
    Write-Host "   Analyzing: $($artist.Name)" -ForegroundColor Gray
    
    try {
        # This is the core MuFo analysis call
        $analysis = Invoke-MuFo -Path $artist.FullName -Preview -ArtistAt Here
        
        # Extract confidence score (this is how you get it from MuFo results)
        $confidence = if ($analysis.SelectedArtist.ConfidenceScore) { 
            $analysis.SelectedArtist.ConfidenceScore 
        } else { 0 }
        
        # Create result object (this is the pattern for building workflow data)
        $results += [PSCustomObject]@{
            LocalName = $artist.Name
            SpotifyMatch = $analysis.SelectedArtist.Name
            Confidence = [math]::Round($confidence, 2)
            Category = if ($confidence -ge 0.8) { "High" } 
                      elseif ($confidence -ge 0.5) { "Medium" } 
                      else { "Low" }
            Path = $artist.FullName
        }
        
    } catch {
        # Error handling pattern
        $results += [PSCustomObject]@{
            LocalName = $artist.Name
            SpotifyMatch = "Analysis failed"
            Confidence = 0
            Category = "Error"
            Path = $artist.FullName
        }
    }
}

# Step 3: Show results and use Out-GridView
Write-Host ""
Write-Host "🔍 Step 3: Showing results..." -ForegroundColor Cyan
Write-Host "Results summary:" -ForegroundColor White
$results | Group-Object Category | ForEach-Object {
    Write-Host "   $($_.Name): $($_.Count) artists" -ForegroundColor Gray
}

Write-Host ""
Write-Host "📋 Opening Out-GridView for interactive selection..." -ForegroundColor Cyan
Write-Host "(Select items you want to process, then click OK)" -ForegroundColor Yellow

# This is the key Out-GridView pattern for interactive workflows
$selected = $results | Out-GridView -Title "Learning Example - Select artists to process" -PassThru

# Step 4: Process selected items
if ($selected.Count -eq 0) {
    Write-Host "No items selected. Example complete." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "🔄 Step 4: Processing selected items..." -ForegroundColor Cyan
    
    foreach ($item in $selected) {
        Write-Host "   Processing: $($item.LocalName) → $($item.SpotifyMatch)" -ForegroundColor Green
        
        # In a real workflow, you'd call:
        # Invoke-MuFo -Path $item.Path -DoIt Automatic
        
        Write-Host "   (Demo mode - not actually processing)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✅ Learning Example Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Key Patterns You Learned:" -ForegroundColor Cyan
Write-Host "   • Use 'Invoke-MuFo -Preview' for analysis without changes" -ForegroundColor White
Write-Host "   • Build result objects with consistent properties" -ForegroundColor White
Write-Host "   • Use 'Out-GridView -PassThru' for interactive selection" -ForegroundColor White
Write-Host "   • Process selected items with 'Invoke-MuFo -DoIt Automatic'" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "   • Modify this script to add your own categorization logic" -ForegroundColor White
Write-Host "   • Add custom filtering or sorting" -ForegroundColor White
Write-Host "   • Create your own workflow variations" -ForegroundColor White
Write-Host "   • See Get-MuFoArtistReport for the full implementation" -ForegroundColor White