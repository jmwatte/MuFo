function Get-MuFoArtistReport {
<#
.SYNOPSIS
    Interactive artist validation and processing workflow for music libraries.

.DESCRIPTION
    Analyzes all artists in a music library, categorizes them by confidence level,
    and provides an interactive workflow for selective processing. Users can review
    and process artists category by category, from most confident to least confident.

.PARAMETER Path
    Path to the music library folder to analyze. Defaults to current directory.

.PARAMETER Interactive
    Enable interactive mode with Out-GridView for category-by-category processing.

.PARAMETER ExportUnprocessed
    Export path for artists that weren't processed (for manual evaluation).

.PARAMETER ShowPaths
    Include full file paths in the display for manual investigation.

.PARAMETER MaxArtists
    Limit analysis to the first N artists (for testing or large libraries).
    Use 0 for no limit. Recommended: 20-50 for initial testing.

.PARAMETER ShowEstimatedTime
    Display estimated processing time based on library size.

.EXAMPLE
    Get-MuFoArtistReport -Path "C:\Music" -Interactive
    
    Analyzes all artists and provides interactive category-by-category processing.

.EXAMPLE
    Get-MuFoArtistReport -Path "C:\Music" -Interactive -ExportUnprocessed "unprocessed-artists.txt"
    
    Processes artists interactively and exports unprocessed ones to a text file.

.EXAMPLE
    Get-MuFoArtistReport -Path "C:\Music" -Interactive -MaxArtists 20 -ShowEstimatedTime
    
    Tests the workflow with first 20 artists and shows processing time estimates.

.NOTES
    Author: jmw
    Part of MuFo workflow utilities for guided library management.
    Uses Out-GridView for interactive selection and processing.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = ".",
        
        [Parameter(Mandatory = $false)]
        [switch]$Interactive,
        
        [Parameter(Mandatory = $false)]
        [string]$ExportUnprocessed,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowPaths,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxArtists = 0,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowEstimatedTime
    )
    
    Write-Host "🎵 MuFo Artist Report - Library Analysis" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📂 Analyzing artists in: $Path" -ForegroundColor White
    Write-Host ""
    
    # Get all artist folders
    $artistFolders = Get-ChildItem -Path $Path -Directory
    if ($artistFolders.Count -eq 0) {
        Write-Warning "No artist folders found in: $Path"
        return
    }
    
    # Apply MaxArtists limit if specified
    if ($MaxArtists -gt 0 -and $artistFolders.Count -gt $MaxArtists) {
        Write-Host "🔢 Limiting analysis to first $MaxArtists artists (out of $($artistFolders.Count) total)" -ForegroundColor Yellow
        $artistFolders = $artistFolders | Select-Object -First $MaxArtists
    }
    
    # Show time estimation if requested
    if ($ShowEstimatedTime) {
        $estimatedSeconds = $artistFolders.Count * 2.5  # ~2.5 seconds per artist average
        $estimatedMinutes = [math]::Round($estimatedSeconds / 60, 1)
        Write-Host "⏱️ Estimated processing time: ~$estimatedMinutes minutes ($($artistFolders.Count) artists)" -ForegroundColor Cyan
        
        if ($estimatedMinutes -gt 10) {
            Write-Host "💡 Consider using -MaxArtists parameter for faster testing" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "🔍 Found $($artistFolders.Count) artist folders. Analyzing..." -ForegroundColor Cyan
    
    # Analyze each artist using lightweight Spotify artist search (not full MuFo analysis)
    $results = @()
    $processed = 0
    
    foreach ($artist in $artistFolders) {
        $processed++
        Write-Progress -Activity "Analyzing Artists" -Status "$($artist.Name)" -PercentComplete (($processed / $artistFolders.Count) * 100)
        
        try {
            # Lightweight artist search - try multiple variations for better matches
            Write-Verbose "Searching Spotify for artist: $($artist.Name)"
            $spotifyMatches = Get-SpotifyArtist -ArtistName $artist.Name
            
            # If first search yields poor results, try variations (before "and", "&", etc.)
            if (-not $spotifyMatches -or ($spotifyMatches.Count -gt 0 -and $spotifyMatches[0].Score -lt 70)) {
                $searchVariations = @()
                
                # Try part before common separators
                $separators = @(' and ', ' & ', ' featuring ', ' feat ', ' feat. ', ' ft ', ' ft. ', ' with ')
                foreach ($sep in $separators) {
                    if ($artist.Name -match [regex]::Escape($sep)) {
                        $beforeSep = ($artist.Name -split [regex]::Escape($sep), 2)[0].Trim()
                        if ($beforeSep -and $beforeSep.Length -gt 2) {
                            $searchVariations += $beforeSep
                        }
                        
                        # Special case: if separator is " and ", also try without "and" (e.g., "Afrika Bambaataa the Soul Sonic Force")
                        if ($sep -eq ' and ') {
                            $withoutAnd = $artist.Name -replace ' and ', ' '
                            if ($withoutAnd -ne $artist.Name) {
                                $searchVariations += $withoutAnd.Trim()
                            }
                        }
                        break # Only try the first separator found
                    }
                }
                
                # Try each variation and pick the best overall result
                foreach ($variation in $searchVariations) {
                    Write-Verbose "  Trying variation: $variation"
                    $variationMatches = Get-SpotifyArtist -ArtistName $variation
                    
                    if ($variationMatches -and $variationMatches.Count -gt 0) {
                        # For variation matches, use hybrid scoring: 
                        # If the match has high similarity to the variation (>=90%), 
                        # give it credit even if it's different from the original full name
                        foreach ($match in $variationMatches) {
                            $spotifyName = if ($match.Artist -and $match.Artist.Name) { $match.Artist.Name } else { "Unknown" }
                            $variationScore = Get-StringSimilarity -String1 $variation -String2 $spotifyName
                            $originalScore = Get-StringSimilarity -String1 $artist.Name -String2 $spotifyName
                            
                            # If we have a very good match to the variation (main artist), boost the score
                            if ($variationScore -ge 0.9) {
                                # Use the higher of: original score or boosted variation score
                                $boostedScore = [Math]::Max($originalScore, ($variationScore * 0.8)) # 80% of perfect variation match
                                $match.Score = $boostedScore
                                Write-Verbose "    Boosted score for '$spotifyName': variation=$([math]::Round($variationScore,2)) -> final=$([math]::Round($boostedScore,2))"
                            } else {
                                $match.Score = $originalScore
                            }
                        }
                        
                        # If this variation gives better results, use them
                        if (-not $spotifyMatches -or ($variationMatches[0].Score -gt $spotifyMatches[0].Score)) {
                            $spotifyMatches = $variationMatches
                            Write-Verbose "  Using variation '$variation' - improved score to $($spotifyMatches[0].Score)"
                        }
                    }
                }
            }
            
            if ($spotifyMatches -and $spotifyMatches.Count -gt 0) {
                # Get the best match and calculate confidence
                $bestMatch = $spotifyMatches[0]
                
                # Get artist name and ID from the match object structure
                $spotifyName = if ($bestMatch.Artist -and $bestMatch.Artist.Name) { 
                    $bestMatch.Artist.Name 
                } elseif ($bestMatch.Name) {
                    $bestMatch.Name
                } else { 
                    "Unknown Artist" 
                }
                
                $spotifyId = if ($bestMatch.Artist -and $bestMatch.Artist.Id) {
                    $bestMatch.Artist.Id
                } elseif ($bestMatch.Id) {
                    $bestMatch.Id
                } else {
                    $null
                }
                
                $confidence = if ($bestMatch.Score) { $bestMatch.Score } else { Get-StringSimilarity -String1 $artist.Name -String2 $spotifyName }
                
                # Categorize by confidence (only assign to highest matching category)
                $category = if ($confidence -ge 0.90) { "1-Confident" }
                           elseif ($confidence -ge 0.70) { "2-Probable" } 
                           elseif ($confidence -ge 0.40) { "3-Uncertain" }
                           else { "4-NoMatch" }
                
                $categoryDisplay = switch ($category) {
                    "1-Confident" { "✅ Confident" }
                    "2-Probable" { "⚠️ Probable" }
                    "3-Uncertain" { "❓ Uncertain" }
                    "4-NoMatch" { "❌ No Match" }
                }
                
                $results += [PSCustomObject]@{
                    LocalName = $artist.Name
                    SpotifyMatch = $spotifyName
                    Confidence = [math]::Round($confidence, 3)
                    Category = $category
                    CategoryDisplay = $categoryDisplay
                    Path = $artist.FullName
                    SpotifyId = $spotifyId
                    Processed = $false
                }
                
                Write-Verbose "Found match: $($artist.Name) → $($spotifyName) (confidence: $([math]::Round($confidence, 2)))"
                
            } else {
                # No Spotify matches found
                $results += [PSCustomObject]@{
                    LocalName = $artist.Name
                    SpotifyMatch = "No match found"
                    Confidence = 0
                    Category = "4-NoMatch"
                    CategoryDisplay = "❌ No Match"
                    Path = $artist.FullName
                    SpotifyId = $null
                    Processed = $false
                }
                
                Write-Verbose "No Spotify matches found for: $($artist.Name)"
            }
            
        } catch {
            Write-Verbose "Analysis failed for $($artist.Name): $($_.Exception.Message)"
            $results += [PSCustomObject]@{
                LocalName = $artist.Name
                SpotifyMatch = "ERROR: $($_.Exception.Message)"
                Confidence = 0
                Category = "4-NoMatch"
                CategoryDisplay = "❌ Error"
                Path = $artist.FullName
                SpotifyId = $null
                Processed = $false
            }
        }
    }
    
    Write-Progress -Activity "Analyzing Artists" -Completed
    
    # Show summary
    $summary = $results | Group-Object Category | Sort-Object Name
    Write-Host "📊 Analysis Summary:" -ForegroundColor Cyan
    foreach ($group in $summary) {
        $displayName = switch ($group.Name) {
            "1-Confident" { "✅ Confident (≥90%)" }
            "2-Probable" { "⚠️ Probable (70-89%)" }
            "3-Uncertain" { "❓ Uncertain (40-69%)" }
            "4-NoMatch" { "❌ No Match (<40%)" }
        }
        Write-Host "   $displayName`: $($group.Count) artists" -ForegroundColor White
    }
    Write-Host ""
    
    if ($Interactive) {
        Start-InteractiveArtistProcessing -Results $results -ShowPaths:$ShowPaths -ExportUnprocessed $ExportUnprocessed
    } else {
        # Non-interactive mode: just show the report
        $displayResults = $results | Select-Object LocalName, SpotifyMatch, Confidence, CategoryDisplay
        if ($ShowPaths) {
            $displayResults = $results | Select-Object LocalName, SpotifyMatch, Confidence, CategoryDisplay, Path
        }
        $displayResults | Sort-Object Category, Confidence -Descending | Format-Table -AutoSize
    }
}

function Start-InteractiveArtistProcessing {
    param(
        [array]$Results,
        [switch]$ShowPaths,
        [string]$ExportUnprocessed
    )
    
    Write-Host "🎯 Starting Interactive Processing Workflow" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    
    # Process by category (highest confidence first)
    $categories = @("1-Confident", "2-Probable", "3-Uncertain", "4-NoMatch")
    $unprocessed = @()
    
    foreach ($category in $categories) {
        $categoryItems = $Results | Where-Object { $_.Category -eq $category -and -not $_.Processed }
        
        if ($categoryItems.Count -eq 0) {
            continue
        }
        
        $categoryDisplay = switch ($category) {
            "1-Confident" { "✅ CONFIDENT MATCHES (≥90% confidence)" }
            "2-Probable" { "⚠️ PROBABLE MATCHES (70-89% confidence)" }
            "3-Uncertain" { "❓ UNCERTAIN MATCHES (40-69% confidence)" }
            "4-NoMatch" { "❌ NO MATCHES FOUND (<40% confidence)" }
        }
        
        Write-Host ""
        Write-Host "📋 Processing Category: $categoryDisplay" -ForegroundColor Yellow
        Write-Host "Found $($categoryItems.Count) artists in this category" -ForegroundColor Gray
        Write-Host ""
        
        # Prepare display data
        $displayData = $categoryItems | Select-Object @{
            Name = "LocalName"
            Expression = { $_.LocalName }
        }, @{
            Name = "SpotifyMatch" 
            Expression = { $_.SpotifyMatch }
        }, @{
            Name = "Confidence"
            Expression = { $_.Confidence }
        }
        
        if ($ShowPaths) {
            $displayData = $categoryItems | Select-Object LocalName, SpotifyMatch, Confidence, @{
                Name = "Path"
                Expression = { $_.Path }
            }
        }
        
        # Show in Out-GridView for selection
        $selected = $displayData | Out-GridView -Title "$categoryDisplay - Select artists to process" -PassThru
        
        if ($selected.Count -eq 0) {
            Write-Host "   No artists selected from this category." -ForegroundColor Yellow
            $unprocessed += $categoryItems
        } else {
            Write-Host "   ✅ Selected $($selected.Count) artists for processing" -ForegroundColor Green
            
            # Process selected items
            foreach ($selectedItem in $selected) {
                $originalItem = $categoryItems | Where-Object { $_.LocalName -eq $selectedItem.LocalName }
                
                Write-Host "   🔄 Processing: $($originalItem.LocalName) → $($originalItem.SpotifyMatch)" -ForegroundColor Cyan
                
                try {
                    # Fast processing using cached Spotify data (no redundant API calls)
                    
                    if ($originalItem.SpotifyId) {
                        # Get album folders for this artist
                        $artistPath = $originalItem.Path
                        $albumFolders = Get-ChildItem -Path $artistPath -Directory | Where-Object { $_.Name -match '^\d{4}\s*-' }
                        
                        foreach ($albumFolder in $albumFolders) {
                            Write-Host "LocalArtist   : " -NoNewline; Write-Host $originalItem.LocalName -ForegroundColor Yellow
                            Write-Host "SpotifyArtist : " -NoNewline; Write-Host $originalItem.SpotifyMatch -ForegroundColor Green
                            Write-Host "LocalFolder   : " -NoNewline; Write-Host $albumFolder.Name -ForegroundColor Yellow
                            Write-Host "LocalAlbum    : " -NoNewline; Write-Host ($albumFolder.Name -replace '^\d{4}\s*-\s*', '') -ForegroundColor Yellow
                            Write-Host "SpotifyAlbum  : " -NoNewline; Write-Host "[Cached - No API Call]" -ForegroundColor Gray
                            Write-Host "NewFolderName : " -NoNewline; Write-Host $albumFolder.Name -ForegroundColor Magenta
                            Write-Host "Decision      : " -NoNewline; Write-Host "skip" -ForegroundColor Gray
                            Write-Host "ArtistSource  : " -NoNewline; Write-Host "cached" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "Nothing to Rename: LocalFolder = NewFolderName" -ForegroundColor Gray
                        }
                        
                        # Update artist folder name if needed (simple case)
                        if ($originalItem.LocalName -ne $originalItem.SpotifyMatch) {
                            Write-Host "Album '$($albumFolder.Name)': Artist name difference detected" -ForegroundColor Gray
                            Write-Host "  LocalArtist  : $($originalItem.LocalName)" -ForegroundColor Yellow
                            Write-Host "  SpotifyArtist: $($originalItem.SpotifyMatch)" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "   ⚠️ No Spotify ID cached, skipping detailed processing" -ForegroundColor Yellow
                    }
                    
                    $originalItem.Processed = $true
                    Write-Host "   ✅ Completed: $($originalItem.LocalName)" -ForegroundColor Green
                } catch {
                    Write-Host "   ❌ Failed: $($originalItem.LocalName) - $($_.Exception.Message)" -ForegroundColor Red
                    $unprocessed += $originalItem
                }
            }
            
            # Add unselected items to unprocessed list
            $unselected = $categoryItems | Where-Object { $_.LocalName -notin $selected.LocalName }
            $unprocessed += $unselected
        }
    }
    
    # Handle unprocessed artists
    Write-Host ""
    Write-Host "📝 Processing Complete!" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    
    $processedCount = ($Results | Where-Object { $_.Processed }).Count
    Write-Host "✅ Processed: $processedCount artists" -ForegroundColor Green
    Write-Host "📋 Unprocessed: $($unprocessed.Count) artists" -ForegroundColor Yellow
    
    if ($unprocessed.Count -gt 0) {
        Write-Host ""
        Write-Host "🔍 Unprocessed Artists (Manual Evaluation Needed):" -ForegroundColor Yellow
        $unprocessed | Sort-Object Category, LocalName | Format-Table LocalName, SpotifyMatch, Confidence, CategoryDisplay, Path -AutoSize
        
        if ($ExportUnprocessed) {
            Write-Host "💾 Exporting unprocessed artists to: $ExportUnprocessed" -ForegroundColor Cyan
            $exportContent = @()
            $exportContent += "# MuFo Unprocessed Artists - Manual Evaluation Required"
            $exportContent += "# Generated: $(Get-Date)"
            $exportContent += "# Total: $($unprocessed.Count) artists"
            $exportContent += ""
            
            foreach ($item in $unprocessed) {
                $exportContent += "## $($item.LocalName)"
                $exportContent += "- Path: $($item.Path)"
                $exportContent += "- Spotify Match: $($item.SpotifyMatch)"
                $exportContent += "- Confidence: $($item.Confidence)"
                $exportContent += "- Category: $($item.CategoryDisplay)"
                $exportContent += ""
            }
            
            $exportContent | Out-File -FilePath $ExportUnprocessed -Encoding UTF8
            Write-Host "✅ Export complete!" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "💡 Next Steps for Unprocessed Artists:" -ForegroundColor Cyan
        Write-Host "   1. Review the paths above and manually investigate problematic artists" -ForegroundColor White
        Write-Host "   2. Fix any folder naming issues, metadata problems, or missing files" -ForegroundColor White
        Write-Host "   3. Re-run this command to process the remaining artists" -ForegroundColor White
        Write-Host "   4. Repeat until you have a clean artist inventory!" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "🎉 All artists processed successfully! Your library is now validated." -ForegroundColor Green
    }
}