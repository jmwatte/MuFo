function New-TrackMapping {
<#
.SYNOPSIS
    Generate playlist and editable text file for manual track reordering workflow.

.DESCRIPTION
    Creates two files:
    1. .m3u playlist file for listening to tracks in current order
    2. .txt mapping file for manual editing (reorder lines to match what you hear)
    
    Workflow:
    1. Run this command to generate files
    2. Play the .m3u playlist in your media player
    3. Edit the .txt file to match the order you hear (vim/helix/notepad)
    4. Use Import-TrackMapping to apply your changes

.PARAMETER Path
    Path to folder containing audio files.

.PARAMETER OutputName
    Base name for output files (without extension).
    Creates: OutputName.m3u and OutputName.txt

.PARAMETER SortBy
    How to initially sort tracks for the mapping.
    - FileName: Sort by filename (default)
    - TrackNumber: Sort by track number in tags
    - Title: Sort by title in tags

.EXAMPLE
    New-TrackMapping -Path "C:\Music\Album" -OutputName "album-mapping"
    
    Creates:
    - album-mapping.m3u (playlist for listening)
    - album-mapping.txt (editable mapping file)

.EXAMPLE
    New-TrackMapping -Path "." -OutputName "fix-tracks" -SortBy TrackNumber
    
    Creates mapping files sorted by current track numbers.

.NOTES
    Author: jmw
    Part of manual override system for MuFo.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputName,
        
        [ValidateSet('FileName', 'TrackNumber', 'Title')]
        [string]$SortBy = 'FileName'
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Path not found: $Path"
        return
    }
    
    # Get audio files
    $audioExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')
    $audioFiles = Get-ChildItem -Path $Path -File | Where-Object { 
        $_.Extension.ToLower() -in $audioExtensions 
    }
    
    if ($audioFiles.Count -eq 0) {
        Write-Error "No audio files found in: $Path"
        return
    }
    
    Write-Host "Found $($audioFiles.Count) audio files" -ForegroundColor Cyan
    
    # Get tag information for sorting
    $trackInfo = @()
    foreach ($file in $audioFiles) {
        $info = @{
            File = $file
            FileName = $file.Name
            FullPath = $file.FullName
            TrackNumber = 0
            Title = ""
        }
        
        try {
            if (([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
                $tagFile = [TagLib.File]::Create($file.FullName)
                $info.TrackNumber = if ($tagFile.Tag.Track) { $tagFile.Tag.Track } else { 0 }
                $info.Title = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $file.BaseName }
                $tagFile.Dispose()
            } else {
                $info.Title = $file.BaseName
            }
        } catch {
            Write-Verbose "Could not read tags from: $($file.Name)"
            $info.Title = $file.BaseName
        }
        
        $trackInfo += $info
    }
    
    # Sort tracks according to SortBy parameter
    switch ($SortBy) {
        'FileName' { $sortedTracks = $trackInfo | Sort-Object FileName }
        'TrackNumber' { $sortedTracks = $trackInfo | Sort-Object TrackNumber, FileName }
        'Title' { $sortedTracks = $trackInfo | Sort-Object Title }
    }
    
    # Generate playlist file (.m3u)
    $playlistPath = "$OutputName.m3u"
    $playlistContent = @()
    $playlistContent += "#EXTM3U"
    
    foreach ($track in $sortedTracks) {
        $playlistContent += "#EXTINF:-1,$($track.Title)"
        $playlistContent += $track.FullPath
    }
    
    $playlistContent | Out-File -FilePath $playlistPath -Encoding UTF8
    Write-Host "✅ Playlist created: $playlistPath" -ForegroundColor Green
    
    # Generate editable mapping file (.txt)
    $mappingPath = "$OutputName.txt"
    $mappingContent = @()
    $mappingContent += "# MuFo Track Mapping File"
    $mappingContent += "# Instructions:"
    $mappingContent += "#   1. Play the $playlistPath file in your media player"
    $mappingContent += "#   2. Edit this file to match the order you hear"
    $mappingContent += "#   3. Move lines up/down to match actual track order"
    $mappingContent += "#   4. Edit track numbers and titles as needed"
    $mappingContent += "#   5. Save and use: Import-TrackMapping -MappingFile '$mappingPath'"
    $mappingContent += "#"
    $mappingContent += "# Format: TrackNumber. Title"
    $mappingContent += "# The first song you hear should be '1. [Title]'"
    $mappingContent += "# The second song you hear should be '2. [Title]'"
    $mappingContent += "# etc."
    $mappingContent += ""
    
    $trackNumber = 1
    foreach ($track in $sortedTracks) {
        $mappingContent += "$trackNumber. $($track.Title)"
        $trackNumber++
    }
    
    $mappingContent | Out-File -FilePath $mappingPath -Encoding UTF8
    Write-Host "✅ Mapping file created: $mappingPath" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. 🎵 Play: $playlistPath" -ForegroundColor White
    Write-Host "2. ✏️  Edit: $mappingPath (reorder to match what you hear)" -ForegroundColor White
    Write-Host "3. 💾 Save the mapping file" -ForegroundColor White
    Write-Host "4. 🔄 Run: Import-TrackMapping -MappingFile '$mappingPath'" -ForegroundColor White
    
    return @{
        PlaylistFile = $playlistPath
        MappingFile = $mappingPath
        TrackCount = $sortedTracks.Count
        SortedBy = $SortBy
    }
}