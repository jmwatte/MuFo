function Set-TrackTags {
<#
.SYNOPSIS
    Manual command to set specific tag values in audio files using TagLib-Sharp.

.DESCRIPTION
    Provides direct tag modification for manual override scenarios.
    Use this when automatic tagging doesn't work and you need precise control.

.PARAMETER Path
    Path to the audio file to modify.

.PARAMETER Title
    Set the track title.

.PARAMETER Artist
    Set the track artist (performer).

.PARAMETER AlbumArtist
    Set the album artist.

.PARAMETER Album
    Set the album name.

.PARAMETER Track
    Set the track number.

.PARAMETER Year
    Set the year.

.PARAMETER Genre
    Set the genre.

.PARAMETER RenameFile
    Rename the file based on new tag information using pattern: "TrackNumber - Title.ext"

.PARAMETER RenamePattern
    Custom rename pattern. Variables: {Track}, {Title}, {Artist}, {Album}
    Default: "{Track:D2} - {Title}"

.EXAMPLE
    Set-TrackTags -Path "track1.mp3" -Title "Correct Title" -Track 1
    
    Sets title and track number manually.

.EXAMPLE
    Set-TrackTags -Path "track1.mp3" -Title "Hotel" -Track 5 -RenameFile
    
    Sets tags and renames file to "05 - Hotel.mp3"

.EXAMPLE
    Set-TrackTags -Path "track1.mp3" -Title "Wall" -RenamePattern "{Track:D2}-{Artist}-{Title}" -RenameFile
    
    Custom rename pattern: "05-Pink Floyd-Wall.mp3"

.NOTES
    Author: jmw
    Part of manual override system for MuFo.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,
        
        [string]$Title,
        [string]$Artist,
        [string]$AlbumArtist,
        [string]$Album,
        [int]$Track,
        [int]$Year,
        [string]$Genre,
        
        [switch]$RenameFile,
        [string]$RenamePattern = "{Track:D2} - {Title}"
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
        
        $changes = @()
        $newFileName = $null
        
        try {
            $file = [TagLib.File]::Create($Path)
            $tag = $file.Tag
            
            # Apply tag changes
            if ($PSBoundParameters.ContainsKey('Title')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set title to '$Title'")) {
                    $tag.Title = $Title
                }
                $changes += "Title: '$Title'"
            }
            
            if ($PSBoundParameters.ContainsKey('Artist')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set artist to '$Artist'")) {
                    $tag.Performers = @($Artist)
                }
                $changes += "Artist: '$Artist'"
            }
            
            if ($PSBoundParameters.ContainsKey('AlbumArtist')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set album artist to '$AlbumArtist'")) {
                    $tag.AlbumArtists = @($AlbumArtist)
                }
                $changes += "AlbumArtist: '$AlbumArtist'"
            }
            
            if ($PSBoundParameters.ContainsKey('Album')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set album to '$Album'")) {
                    $tag.Album = $Album
                }
                $changes += "Album: '$Album'"
            }
            
            if ($PSBoundParameters.ContainsKey('Track')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set track number to $Track")) {
                    $tag.Track = $Track
                }
                $changes += "Track: $Track"
            }
            
            if ($PSBoundParameters.ContainsKey('Year')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set year to $Year")) {
                    $tag.Year = $Year
                }
                $changes += "Year: $Year"
            }
            
            if ($PSBoundParameters.ContainsKey('Genre')) {
                if ($PSCmdlet.ShouldProcess($Path, "Set genre to '$Genre'")) {
                    $tag.Genres = @($Genre)
                }
                $changes += "Genre: '$Genre'"
            }
            
            # Calculate new filename if renaming
            if ($RenameFile) {
                $fileInfo = [System.IO.FileInfo]::new($Path)
                $currentTitle = if ($PSBoundParameters.ContainsKey('Title')) { $Title } else { $tag.Title }
                $currentTrack = if ($PSBoundParameters.ContainsKey('Track')) { $Track } else { $tag.Track }
                $currentArtist = if ($PSBoundParameters.ContainsKey('Artist')) { $Artist } else { 
                    if ($tag.Performers -and $tag.Performers.Length -gt 0) { $tag.Performers[0] } else { "Unknown" }
                }
                $currentAlbum = if ($PSBoundParameters.ContainsKey('Album')) { $Album } else { $tag.Album }
                
                # Create filename from pattern
                $cleanTitle = if ($currentTitle) { $currentTitle -replace '[<>:"/\\|?*]', '_' } else { "Unknown" }
                $cleanArtist = if ($currentArtist) { $currentArtist -replace '[<>:"/\\|?*]', '_' } else { "Unknown" }
                $cleanAlbum = if ($currentAlbum) { $currentAlbum -replace '[<>:"/\\|?*]', '_' } else { "Unknown" }
                
                # Replace pattern variables
                $filename = $RenamePattern
                $filename = $filename -replace '\{Track:D2\}', $("{0:D2}" -f $currentTrack)
                $filename = $filename -replace '\{Track\}', $currentTrack
                $filename = $filename -replace '\{Title\}', $cleanTitle
                $filename = $filename -replace '\{Artist\}', $cleanArtist
                $filename = $filename -replace '\{Album\}', $cleanAlbum
                
                $newFileName = "$filename$($fileInfo.Extension)"
                $newPath = Join-Path $fileInfo.DirectoryName $newFileName
                
                if ($newFileName -ne $fileInfo.Name) {
                    $changes += "Rename: '$($fileInfo.Name)' → '$newFileName'"
                }
            }
            
            # Display what would change
            if ($changes.Count -gt 0) {
                Write-Host "Changes for: $([System.IO.Path]::GetFileName($Path))" -ForegroundColor Cyan
                foreach ($change in $changes) {
                    Write-Host "  $change" -ForegroundColor Yellow
                }
            } else {
                Write-Host "No changes specified for: $([System.IO.Path]::GetFileName($Path))" -ForegroundColor Gray
                return
            }
            
            # Apply changes if not WhatIf
            if (-not $WhatIfPreference -and $changes.Count -gt 0) {
                # Save tag changes
                if ($changes -notlike "*Rename:*") {
                    $file.Save()
                    Write-Host "✅ Tags updated successfully" -ForegroundColor Green
                }
                
                # Rename file if requested
                if ($RenameFile -and $newFileName -and $newFileName -ne [System.IO.Path]::GetFileName($Path)) {
                    $file.Dispose()  # Release file handle before renaming
                    $file = $null
                    
                    $fileInfo = [System.IO.FileInfo]::new($Path)
                    $newPath = Join-Path $fileInfo.DirectoryName $newFileName
                    
                    if (Test-Path $newPath) {
                        Write-Warning "Target filename already exists: $newFileName"
                    } else {
                        if ($PSCmdlet.ShouldProcess($Path, "Rename to '$newFileName'")) {
                            Move-Item -Path $Path -Destination $newPath
                            Write-Host "✅ File renamed successfully" -ForegroundColor Green
                        }
                    }
                }
            }
            
        } catch {
            Write-Error "Failed to update tags for '$Path': $($_.Exception.Message)"
        } finally {
            if ($file) {
                $file.Dispose()
            }
        }
    }
}