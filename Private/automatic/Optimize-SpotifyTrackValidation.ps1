function Optimize-SpotifyTrackValidation {
<#
.SYNOPSIS
    Optimized batch processing for Spotify track validation with rate limiting and caching.

.DESCRIPTION
    This function provides efficient batch processing of Spotify track validation for large collections.
    It includes rate limiting to respect Spotify API limits, caching to avoid duplicate calls,
    and optimized track matching algorithms.

.PARAMETER Comparisons
    Array of album comparison objects to process.

.PARAMETER BatchSize
    Number of albums to process in each batch (default: 10).

.PARAMETER DelayMs
    Delay between batches in milliseconds (default: 1000 for rate limiting).

.PARAMETER ShowProgress
    Display progress bar for large collections.

.OUTPUTS
    Enhanced comparison objects with optimized Spotify track information.

.NOTES
    Respects Spotify API rate limits and provides efficient processing for large collections.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$Comparisons,
        
        [int]$BatchSize = 10,
        
        [int]$DelayMs = 1000,
        
        [switch]$ShowProgress
    )

    begin {
        # Cache for Spotify album tracks to avoid duplicate API calls
        $spotifyTrackCache = @{}
        
        # Statistics tracking
        $totalProcessed = 0
        $cacheHits = 0
        $apiCalls = 0
        $startTime = Get-Date
        
        Write-Verbose "Starting optimized Spotify track validation for $($Comparisons.Count) albums"
        Write-Verbose "Batch size: $BatchSize, Delay: ${DelayMs}ms"
    }

    process {
        # Filter comparisons that need Spotify track information
        $needsValidation = $Comparisons | Where-Object { 
            $_.MatchedItem -and $_.MatchedItem.Item -and $_.MatchedItem.Item.Id -and $_.MatchScore -gt 0.6
        }
        
        if ($needsValidation.Count -eq 0) {
            Write-Verbose "No albums require Spotify track validation"
            return $Comparisons
        }
        
        Write-Verbose "Processing $($needsValidation.Count) albums that need Spotify track validation"
        
        # Process in batches to respect API rate limits
        $batches = for ($i = 0; $i -lt $needsValidation.Count; $i += $BatchSize) {
            $needsValidation[$i..[math]::Min($i + $BatchSize - 1, $needsValidation.Count - 1)]
        }
        
        $batchNumber = 0
        foreach ($batch in $batches) {
            $batchNumber++
            
            # Show progress for large collections
            if ($ShowProgress -and $batches.Count -gt 1) {
                $percentComplete = [math]::Round(($batchNumber / $batches.Count) * 100, 1)
                Write-Progress -Activity "Optimizing Spotify Track Validation" `
                              -Status "Processing batch $batchNumber of $($batches.Count) ($percentComplete%)" `
                              -CurrentOperation "Validating tracks for $($batch.Count) albums" `
                              -PercentComplete $percentComplete
            }
            
            # Process each album in the current batch
            foreach ($comparison in $batch) {
                $totalProcessed++
                $albumId = $comparison.MatchedItem.Item.Id
                
                try {
                    # Check cache first
                    if ($spotifyTrackCache.ContainsKey($albumId)) {
                        $spotifyTracks = $spotifyTrackCache[$albumId]
                        $cacheHits++
                        Write-Verbose "Cache hit for album ID: $albumId"
                    } else {
                        # Make API call and cache result
                        Write-Verbose "Fetching tracks for album ID: $albumId"
                        $spotifyTracks = Get-SpotifyAlbumTracks -AlbumId $albumId -ErrorAction SilentlyContinue
                        if (-not $spotifyTracks) { $spotifyTracks = @() }
                        $spotifyTrackCache[$albumId] = $spotifyTracks
                        $apiCalls++
                    }
                    
                    # Add optimized track information
                    $comparison | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue $spotifyTracks.Count -Force
                    $comparison | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue $spotifyTracks -Force
                    
                    # Calculate track mismatches if local tracks are available
                    if ($comparison.TrackCountLocal -gt 0 -and $spotifyTracks.Count -gt 0) {
                        $mismatches = Get-OptimizedTrackMismatches -LocalTracks $comparison.Tracks -SpotifyTracks $spotifyTracks
                        $comparison | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue $mismatches -Force
                    } else {
                        $comparison | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue 0 -Force
                    }
                    
                } catch {
                    Write-Warning "Failed to process Spotify tracks for album '$($comparison.LocalAlbum)': $($_.Exception.Message)"
                    $comparison | Add-Member -NotePropertyName TrackCountSpotify -NotePropertyValue 0 -Force
                    $comparison | Add-Member -NotePropertyName SpotifyTracks -NotePropertyValue @() -Force
                    $comparison | Add-Member -NotePropertyName TracksMismatchedToSpotify -NotePropertyValue 0 -Force
                }
            }
            
            # Rate limiting: pause between batches (except for the last batch)
            if ($batchNumber -lt $batches.Count -and $DelayMs -gt 0) {
                Write-Verbose "Rate limiting: waiting ${DelayMs}ms before next batch"
                Start-Sleep -Milliseconds $DelayMs
            }
        }
        
        # Clear progress display
        if ($ShowProgress -and $batches.Count -gt 1) {
            Write-Progress -Activity "Optimizing Spotify Track Validation" -Completed
        }
    }

    end {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $cacheHitRate = if ($totalProcessed -gt 0) { [math]::Round(($cacheHits / $totalProcessed) * 100, 1) } else { 0 }
        
        Write-Verbose "Optimization complete: $totalProcessed albums processed in $([math]::Round($duration.TotalSeconds, 1))s"
        Write-Verbose "API efficiency: $apiCalls API calls, $cacheHits cache hits ($cacheHitRate% cache hit rate)"
        Write-Host "✓ Spotify track validation optimized: $totalProcessed albums, $cacheHitRate% cache hit rate" -ForegroundColor Green
        
        return $Comparisons
    }
}

function Get-OptimizedTrackMismatches {
<#
.SYNOPSIS
    Optimized algorithm for calculating track mismatches between local and Spotify tracks.

.DESCRIPTION
    Uses improved string similarity and fuzzy matching to efficiently compare track titles.

.PARAMETER LocalTracks
    Array of local track objects.

.PARAMETER SpotifyTracks
    Array of Spotify track objects.

.OUTPUTS
    Number of mismatched tracks.
#>
    [CmdletBinding()]
    param (
        [array]$LocalTracks,
        [array]$SpotifyTracks
    )

    if (-not $LocalTracks -or -not $SpotifyTracks -or $LocalTracks.Count -eq 0 -or $SpotifyTracks.Count -eq 0) {
        return 0
    }

    $mismatches = 0
    $threshold = 0.8

    # Create lookup dictionary for faster Spotify track searching
    $spotifyLookup = @{}
    foreach ($spotifyTrack in $SpotifyTracks) {
        $normalizedTitle = $spotifyTrack.Name.ToLower().Trim()
        if (-not $spotifyLookup.ContainsKey($normalizedTitle)) {
            $spotifyLookup[$normalizedTitle] = @()
        }
        $spotifyLookup[$normalizedTitle] += $spotifyTrack
    }

    foreach ($localTrack in $LocalTracks) {
        if (-not $localTrack.Title) { continue }
        
        $localTitle = $localTrack.Title.ToLower().Trim()
        $bestScore = 0
        
        # First try exact match for performance
        if ($spotifyLookup.ContainsKey($localTitle)) {
            $bestScore = 1.0
        } else {
            # Fuzzy matching for non-exact matches
            foreach ($spotifyTrack in $SpotifyTracks) {
                $score = Get-StringSimilarity -String1 $localTrack.Title -String2 $spotifyTrack.Name
                if ($score -gt $bestScore) { 
                    $bestScore = $score 
                    # Early exit if we find a very good match
                    if ($score -ge 0.95) { break }
                }
            }
        }
        
        if ($bestScore -lt $threshold) { 
            $mismatches++ 
        }
    }

    return $mismatches
}