function Add-MemoryOptimization {
<#
.SYNOPSIS
    Adds memory monitoring and optimization for large music library processing.

.DESCRIPTION
    This function provides memory monitoring, garbage collection, and warnings for large collections
    to prevent memory issues when processing very large music libraries.

.PARAMETER AlbumCount
    Number of albums being processed.

.PARAMETER Phase
    Processing phase (Start, Progress, End).

.PARAMETER ForceCleanup
    Force garbage collection regardless of memory usage.

.OUTPUTS
    Memory usage statistics and recommendations.
#>
    [CmdletBinding()]
    param (
        [int]$AlbumCount = 0,
        [ValidateSet('Start', 'Progress', 'End')]
        [string]$Phase = 'Progress',
        [switch]$ForceCleanup
    )

    # Get current memory usage
    $memoryBefore = [GC]::GetTotalMemory($false) / 1MB
    $workingSet = (Get-Process -Id $PID).WorkingSet64 / 1MB
    
    switch ($Phase) {
        'Start' {
            Write-Verbose "Memory optimization: Starting processing for $AlbumCount albums"
            Write-Verbose "Initial memory: $([math]::Round($memoryBefore, 1)) MB managed, $([math]::Round($workingSet, 1)) MB working set"
            
            # Warn about very large collections
            if ($AlbumCount -gt 1000) {
                Write-Warning "Large collection detected ($AlbumCount albums). Consider processing in smaller batches for optimal performance."
                Write-Host "💡 Tip: Use -ConfidenceThreshold to filter results and reduce memory usage" -ForegroundColor Cyan
            }
            
            if ($AlbumCount -gt 5000) {
                Write-Warning "Very large collection ($AlbumCount albums). Memory usage will be monitored and optimized automatically."
            }
        }
        
        'Progress' {
            # Monitor memory usage during processing
            if ($workingSet -gt 1000) {  # > 1GB working set
                Write-Verbose "High memory usage detected: $([math]::Round($workingSet, 1)) MB working set"
                Write-Verbose "Performing automatic garbage collection..."
                
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                [GC]::Collect()
                
                $memoryAfter = [GC]::GetTotalMemory($false) / 1MB
                $workingSetAfter = (Get-Process -Id $PID).WorkingSet64 / 1MB
                $saved = $memoryBefore - $memoryAfter
                
                Write-Verbose "Memory cleanup: Freed $([math]::Round($saved, 1)) MB managed memory"
                Write-Verbose "Working set: $([math]::Round($workingSetAfter, 1)) MB (was $([math]::Round($workingSet, 1)) MB)"
                
                if ($saved -gt 50) {
                    Write-Host "🧹 Automatic cleanup freed $([math]::Round($saved, 1)) MB memory" -ForegroundColor Green
                }
            }
        }
        
        'End' {
            Write-Verbose "Memory optimization: Processing complete"
            
            if ($ForceCleanup -or $workingSet -gt 500) {
                Write-Verbose "Performing final cleanup..."
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                [GC]::Collect()
                
                $finalWorkingSet = (Get-Process -Id $PID).WorkingSet64 / 1MB
                Write-Verbose "Final memory usage: $([math]::Round($finalWorkingSet, 1)) MB working set"
            }
            
            # Memory usage summary
            $memoryAfter = [GC]::GetTotalMemory($false) / 1MB
            Write-Verbose "Memory summary: $([math]::Round($memoryAfter, 1)) MB managed memory used"
        }
    }
    
    # Return memory statistics
    return [PSCustomObject]@{
        Phase = $Phase
        ManagedMemoryMB = [math]::Round($memoryBefore, 1)
        WorkingSetMB = [math]::Round($workingSet, 1)
        Timestamp = Get-Date
    }
}

function Get-CollectionSizeRecommendations {
<#
.SYNOPSIS
    Provides recommendations for processing large music collections efficiently.

.PARAMETER AlbumCount
    Number of albums in the collection.

.PARAMETER IncludeTracks
    Whether track processing is enabled.

.OUTPUTS
    Performance recommendations and warnings.
#>
    [CmdletBinding()]
    param (
        [int]$AlbumCount,
        [switch]$IncludeTracks
    )

    $recommendations = @()
    $warnings = @()

    # Size-based recommendations
    if ($AlbumCount -gt 500) {
        $recommendations += "Consider using -ConfidenceThreshold 0.8 or higher to reduce processing time"
        $recommendations += "Use -ExcludeFolders to skip unnecessary directories"
    }

    if ($AlbumCount -gt 1000) {
        $warnings += "Large collection ($AlbumCount albums) - processing may take significant time"
        $recommendations += "Consider processing by artist folder instead of entire collection"
        if ($IncludeTracks) {
            $recommendations += "Track processing enabled for large collection - expect extended processing time"
        }
    }

    if ($AlbumCount -gt 2000) {
        $warnings += "Very large collection - consider batch processing in smaller chunks"
        $recommendations += "Use -WhatIf first to estimate processing time"
        $recommendations += "Ensure adequate RAM (8GB+ recommended for collections this size)"
    }

    if ($AlbumCount -gt 5000) {
        $warnings += "Extremely large collection - automatic memory optimization will be enabled"
        $recommendations += "Consider using external tools for initial organization"
        $recommendations += "Process during low-activity periods due to resource requirements"
    }

    return [PSCustomObject]@{
        AlbumCount = $AlbumCount
        Warnings = $warnings
        Recommendations = $recommendations
        EstimatedProcessingMinutes = if ($IncludeTracks) { [math]::Ceiling($AlbumCount / 10) } else { [math]::Ceiling($AlbumCount / 50) }
    }
}