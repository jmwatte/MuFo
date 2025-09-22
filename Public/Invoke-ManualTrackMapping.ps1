function Invoke-ManualTrackMapping {
<#
.SYNOPSIS
    Manual track mapping workflow for edge cases and forensic analysis.

.DESCRIPTION
    Two-step workflow for manually correcting track order when automatic methods fail:
    
    Step 1: Generate playlist + editable mapping file
    Step 2: Import your edits to update track numbers and optionally rename files
    
    This is designed for edge cases where:
    - Track numbers in tags don't match actual audio order
    - Filename order doesn't match actual album order  
    - You need to manually verify track order by listening
    - Automatic Spotify matching can't determine correct order

.PARAMETER Path
    Path to folder containing audio files.

.PARAMETER Action
    What to do:
    - Generate: Create playlist and mapping file for editing
    - Import: Apply edited mapping file to update tags/filenames

.PARAMETER OutputName
    Base name for output files when Action is Generate.
    Creates: OutputName.m3u and OutputName.txt

.PARAMETER MappingFile
    Path to edited mapping file when Action is Import.

.PARAMETER RenameFiles
    When importing, also rename files to match new track order.

.PARAMETER SortBy
    How to initially sort tracks for mapping generation.
    - FileName: Sort by filename (default)
    - TrackNumber: Sort by track number in tags
    - Title: Sort by title in tags

.PARAMETER WhatIf
    Preview changes without applying them (Import action only).

.EXAMPLE
    Invoke-ManualTrackMapping -Path "C:\Music\Problem Album" -Action Generate -OutputName "fix-album"
    
    Step 1: Creates fix-album.m3u and fix-album.txt
    Listen to the playlist and edit the .txt file to match what you hear.

.EXAMPLE
    Invoke-ManualTrackMapping -Action Import -MappingFile "fix-album.txt" -RenameFiles
    
    Step 2: Applies your edits to update track numbers and rename files.

.EXAMPLE
    # Complete workflow
    cd "C:\Music\Problem Album"
    Invoke-ManualTrackMapping -Path . -Action Generate -OutputName "mapping"
    # Edit mapping.txt to match what you hear in mapping.m3u
    Invoke-ManualTrackMapping -Action Import -MappingFile "mapping.txt" -WhatIf
    Invoke-ManualTrackMapping -Action Import -MappingFile "mapping.txt" -RenameFiles

.NOTES
    Author: jmw
    Part of MuFo manual override system for edge cases.
    Always creates backups before making changes.
    
    Workflow:
    1. Generate: Creates playlist (.m3u) and mapping file (.txt)
    2. You: Play playlist and edit mapping file to match what you hear
    3. Import: Updates track tags and optionally renames files
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Generate')]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Generate', 'Import')]
        [string]$Action,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Generate')]
        [string]$OutputName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Import')]
        [string]$MappingFile,
        
        [Parameter(ParameterSetName = 'Import')]
        [switch]$RenameFiles,
        
        [Parameter(ParameterSetName = 'Generate')]
        [ValidateSet('FileName', 'TrackNumber', 'Title')]
        [string]$SortBy = 'FileName',
        
        [Parameter(ParameterSetName = 'Import')]
        [switch]$WhatIf
    )
    
    switch ($Action) {
        'Generate' {
            Write-Host "🎵 Generating manual track mapping workflow..." -ForegroundColor Cyan
            
            $result = New-TrackMapping -Path $Path -OutputName $OutputName -SortBy $SortBy
            
            if ($result) {
                Write-Host ""
                Write-Host "Manual workflow ready!" -ForegroundColor Green
                Write-Host "Files created:" -ForegroundColor Yellow
                Write-Host "  🎵 Playlist: $($result.PlaylistFile)" -ForegroundColor White
                Write-Host "  📝 Mapping:  $($result.MappingFile)" -ForegroundColor White
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Yellow
                Write-Host "1. Play the playlist file in your media player" -ForegroundColor White
                Write-Host "2. Edit the mapping file to match the order you hear" -ForegroundColor White
                Write-Host "3. Run: Invoke-ManualTrackMapping -Action Import -MappingFile '$($result.MappingFile)'" -ForegroundColor White
            }
        }
        
        'Import' {
            Write-Host "📥 Importing track mapping changes..." -ForegroundColor Cyan
            
            $importParams = @{
                MappingFile = $MappingFile
            }
            
            if ($RenameFiles) { $importParams.RenameFiles = $true }
            
            $result = Import-TrackMapping @importParams -WhatIf:$WhatIf
            
            if ($result -and -not $WhatIf) {
                Write-Host ""
                Write-Host "Import completed!" -ForegroundColor Green
                Write-Host "Files processed: $($result.ProcessedFiles) of $($result.TotalChanges)" -ForegroundColor White
                
                if ($result.BackupSuffix) {
                    Write-Host ""
                    Write-Host "💾 Backup files created with suffix: $($result.BackupSuffix)" -ForegroundColor Cyan
                    Write-Host "   Review changes and delete backups when satisfied" -ForegroundColor Gray
                }
            }
        }
    }
}