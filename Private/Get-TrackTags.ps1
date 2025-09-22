function Get-TrackTags {
<#
.SYNOPSIS
    Manual command to inspect audio file tags directly using TagLib-Sharp.

.DESCRIPTION
    Provides detailed tag inspection for manual verification and troubleshooting.
    Use this when you need to see exactly what's in a file's metadata.

.PARAMETER Path
    Path to the audio file to inspect.

.PARAMETER ShowAll
    Display all available tag fields, including empty ones.

.PARAMETER ShowFileInfo
    Include file system information (size, dates, etc.).

.EXAMPLE
    Get-TrackTags -Path "01-track.mp3"
    
    Shows basic tag information for manual verification.

.EXAMPLE
    Get-TrackTags -Path "01-track.mp3" -ShowAll -ShowFileInfo
    
    Shows comprehensive tag and file information for debugging.

.NOTES
    Author: jmw
    Part of manual override system for MuFo.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        
        [switch]$ShowAll,
        
        [switch]$ShowFileInfo
    )
    
    process {
        if (-not (Test-Path $Path)) {
            Write-Error "File not found: $Path"
            return
        }
        
        # Check if TagLib-Sharp is available
        if (-not ([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
            Write-Warning "TagLib-Sharp not loaded. Use Install-TagLibSharp first."
            return
        }
        
        try {
            $file = [TagLib.File]::Create($Path)
            $tag = $file.Tag
            $properties = $file.Properties
            
            # Create comprehensive tag information
            $tagInfo = [PSCustomObject]@{
                # File Information
                FilePath = $Path
                FileName = [System.IO.Path]::GetFileName($Path)
                FileSize = if ($ShowFileInfo) { [System.IO.FileInfo]::new($Path).Length } else { $null }
                
                # Basic Tags
                Title = $tag.Title
                Artist = if ($tag.Performers -and $tag.Performers.Length -gt 0) { $tag.Performers[0] } else { $null }
                Artists = $tag.Performers
                AlbumArtist = if ($tag.AlbumArtists -and $tag.AlbumArtists.Length -gt 0) { $tag.AlbumArtists[0] } else { $null }
                AlbumArtists = $tag.AlbumArtists
                Album = $tag.Album
                Track = $tag.Track
                TrackCount = $tag.TrackCount
                Disc = $tag.Disc
                DiscCount = $tag.DiscCount
                Year = $tag.Year
                Genre = if ($tag.Genres -and $tag.Genres.Length -gt 0) { $tag.Genres[0] } else { $null }
                Genres = $tag.Genres
                
                # Audio Properties
                Duration = $properties.Duration
                DurationSeconds = $properties.Duration.TotalSeconds
                Bitrate = $properties.AudioBitrate
                SampleRate = $properties.AudioSampleRate
                Channels = $properties.AudioChannels
                
                # Extended Tags (only if ShowAll)
                Comment = if ($ShowAll) { $tag.Comment } else { $null }
                Composer = if ($ShowAll -and $tag.Composers -and $tag.Composers.Length -gt 0) { $tag.Composers[0] } else { $null }
                Composers = if ($ShowAll) { $tag.Composers } else { $null }
                Conductor = if ($ShowAll) { $tag.Conductor } else { $null }
                Copyright = if ($ShowAll) { $tag.Copyright } else { $null }
                
                # File System Info (only if ShowFileInfo)
                Created = if ($ShowFileInfo) { [System.IO.FileInfo]::new($Path).CreationTime } else { $null }
                Modified = if ($ShowFileInfo) { [System.IO.FileInfo]::new($Path).LastWriteTime } else { $null }
                Format = [System.IO.Path]::GetExtension($Path).TrimStart('.')
            }
            
            # Display formatted output
            Write-Host "Track Information: $($tagInfo.FileName)" -ForegroundColor Cyan
            Write-Host "Path: $($tagInfo.FilePath)" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "Basic Tags:" -ForegroundColor Yellow
            Write-Host "  Title: $($tagInfo.Title)" -ForegroundColor White
            Write-Host "  Artist: $($tagInfo.Artist)" -ForegroundColor White
            Write-Host "  Album Artist: $($tagInfo.AlbumArtist)" -ForegroundColor White
            Write-Host "  Album: $($tagInfo.Album)" -ForegroundColor White
            Write-Host "  Track: $($tagInfo.Track)$(if ($tagInfo.TrackCount) { "/$($tagInfo.TrackCount)" })" -ForegroundColor White
            Write-Host "  Year: $($tagInfo.Year)" -ForegroundColor White
            Write-Host "  Genre: $($tagInfo.Genre)" -ForegroundColor White
            
            Write-Host ""
            Write-Host "Audio Properties:" -ForegroundColor Yellow
            Write-Host "  Duration: $($tagInfo.Duration)" -ForegroundColor White
            Write-Host "  Bitrate: $($tagInfo.Bitrate) kbps" -ForegroundColor White
            Write-Host "  Sample Rate: $($tagInfo.SampleRate) Hz" -ForegroundColor White
            
            if ($ShowAll) {
                Write-Host ""
                Write-Host "Extended Information:" -ForegroundColor Yellow
                Write-Host "  All Artists: $($tagInfo.Artists -join ', ')" -ForegroundColor White
                Write-Host "  All Album Artists: $($tagInfo.AlbumArtists -join ', ')" -ForegroundColor White
                Write-Host "  All Genres: $($tagInfo.Genres -join ', ')" -ForegroundColor White
                Write-Host "  Composer: $($tagInfo.Composer)" -ForegroundColor White
                Write-Host "  Conductor: $($tagInfo.Conductor)" -ForegroundColor White
                Write-Host "  Comment: $($tagInfo.Comment)" -ForegroundColor White
            }
            
            if ($ShowFileInfo) {
                Write-Host ""
                Write-Host "File Information:" -ForegroundColor Yellow
                Write-Host "  Size: $([math]::Round($tagInfo.FileSize / 1MB, 2)) MB" -ForegroundColor White
                Write-Host "  Created: $($tagInfo.Created)" -ForegroundColor White
                Write-Host "  Modified: $($tagInfo.Modified)" -ForegroundColor White
                Write-Host "  Format: $($tagInfo.Format)" -ForegroundColor White
            }
            
            return $tagInfo
            
        } catch {
            Write-Error "Failed to read tags from '$Path': $($_.Exception.Message)"
        } finally {
            if ($file) {
                $file.Dispose()
            }
        }
    }
}