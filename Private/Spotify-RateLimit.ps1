function Invoke-SpotifyCall-Enhanced {
<#
.SYNOPSIS
    Enhanced Spotify API caller with intelligent rate limiting and retry logic.

.DESCRIPTION
    Wraps Spotishell calls with:
    - Intelligent throttling (configurable delays)
    - Retry logic with exponential backoff
    - Respect for Retry-After headers
    - Batch operation support
    - Call frequency monitoring

.PARAMETER ScriptBlock
    The Spotishell command to execute (e.g., { Search-Item -Type Artist -Query $term })

.PARAMETER MaxRetries
    Maximum number of retries for rate-limited requests (default 3)

.PARAMETER BaseDelay
    Base delay between calls in milliseconds (default 100ms)

.PARAMETER AdaptiveThrottling
    Enable adaptive throttling based on response times (default true)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 3,
        [int]$BaseDelay = 100,
        [switch]$AdaptiveThrottling
    )

    # Static variables to track call frequency and adapt
    if (-not $script:SpotifyCallStats) {
        $script:SpotifyCallStats = @{
            LastCallTime = Get-Date
            AverageResponseTime = 500
            ConsecutiveSlowCalls = 0
            CallCount = 0
        }
    }

    $attempt = 0
    $delay = $BaseDelay

    while ($attempt -le $MaxRetries) {
        $attempt++
        
        # Implement intelligent delay before call
        if ($attempt -gt 1 -or $script:SpotifyCallStats.CallCount -gt 0) {
            $timeSinceLastCall = (Get-Date) - $script:SpotifyCallStats.LastCallTime
            
            if ($AdaptiveThrottling) {
                # Adaptive delay based on recent performance
                if ($script:SpotifyCallStats.ConsecutiveSlowCalls -gt 3) {
                    $delay = $BaseDelay * 3  # Slow down significantly
                } elseif ($script:SpotifyCallStats.AverageResponseTime -gt 1000) {
                    $delay = $BaseDelay * 2  # Moderate slowdown
                }
            }
            
            if ($timeSinceLastCall.TotalMilliseconds -lt $delay) {
                $sleepTime = $delay - $timeSinceLastCall.TotalMilliseconds
                Write-Verbose "Rate limiting: Sleeping for $([math]::Round($sleepTime))ms"
                Start-Sleep -Milliseconds $sleepTime
            }
        }

        $script:SpotifyCallStats.LastCallTime = Get-Date
        $callStart = Get-Date

        try {
            Write-Verbose "Spotify API call attempt $attempt"
            $result = & $ScriptBlock
            $callEnd = Get-Date
            
            # Update performance stats
            $responseTime = ($callEnd - $callStart).TotalMilliseconds
            $script:SpotifyCallStats.AverageResponseTime = 
                ($script:SpotifyCallStats.AverageResponseTime * 0.8) + ($responseTime * 0.2)
            
            if ($responseTime -gt 1000) {
                $script:SpotifyCallStats.ConsecutiveSlowCalls++
            } else {
                $script:SpotifyCallStats.ConsecutiveSlowCalls = 0
            }
            
            $script:SpotifyCallStats.CallCount++
            
            Write-Verbose "Call successful in $([math]::Round($responseTime))ms (avg: $([math]::Round($script:SpotifyCallStats.AverageResponseTime))ms)"
            return $result

        } catch {
            $callEnd = Get-Date
            $responseTime = ($callEnd - $callStart).TotalMilliseconds
            
            # Check for rate limiting (429 status)
            if ($_.Exception.Message -match "429|rate.?limit|too.?many.?requests") {
                Write-Warning "Rate limit hit on attempt $attempt"
                
                # Try to extract Retry-After header value
                $retryAfter = 60 # Default to 60 seconds if no header
                if ($_.Exception.Message -match "retry.?after[:\s]*(\d+)") {
                    $retryAfter = [int]$matches[1]
                }
                
                if ($attempt -le $MaxRetries) {
                    $backoffDelay = [math]::Min($retryAfter * 1000, 60000) # Max 60 seconds
                    Write-Warning "Waiting $backoffDelay ms before retry (Retry-After: $retryAfter seconds)"
                    Start-Sleep -Milliseconds $backoffDelay
                    continue
                }
            }
            
            # For non-429 errors or max retries exceeded, rethrow
            Write-Verbose "Call failed after $([math]::Round($responseTime))ms: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SpotifyArtist-Throttled {
<#
.SYNOPSIS
    Rate-limited version of Get-SpotifyArtist with intelligent throttling.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ArtistName,

        [Parameter(Mandatory = $false)]
        [double]$MatchThreshold = 0.8,

        [int]$ThrottleMs = 100
    )

    $result = Invoke-SpotifyCall-Enhanced -AdaptiveThrottling -BaseDelay $ThrottleMs {
        Get-SpotifyArtist -ArtistName $ArtistName -MatchThreshold $MatchThreshold
    }
    
    return $result
}

function Search-Spotify-Batch {
<#
.SYNOPSIS
    Batch Spotify searches with intelligent rate limiting.

.DESCRIPTION
    Processes multiple search terms with proper throttling between calls.
    Useful for processing large artist lists efficiently.

.PARAMETER SearchTerms
    Array of search terms to process

.PARAMETER SearchType
    Type of search (Artist, Album, Track, etc.)

.PARAMETER BatchDelay
    Delay between batches in milliseconds (default 200ms)

.PARAMETER ShowProgress
    Show progress bar for large batches
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SearchTerms,
        
        [Parameter(Mandatory)]
        [ValidateSet('Artist', 'Album', 'Track', 'All')]
        [string]$SearchType,
        
        [int]$BatchDelay = 200,
        [switch]$ShowProgress
    )

    $results = @()
    $total = $SearchTerms.Count
    
    for ($i = 0; $i -lt $total; $i++) {
        $term = $SearchTerms[$i]
        
        if ($ShowProgress) {
            $percentComplete = [math]::Round(($i / $total) * 100, 1)
            Write-Progress -Activity "Batch Spotify Search" -Status "Processing: $term" -PercentComplete $percentComplete
        }
        
        try {
            $result = Invoke-SpotifyCall-Enhanced -BaseDelay $BatchDelay -AdaptiveThrottling {
                Search-Item -Type $SearchType -Query $term
            }
            
            $results += [PSCustomObject]@{
                SearchTerm = $term
                Success = $true
                Result = $result
                Index = $i
            }
            
            Write-Verbose "✅ Processed: $term"
            
        } catch {
            $results += [PSCustomObject]@{
                SearchTerm = $term
                Success = $false
                Result = $null
                Error = $_.Exception.Message
                Index = $i
            }
            
            Write-Warning "❌ Failed: $term - $($_.Exception.Message)"
        }
    }
    
    if ($ShowProgress) {
        Write-Progress -Activity "Batch Spotify Search" -Completed
    }
    
    Write-Verbose "Batch complete: $(($results | Where-Object Success).Count)/$total successful"
    return $results
}

<# Export-ModuleMember -Function @(
    'Invoke-SpotifyCall-Enhanced',
    'Get-SpotifyArtist-Throttled', 
    'Search-Spotify-Batch'
) #>