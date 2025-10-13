function Set-AudioFileTags {
<#
.SYNOPSIS
    Updates audio file tags with flexible input methods and pipeline support.

.DESCRIPTION
    Public wrapper for audio file tag updates. Supports three input patterns:
    1. Simple hashtable for uniform updates across files
    2. Pipeline input from Get-AudioFileTags for batch processing
    3. Transform scriptblock for complex per-file logic
    
    This function provides a user-friendly interface for tag modification while
    leveraging TagLib-Sharp for direct file writing.

.PARAMETER Path
    Path to an audio file or directory. Can be provided via pipeline from Get-AudioFileTags.
    Aliases: FilePath, LiteralPath

.PARAMETER Tags
    Hashtable of tag updates to apply. Keys should match tag property names.
    Example: @{Artist="Arvo Pärt"; Album="Alina"; Year=1999}

.PARAMETER InputObject
    PSCustomObject from Get-AudioFileTags pipeline. Automatically extracts Path property.

.PARAMETER Transform
    Scriptblock that receives current tag object ($_) and returns modified version.
    Example: { if ($_.Artist -eq "Unknown") { $_.Artist = "Correct Artist" }; $_ }

.PARAMETER PassThru
    Return updated tag objects after writing. Useful for verification or chaining.

.PARAMETER Force
    Skip confirmation prompts for destructive operations.

.PARAMETER WhatIf
    Show what changes would be made without actually writing them.

.PARAMETER Confirm
    Prompt for confirmation before making changes.

.EXAMPLE
    Set-AudioFileTags -Path "song.mp3" -Tags @{Artist="Arvo Pärt"; Album="Alina"}
    
    Updates specified tags on a single file.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Album" | Set-AudioFileTags -Tags @{AlbumArtist="Various Artists"} -PassThru
    
    Pipeline: Updates all files in album with same value, returns updated tags.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music\Album" | Set-AudioFileTags -Transform {
        if ($_.Title -match "^\d+\s+") {
            $_.Title = $_.Title -replace "^\d+\s+", ""
        }
        $_
    } -PassThru
    
    Uses transform scriptblock to remove leading track numbers from titles.

.EXAMPLE
    Set-AudioFileTags -Path "C:\Music\Album" -Tags @{Year=1999} -WhatIf
    
    Preview changes without applying them.

.EXAMPLE
    Get-AudioFileTags -Path "C:\Music" | Where-Object { $_.Year -eq $null } | Set-AudioFileTags -Tags @{Year=2023}
    
    Fix missing year tags across multiple files.

.NOTES
    Requires TagLib-Sharp assembly to be loaded.
    For album-level Spotify integration, use Invoke-MuFo with -FixTags.
    Author: jmw
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Simple')]
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Transform')]
        [Alias('FilePath', 'LiteralPath')]
        [string]$Path,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Simple')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [hashtable]$Tags,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [PSCustomObject]$InputObject,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Transform')]
        [scriptblock]$Transform,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Check for TagLib-Sharp
        $tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        
        if (-not $tagLibLoaded) {
            Write-Error "TagLib-Sharp is required but not loaded. Please run Get-AudioFileTags first to load it, or install: Install-Package TagLibSharp"
            return
        }
        
        $processedCount = 0
        $errorCount = 0
        $results = @()
        
        Write-Verbose "Starting tag update process"
    }
    
    process {
        # Determine the file path based on parameter set
        $filePath = switch ($PSCmdlet.ParameterSetName) {
            'Pipeline' { $InputObject.Path }
            'Simple' { $Path }
            'Transform' { $Path }
        }
        
        if (-not $filePath) {
            Write-Warning "No file path provided"
            return
        }
        
        # Validate file exists
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Write-Warning "File not found: $filePath"
            $errorCount++
            return
        }
        
        try {
            # Read current tags
            Write-Verbose "Reading current tags from: $(Split-Path $filePath -Leaf)"
            $currentTags = Get-AudioFileTags -Path $filePath
            
            if (-not $currentTags) {
                Write-Warning "Could not read tags from: $(Split-Path $filePath -Leaf)"
                $errorCount++
                return
            }
            
            # Determine new tag values based on parameter set
            $newTags = switch ($PSCmdlet.ParameterSetName) {
                'Simple' {
                    # Apply hashtable updates to current tags
                    $updated = $currentTags
                    foreach ($key in $Tags.Keys) {
                        if ($updated.PSObject.Properties.Name -contains $key) {
                            $updated.$key = $Tags[$key]
                        } else {
                            Write-Warning "Property '$key' does not exist on tag object"
                        }
                    }
                    $updated
                }
                'Pipeline' {
                    # Use modified tags from pipeline, optionally apply additional hashtable updates
                    if ($Tags) {
                        $updated = $InputObject
                        foreach ($key in $Tags.Keys) {
                            if ($updated.PSObject.Properties.Name -contains $key) {
                                $updated.$key = $Tags[$key]
                            }
                        }
                        $updated
                    } else {
                        $InputObject
                    }
                }
                'Transform' {
                    # Execute transform scriptblock with current tags as context
                    $Transform.InvokeWithContext($null, [psvariable]::new('_', $currentTags), $currentTags)
                }
            }
            
            # Build list of changes
            $changes = @()
            $readOnlyProps = @('Path', 'FileName', 'Format', 'Duration', 'DurationSeconds', 'Bitrate', 'SampleRate', 
                              'IsClassical', 'ContributingArtists', 'Conductor', 'SuggestedAlbumArtist')
            
            foreach ($prop in $newTags.PSObject.Properties) {
                $propName = $prop.Name
                $newValue = $prop.Value
                $oldValue = $currentTags.$propName
                
                # Skip read-only properties
                if ($propName -in $readOnlyProps) {
                    continue
                }
                
                # Detect changes
                if ($newValue -ne $oldValue) {
                    # Handle array comparison
                    if ($newValue -is [array] -and $oldValue -is [array]) {
                        if (($newValue -join ',') -ne ($oldValue -join ',')) {
                            $changes += @{
                                Property = $propName
                                OldValue = $oldValue
                                NewValue = $newValue
                            }
                        }
                    } else {
                        $changes += @{
                            Property = $propName
                            OldValue = $oldValue
                            NewValue = $newValue
                        }
                    }
                }
            }
            
            if ($changes.Count -eq 0) {
                Write-Verbose "No changes needed for: $(Split-Path $filePath -Leaf)"
                $processedCount++
                
                if ($PassThru) {
                    $results += $currentTags
                }
                return
            }
            
            # Confirm changes
            $changeDescription = "Update $($changes.Count) tag(s) in '$(Split-Path $filePath -Leaf)'"
            if ($Force -or $PSCmdlet.ShouldProcess($filePath, $changeDescription)) {
                # Write tags using TagLib-Sharp
                Write-Verbose "Writing tags to: $(Split-Path $filePath -Leaf)"
                
                $fileObj = [TagLib.File]::Create($filePath)
                try {
                    $tag = $fileObj.Tag
                    
                    # Apply changes
                    foreach ($change in $changes) {
                        $propName = $change.Property
                        $newValue = $change.NewValue
                        
                        Write-Verbose "  $propName: '$($change.OldValue)' -> '$newValue'"
                        
                        # Map common property names to TagLib properties
                        switch ($propName) {
                            'Title' { $tag.Title = $newValue }
                            'Artist' { 
                                if ($newValue) {
                                    $tag.Performers = @($newValue)
                                }
                            }
                            'Artists' { 
                                if ($newValue) {
                                    $tag.Performers = $newValue
                                }
                            }
                            'AlbumArtist' { 
                                if ($newValue) {
                                    $tag.AlbumArtists = @($newValue)
                                }
                            }
                            'AlbumArtists' { 
                                if ($newValue) {
                                    $tag.AlbumArtists = $newValue
                                }
                            }
                            'Album' { $tag.Album = $newValue }
                            'Year' { 
                                if ($newValue) {
                                    $tag.Year = [uint32]$newValue
                                } else {
                                    $tag.Year = 0
                                }
                            }
                            'Track' { 
                                if ($newValue) {
                                    $tag.Track = [uint32]$newValue
                                } else {
                                    $tag.Track = 0
                                }
                            }
                            'TrackCount' { 
                                if ($newValue) {
                                    $tag.TrackCount = [uint32]$newValue
                                } else {
                                    $tag.TrackCount = 0
                                }
                            }
                            'Disc' { 
                                if ($newValue) {
                                    $tag.Disc = [uint32]$newValue
                                } else {
                                    $tag.Disc = 0
                                }
                            }
                            'DiscCount' { 
                                if ($newValue) {
                                    $tag.DiscCount = [uint32]$newValue
                                } else {
                                    $tag.DiscCount = 0
                                }
                            }
                            'Genre' { 
                                if ($newValue) {
                                    $tag.Genres = @($newValue)
                                } else {
                                    $tag.Genres = @()
                                }
                            }
                            'Genres' { 
                                if ($newValue) {
                                    $tag.Genres = $newValue
                                } else {
                                    $tag.Genres = @()
                                }
                            }
                            'Composer' { 
                                if ($newValue) {
                                    $tag.Composers = @($newValue)
                                } else {
                                    $tag.Composers = @()
                                }
                            }
                            'Composers' { 
                                if ($newValue) {
                                    $tag.Composers = $newValue
                                } else {
                                    $tag.Composers = @()
                                }
                            }
                            default {
                                Write-Verbose "  Skipping unknown or read-only property: $propName"
                            }
                        }
                    }
                    
                    # Save changes
                    if (-not $WhatIfPreference) {
                        $fileObj.Save()
                        Write-Verbose "Successfully updated: $(Split-Path $filePath -Leaf)"
                    } else {
                        Write-Host "What if: Performing the operation `"Update tags`" on target `"$(Split-Path $filePath -Leaf)`"." -ForegroundColor Yellow
                    }
                    
                    $processedCount++
                    
                    # Return updated tags if requested
                    if ($PassThru) {
                        if (-not $WhatIfPreference) {
                            $updatedTags = Get-AudioFileTags -Path $filePath
                            $results += $updatedTags
                        } else {
                            # In WhatIf mode, return the proposed tags
                            $results += $newTags
                        }
                    }
                    
                } finally {
                    $fileObj.Dispose()
                }
            } else {
                Write-Verbose "Skipped (user declined): $(Split-Path $filePath -Leaf)"
            }
            
        } catch {
            $errorCount++
            Write-Error "Failed to update tags for '$(Split-Path $filePath -Leaf)': $($_.Exception.Message)"
        }
    }
    
    end {
        # Summary
        if ($processedCount -gt 0 -or $errorCount -gt 0) {
            $verb = if ($WhatIfPreference) { "would be updated" } else { "updated" }
            Write-Verbose "Tag update complete: $processedCount files $verb, $errorCount errors"
            
            if (-not $WhatIfPreference -and $processedCount -gt 0) {
                Write-Host "✓ Successfully updated $processedCount file(s)" -ForegroundColor Green
            }
        }
        
        # Return results if PassThru
        if ($PassThru) {
            return $results
        }
    }
}
