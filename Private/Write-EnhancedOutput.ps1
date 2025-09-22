function Write-DurationMismatchWarning {
<#
.SYNOPSIS
    Display duration mismatch warnings with clickable file paths.

.DESCRIPTION
    Creates user-friendly warnings for duration discrepancies with clickable file paths
    for easy navigation in modern terminals (Windows Terminal, VS Code, etc.).
    Uses both absolute and percentage differences for context.

.PARAMETER FilePath
    Full path to the audio file with duration mismatch.

.PARAMETER ActualDuration
    The duration found in the audio file.

.PARAMETER ExpectedDuration
    The expected duration (e.g., from Spotify).

.PARAMETER TrackTitle
    The track title for context.

.PARAMETER DifferenceSeconds
    The difference in seconds between actual and expected.

.PARAMETER PercentDifference
    The percentage difference relative to track length.

.PARAMETER TrackLength
    Category: Short, Normal, Long, Epic.

.EXAMPLE
    Write-DurationMismatchWarning -FilePath "C:\Music\Album\track.mp3" -ActualDuration "4:57" -ExpectedDuration "4:23" -TrackTitle "Hotel" -DifferenceSeconds 34 -PercentDifference 12.5 -TrackLength "Normal"

.NOTES
    Supports clickable paths in Windows Terminal, VS Code Terminal, and other modern terminals.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ActualDuration,
        
        [Parameter(Mandatory = $true)]
        [string]$ExpectedDuration,
        
        [Parameter(Mandatory = $true)]
        [string]$TrackTitle,
        
        [Parameter(Mandatory = $true)]
        [int]$DifferenceSeconds,
        
        [double]$PercentDifference = 0,
        
        [string]$TrackLength = "Normal"
    )
    
    # Determine severity based on percentage difference (more intelligent)
    $severity = if ($PercentDifference -gt 15) { "HIGH" } 
                elseif ($PercentDifference -gt 8) { "MEDIUM" } 
                elseif ($PercentDifference -gt 3) { "LOW" }
                else { "MINIMAL" }
    
    $severityColor = switch ($severity) {
        "HIGH" { "Red" }
        "MEDIUM" { "Yellow" } 
        "LOW" { "Cyan" }
        "MINIMAL" { "Green" }
    }
    
    # Track length context emoji
    $lengthEmoji = switch ($TrackLength) {
        "Short" { "⚡" }
        "Normal" { "🎵" }
        "Long" { "🎼" }
        "Epic" { "🎆" }
        default { "🎵" }
    }
    
    Write-Host ""
    Write-Host "⚠️  DURATION MISMATCH DETECTED [$severity] $lengthEmoji" -ForegroundColor $severityColor
    Write-Host "Track: " -NoNewline -ForegroundColor Gray
    Write-Host "`"$TrackTitle`" ($TrackLength track)" -ForegroundColor White
    Write-Host ""
    
    # Display clickable file path (works in Windows Terminal, VS Code Terminal)
    Write-Host "📁 File: " -NoNewline -ForegroundColor Gray
    Write-Host $FilePath -ForegroundColor Cyan
    
    # Alternative formats for different terminals
    if ($env:TERM_PROGRAM -eq "vscode") {
        $vscodeUri = "vscode://file/$($FilePath -replace '\\', '/')"
        Write-Host "🔗 VS Code: " -NoNewline -ForegroundColor Gray
        Write-Host $vscodeUri -ForegroundColor Blue
    }
    
    # Duration comparison with percentage context
    Write-Host ""
    Write-Host "⏱️  Duration Comparison:" -ForegroundColor Yellow
    Write-Host "   File duration:     " -NoNewline -ForegroundColor Gray
    Write-Host $ActualDuration -ForegroundColor White
    Write-Host "   Expected duration: " -NoNewline -ForegroundColor Gray  
    Write-Host $ExpectedDuration -ForegroundColor White
    Write-Host "   Absolute difference: " -NoNewline -ForegroundColor Gray
    Write-Host "$DifferenceSeconds seconds" -ForegroundColor $severityColor
    Write-Host "   Relative difference: " -NoNewline -ForegroundColor Gray
    Write-Host "$PercentDifference%" -ForegroundColor $severityColor
    
    Write-Host ""
    Write-Host "💡 Context & Suggestions:" -ForegroundColor Yellow
    
    # Track length specific advice
    switch ($TrackLength) {
        "Short" { 
            Write-Host "   • Short track: Even small differences are significant" -ForegroundColor Gray
            Write-Host "   • Check for fade-in/fade-out differences" -ForegroundColor Gray
        }
        "Epic" { 
            Write-Host "   • Long track: Some variation is normal for live recordings" -ForegroundColor Gray
            Write-Host "   • Check for extended/alternate versions" -ForegroundColor Gray
        }
        default {
            Write-Host "   • Check if this is the correct track order" -ForegroundColor Gray
            Write-Host "   • Verify the audio file isn't corrupted or edited" -ForegroundColor Gray
        }
    }
    
    Write-Host "   • Use manual workflow: " -NoNewline -ForegroundColor Gray
    Write-Host "Invoke-ManualTrackMapping" -ForegroundColor Cyan
    Write-Host ""
}

function Write-ClickableFilePath {
<#
.SYNOPSIS
    Display file paths in clickable format for modern terminals.

.DESCRIPTION
    Formats file paths to be clickable in Windows Terminal, VS Code Terminal, and other
    modern terminals that support file path clicking.

.PARAMETER Path
    The file path to display.

.PARAMETER Label
    Optional label to display before the path.

.PARAMETER Color
    Color for the file path display.

.EXAMPLE
    Write-ClickableFilePath -Path "C:\Music\track.mp3" -Label "Problem file"

.NOTES
    Works with Windows Terminal (Ctrl+Click), VS Code Terminal, and modern terminal emulators.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [string]$Label = "File",
        
        [string]$Color = "Cyan"
    )
    
    Write-Host "${Label}: " -NoNewline -ForegroundColor Gray
    Write-Host $Path -ForegroundColor $Color
    
    # Additional formats for better compatibility
    if ($env:WT_SESSION -or $env:TERM_PROGRAM -eq "vscode") {
        # These terminals support enhanced clicking
        Write-Verbose "Terminal supports clickable paths"
    }
}

function Write-TrackAnalysisResults {
<#
.SYNOPSIS
    Display comprehensive track analysis results with clickable paths.

.DESCRIPTION
    Shows track validation results including duration mismatches, tag issues,
    and other problems with clickable file paths for easy navigation.

.PARAMETER Results
    Array of track analysis results.

.EXAMPLE
    Write-TrackAnalysisResults -Results $analysisResults

.NOTES
    Designed for MuFo track validation workflows.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )
    
    $problemFiles = $Results | Where-Object { $_.HasIssues }
    $okFiles = $Results | Where-Object { -not $_.HasIssues }
    
    Write-Host "📊 TRACK ANALYSIS RESULTS" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($okFiles.Count -gt 0) {
        Write-Host "✅ Files without issues: $($okFiles.Count)" -ForegroundColor Green
        foreach ($file in $okFiles) {
            Write-Host "  ✅ " -NoNewline -ForegroundColor Green
            Write-Host "$($file.TrackTitle)" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($problemFiles.Count -gt 0) {
        Write-Host "⚠️  Files with issues: $($problemFiles.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($file in $problemFiles) {
            Write-Host "  🚨 " -NoNewline -ForegroundColor Red
            Write-Host "$($file.TrackTitle)" -ForegroundColor White
            
            # Show clickable file path
            Write-ClickableFilePath -Path $file.FilePath -Label "     📁 Location" -Color "Cyan"
            
            # Show specific issues
            foreach ($issue in $file.Issues) {
                Write-Host "     ⚠️  $issue" -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        Write-Host "🔧 Quick Actions:" -ForegroundColor Yellow
        Write-Host "  • Click file paths above to open in explorer/editor" -ForegroundColor Gray
        Write-Host "  • Use manual workflow: " -NoNewline -ForegroundColor Gray
        Write-Host "Invoke-ManualTrackMapping" -ForegroundColor Cyan
        Write-Host "  • Check individual files: " -NoNewline -ForegroundColor Gray  
        Write-Host "Get-TrackTags -Path <file>" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Functions are automatically available when dot-sourced