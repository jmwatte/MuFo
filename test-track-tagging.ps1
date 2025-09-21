#Requires -Modules MuFo

<#
.SYNOPSIS
    Test script for validating track tagging functionality with classical music support.

.DESCRIPTION
    This script tests the Get-AudioFileTags function to ensure it properly handles:
    - Basic audio file tag reading
    - Classical music composer detection
    - Contributing artists analysis (conductors, orchestras, soloists)
    - Suggested album artist determination
    
.NOTES
    Requires TagLib-Sharp to be installed and available.
    Author: jmw
#>

param(
    [Parameter(Mandatory)]
    [string]$TestPath,
    
    [switch]$Verbose,
    
    [string]$LogTo = "tag-test-results.json"
)

# Import the module
Import-Module $PSScriptRoot\MuFo.psd1 -Force

Write-Host "=== MuFo Track Tagging Test ===" -ForegroundColor Cyan
Write-Host "Testing path: $TestPath" -ForegroundColor Yellow

if (-not (Test-Path $TestPath)) {
    Write-Error "Test path does not exist: $TestPath"
    exit 1
}

try {
    # Test basic tag reading
    Write-Host "`n--- Basic Tag Reading ---" -ForegroundColor Green
    $basicTags = Get-AudioFileTags -Path $TestPath
    
    if ($basicTags.Count -eq 0) {
        Write-Warning "No audio files found or TagLib-Sharp not available"
        Write-Host ""        
        Write-Host "If TagLib-Sharp is missing, the Get-AudioFileTags function will offer to install it." -ForegroundColor Yellow
        Write-Host "Alternatively, install manually: Install-Package TagLibSharp" -ForegroundColor White
        Write-Host ""        
        Write-Host "Note: If no audio files exist in the test path, create some sample files first." -ForegroundColor Cyan
        exit 1
    }
    
    Write-Host "Found $($basicTags.Count) audio files" -ForegroundColor Green
    
    # Display sample basic tags
    $sample = $basicTags | Select-Object -First 3
    foreach ($track in $sample) {
        Write-Host "  File: $($track.FileName)" -ForegroundColor White
        Write-Host "    Title: $($track.Title)" -ForegroundColor Gray
        Write-Host "    Artist: $($track.Artist)" -ForegroundColor Gray
        Write-Host "    Album: $($track.Album)" -ForegroundColor Gray
        Write-Host "    Year: $($track.Year)" -ForegroundColor Gray
        Write-Host "    Duration: $($track.Duration)" -ForegroundColor Gray
        Write-Host ""
    }

    # Test classical music analysis
    Write-Host "--- Classical Music Analysis ---" -ForegroundColor Green
    $classicalTags = Get-AudioFileTags -Path $TestPath -IncludeComposer -LogTo $LogTo
    
    $classicalTracks = $classicalTags | Where-Object { $_.IsClassical -eq $true }
    Write-Host "Detected $($classicalTracks.Count) classical music tracks" -ForegroundColor Green
    
    if ($classicalTracks.Count -gt 0) {
        Write-Host "`nClassical Music Analysis:" -ForegroundColor Yellow
        
        foreach ($track in ($classicalTracks | Select-Object -First 3)) {
            Write-Host "  File: $($track.FileName)" -ForegroundColor White
            Write-Host "    Composer: $($track.Composer)" -ForegroundColor Cyan
            Write-Host "    Artists: $($track.Artists -join ', ')" -ForegroundColor Gray
            Write-Host "    Album Artists: $($track.AlbumArtists -join ', ')" -ForegroundColor Gray
            Write-Host "    Suggested Album Artist: $($track.SuggestedAlbumArtist)" -ForegroundColor Green
            
            if ($track.ContributingArtists.Count -gt 0) {
                Write-Host "    Contributing Artists:" -ForegroundColor Yellow
                foreach ($contributor in $track.ContributingArtists) {
                    Write-Host "      $($contributor.Type): $($contributor.Name)" -ForegroundColor Gray
                }
            }
            
            if ($track.Conductor) {
                Write-Host "    Conductor: $($track.Conductor)" -ForegroundColor Magenta
            }
            Write-Host ""
        }
    }

    # Summary statistics
    Write-Host "--- Summary Statistics ---" -ForegroundColor Green
    $stats = @{
        TotalFiles = $classicalTags.Count
        ClassicalTracks = ($classicalTags | Where-Object IsClassical).Count
        TracksWithComposer = ($classicalTags | Where-Object { $_.Composer }).Count
        TracksWithConductor = ($classicalTags | Where-Object { $_.Conductor }).Count
        UniqueAlbums = ($classicalTags | Group-Object Album | Measure-Object).Count
        UniqueArtists = ($classicalTags | ForEach-Object { $_.Artists } | Select-Object -Unique | Measure-Object).Count
    }
    
    foreach ($key in $stats.Keys) {
        Write-Host "  $key`: $($stats[$key])" -ForegroundColor White
    }

    # Test organization suggestions
    Write-Host "`n--- Organization Suggestions ---" -ForegroundColor Green
    $albums = $classicalTags | Group-Object Album | Where-Object { $_.Name }
    
    foreach ($album in ($albums | Select-Object -First 5)) {
        $albumTracks = $album.Group
        $firstTrack = $albumTracks[0]
        
        Write-Host "Album: $($album.Name)" -ForegroundColor Yellow
        Write-Host "  Current Artist(s): $($albumTracks.Artist | Select-Object -Unique | Where-Object { $_ } | Join-String -Separator ', ')" -ForegroundColor Gray
        
        if ($firstTrack.IsClassical) {
            Write-Host "  Suggested Album Artist: $($firstTrack.SuggestedAlbumArtist)" -ForegroundColor Green
            Write-Host "  Classification: Classical Music" -ForegroundColor Cyan
        } else {
            Write-Host "  Classification: Popular Music" -ForegroundColor White
        }
        Write-Host ""
    }

    Write-Host "=== Test Completed Successfully ===" -ForegroundColor Green
    Write-Host "Log saved to: $LogTo" -ForegroundColor Yellow
    
} catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}