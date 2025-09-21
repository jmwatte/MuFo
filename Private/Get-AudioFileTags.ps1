function Get-AudioFileTags {
<#
.SYNOPSIS
    Reads audio file tags using TagLib-Sharp with enhanced classical music support.

.DESCRIPTION
    This function scans a folder or processes individual audio files to extract metadata
    using TagLib-Sharp. It provides special handling for classical music with proper
    composer, performer, and album artist distinction.

.PARAMETER Path
    The path to a folder containing audio files or a single audio file.

.PARAMETER IncludeComposer
    Include detailed composer and classical music analysis in the output.

.PARAMETER LogTo
    Optional path to log detailed tag information for debugging.

.OUTPUTS
    Array of PSCustomObject with comprehensive tag fields including classical music metadata.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Arvo Pärt\1999 - Alina" -IncludeComposer
    
    Reads all audio files with classical music analysis.

.NOTES
    Requires TagLib-Sharp assembly to be loaded.
    Supported formats: .mp3, .flac, .m4a, .ogg, .wav (where supported by TagLib)
    Author: jmw
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$IncludeComposer,
        
        [string]$LogTo
    )

    begin {
        # Supported audio file extensions
        $supportedExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')

        # Check for TagLib-Sharp and offer installation if missing
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        
        if (-not $tagLibLoaded) {
            # Try to find and load TagLib-Sharp
            $tagLibPaths = @(
                "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",
                "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll",
                (Join-Path $PSScriptRoot '..\TagLib-Sharp.dll'),
                (Join-Path $PSScriptRoot 'TagLib-Sharp.dll')
            )
            
            $tagLibPath = $null
            foreach ($path in $tagLibPaths) {
                if ($path -like "*\*") {
                    # Handle wildcard paths for NuGet packages
                    $found = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                             Where-Object { $_.Name -eq 'TagLib.dll' } | 
                             Select-Object -First 1
                    if ($found) {
                        $tagLibPath = $found.FullName
                        break
                    }
                } elseif (Test-Path $path) {
                    $tagLibPath = $path
                    break
                }
            }
            
            if (-not $tagLibPath) {
                # TagLib-Sharp not found - offer to install
                Write-Host "TagLib-Sharp is required for track tag reading but is not installed." -ForegroundColor Yellow
                Write-Host ""                
                
                # Only prompt if running interactively
                if ([Environment]::UserInteractive -and -not $env:CI) {
                    Write-Host "Would you like to install TagLib-Sharp now? [Y/n]: " -NoNewline -ForegroundColor Cyan
                    $response = Read-Host
                    if ($response -eq '' -or $response -match '^[Yy]') {
                        # Use the helper function if available
                        if (Get-Command Install-TagLibSharp -ErrorAction SilentlyContinue) {
                            try {
                                Install-TagLibSharp
                                Write-Host ""
                                Write-Host "Please restart PowerShell and run your command again to use TagLib-Sharp." -ForegroundColor Yellow
                            } catch {
                                Write-Warning "Installation helper failed: $($_.Exception.Message)"
                                Write-Host "Please try manual installation: Install-Package TagLibSharp" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "Installing TagLib-Sharp..." -ForegroundColor Green
                            try {
                                Install-Package TagLibSharp -Scope CurrentUser -Force -SkipDependencies -ErrorAction Stop
                                Write-Host "✓ TagLib-Sharp installed successfully!" -ForegroundColor Green
                                Write-Host "Please restart PowerShell and try again." -ForegroundColor Yellow
                            } catch {
                                Write-Warning "Failed to install TagLib-Sharp: $($_.Exception.Message)"
                                Write-Host ""
                                Write-Host "Please try manual installation:" -ForegroundColor Yellow
                                Write-Host "  Install-Package TagLibSharp -Force" -ForegroundColor White
                                Write-Host "  -or-" -ForegroundColor Yellow  
                                Write-Host "  Download from: https://www.nuget.org/packages/TagLibSharp/" -ForegroundColor White
                            }
                        }
                    }
                } else {
                    Write-Host "To install TagLib-Sharp:" -ForegroundColor Yellow
                    Write-Host "  Install-Package TagLibSharp" -ForegroundColor White
                    Write-Host "  -or- Use: Install-TagLibSharp (helper function)" -ForegroundColor White
                }
                
                return @()
            }
            
            try {
                Add-Type -Path $tagLibPath
                Write-Verbose "Loaded TagLib-Sharp from $tagLibPath"
            } catch {
                Write-Warning "Failed to load TagLib-Sharp from $tagLibPath`: $($_.Exception.Message)"
                Write-Host "Please try reinstalling TagLib-Sharp:" -ForegroundColor Yellow
                Write-Host "  Install-Package TagLibSharp -Force" -ForegroundColor White
                return @()
            }
        }
    }

    process {
        $results = @()

        # Determine if Path is a file or folder
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $files = @($Path)
        } elseif (Test-Path -LiteralPath $Path -PathType Container) {
            $files = Get-ChildItem -LiteralPath $Path -File | Where-Object { $_.Extension -in $supportedExtensions } | Select-Object -ExpandProperty FullName
        } else {
            Write-Warning "Path '$Path' does not exist or is not accessible."
            return @()
        }

        Write-Verbose "Processing $($files.Count) audio files"

        foreach ($file in $files) {
            try {
                Write-Verbose "Reading tags from: $(Split-Path $file -Leaf)"
                
                $fileObj = [TagLib.File]::Create($file)
                $tag = $fileObj.Tag
                $properties = $fileObj.Properties

                # Extract comprehensive tag information
                $artists = if ($tag -and $tag.Performers) { [array]$tag.Performers } else { @() }
                $albumArtists = if ($tag -and $tag.AlbumArtists) { [array]$tag.AlbumArtists } else { @() }
                $composers = if ($tag -and $tag.Composers) { [array]$tag.Composers } else { @() }
                $genres = if ($tag -and $tag.Genres) { [array]$tag.Genres } else { @() }

                # Create comprehensive tag object
                $normalizedTag = [PSCustomObject]@{
                    Path            = $file
                    FileName        = [System.IO.Path]::GetFileName($file)
                    Title           = if ($tag -and $tag.Title) { $tag.Title } else { [System.IO.Path]::GetFileNameWithoutExtension($file) }
                    Artist          = if ($artists.Count -gt 0) { $artists[0] } else { $null }
                    Artists         = $artists
                    AlbumArtist     = if ($albumArtists.Count -gt 0) { $albumArtists[0] } else { $null }
                    AlbumArtists    = $albumArtists
                    Album           = if ($tag -and $tag.Album) { $tag.Album } else { $null }
                    Track           = if ($tag -and $tag.Track) { $tag.Track } else { $null }
                    TrackCount      = if ($tag -and $tag.TrackCount) { $tag.TrackCount } else { $null }
                    Disc            = if ($tag -and $tag.Disc) { $tag.Disc } else { $null }
                    DiscCount       = if ($tag -and $tag.DiscCount) { $tag.DiscCount } else { $null }
                    Year            = if ($tag -and $tag.Year) { $tag.Year } else { $null }
                    Genre           = if ($genres.Count -gt 0) { $genres[0] } else { $null }
                    Genres          = $genres
                    Duration        = if ($properties -and $properties.Duration) { $properties.Duration } else { [TimeSpan]::Zero }
                    DurationSeconds = if ($properties -and $properties.Duration) { $properties.Duration.TotalSeconds } else { 0 }
                    Bitrate         = if ($properties -and $properties.AudioBitrate) { $properties.AudioBitrate } else { 0 }
                    SampleRate      = if ($properties -and $properties.AudioSampleRate) { $properties.AudioSampleRate } else { 0 }
                    Format          = [System.IO.Path]::GetExtension($file).TrimStart('.')
                }

                # Add classical music analysis if requested
                if ($IncludeComposer) {
                    # Extract composer information
                    $composer = $null
                    if ($composers.Count -gt 0) {
                        $composer = $composers[0]
                    } elseif ($tag.Comment -match 'Composer:\s*(.+)') {
                        $composer = $matches[1].Trim()
                    } elseif ($artists -contains "Arvo Pärt" -or $artists -contains "Arvo Part") {
                        $composer = "Arvo Pärt"
                    }

                    # Detect if this is classical music
                    $isClassical = $false
                    $classicalIndicators = @(
                        ($composer -ne $null),
                        ($genres -contains "Classical"),
                        ($normalizedTag.Album -match "(?i)(symphony|concerto|sonata|quartet|opera|oratorio|cantata|mass|requiem|preludes|etudes)"),
                        (($artists -join " ") -match "(?i)(orchestra|symphony|philharmonic|ensemble|quartet|choir|philharmonie)")
                    )
                    $isClassical = $classicalIndicators -contains $true

                    # Analyze contributors for classical music
                    $contributingArtists = @()
                    $conductor = $null
                    if ($isClassical) {
                        foreach ($artist in $artists) {
                            if ($artist -match "(?i)(orchestra|symphony|philharmonic|philharmonie)") {
                                $contributingArtists += @{ Type = "Orchestra"; Name = $artist }
                            } elseif ($artist -match "(?i)(conductor|dirigent)") {
                                $conductor = $artist -replace "(?i),?\s*(conductor|dirigent)", ""
                                $contributingArtists += @{ Type = "Conductor"; Name = $conductor }
                            } elseif ($artist -ne $composer) {
                                $contributingArtists += @{ Type = "Performer"; Name = $artist }
                            }
                        }
                    }

                    # Suggest organization strategy for classical music
                    $suggestedAlbumArtist = $null
                    if ($isClassical) {
                        if ($composer) {
                            $suggestedAlbumArtist = $composer
                        } elseif ($conductor) {
                            $suggestedAlbumArtist = $conductor
                        } elseif ($albumArtists.Count -gt 0) {
                            $suggestedAlbumArtist = $albumArtists[0]
                        } elseif ($artists.Count -gt 0 -and $artists[0] -notmatch "(?i)(orchestra|symphony|philharmonic|various)") {
                            $suggestedAlbumArtist = $artists[0]
                        }
                    }

                    # Add classical music properties
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "Composer" -Value $composer
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "Composers" -Value $composers
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "IsClassical" -Value $isClassical
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "ContributingArtists" -Value $contributingArtists
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "Conductor" -Value $conductor
                    Add-Member -InputObject $normalizedTag -MemberType NoteProperty -Name "SuggestedAlbumArtist" -Value $suggestedAlbumArtist
                }

                $results += $normalizedTag
                
                # Log detailed information if requested
                if ($LogTo) {
                    $logEntry = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        File = $normalizedTag.FileName
                        Tags = $normalizedTag
                    }
                    $logEntry | ConvertTo-Json -Depth 10 | Add-Content -Path $LogTo
                }

                # Clean up
                $fileObj.Dispose()
                
            } catch {
                Write-Warning "Failed to read tags from '$(Split-Path $file -Leaf)': $($_.Exception.Message)"
                
                # Log error if requested
                if ($LogTo) {
                    $errorEntry = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        File = $(Split-Path $file -Leaf)
                        Error = $_.Exception.Message
                    }
                    $errorEntry | ConvertTo-Json | Add-Content -Path $LogTo
                }
            }
        }

        return $results
    }
}