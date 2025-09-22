# Real-World Duration Analysis
# Analyzes actual albums from corrected library to establish data-driven tolerance thresholds

param(
    [string]$LibraryPath = "D:\_CorrectedMusic",
    [int]$MaxAlbums = 20,
    [switch]$IncludePinkFloyd,
    [switch]$ShowDetailed,
    [string]$OutputFile = "duration-analysis-results.json"
)

Write-Host "🔬 Real-World Duration Analysis" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Analyzing corrected music library for duration patterns..." -ForegroundColor Gray
Write-Host ""

# Load MuFo and functions
$moduleRoot = Split-Path $PSScriptRoot -Parent
if (Get-Module MuFo) { Remove-Module MuFo -Force }
Import-Module "$moduleRoot\MuFo.psd1" -Force

if (-not (Test-Path $LibraryPath)) {
    Write-Host "❌ Library path not found: $LibraryPath" -ForegroundColor Red
    return
}

# Get artist folders
Write-Host "📁 Scanning library structure..." -ForegroundColor Yellow
$artistFolders = Get-ChildItem $LibraryPath -Directory | Sort-Object Name

Write-Host "Found $($artistFolders.Count) artists in library" -ForegroundColor Green

# Prioritize interesting artists for analysis
$priorityArtists = @(
    "Pink Floyd",
    "10cc", 
    "The Beatles",
    "Led Zeppelin",
    "Rush",
    "Yes",
    "King Crimson",
    "Genesis",
    "Jethro Tull",
    "Classical",
    "Mozart",
    "Bach",
    "Beethoven"
)

# Find albums to analyze
$albumsToAnalyze = @()
$foundArtists = @()

# First, look for priority artists
foreach ($priority in $priorityArtists) {
    $matchingArtist = $artistFolders | Where-Object { $_.Name -like "*$priority*" } | Select-Object -First 1
    if ($matchingArtist) {
        $foundArtists += $matchingArtist.Name
        $albumFolders = Get-ChildItem $matchingArtist.FullName -Directory | Select-Object -First 2
        foreach ($album in $albumFolders) {
            $albumsToAnalyze += @{
                Artist = $matchingArtist.Name
                Album = $album.Name
                Path = $album.FullName
                Priority = $true
            }
        }
    }
}

# Add random albums to reach MaxAlbums
$remainingSlots = $MaxAlbums - $albumsToAnalyze.Count
if ($remainingSlots -gt 0) {
    $randomArtists = $artistFolders | Where-Object { $_.Name -notin $foundArtists } | Get-Random -Count ([Math]::Min($remainingSlots, $artistFolders.Count - $foundArtists.Count))
    foreach ($randomArtist in $randomArtists) {
        $albumFolders = Get-ChildItem $randomArtist.FullName -Directory | Select-Object -First 1
        foreach ($album in $albumFolders) {
            $albumsToAnalyze += @{
                Artist = $randomArtist.Name
                Album = $album.Name  
                Path = $album.FullName
                Priority = $false
            }
        }
    }
}

$albumsToAnalyze = $albumsToAnalyze | Select-Object -First $MaxAlbums

Write-Host "📊 Selected $($albumsToAnalyze.Count) albums for analysis:" -ForegroundColor Cyan
foreach ($album in $albumsToAnalyze) {
    $priority = if ($album.Priority) { "⭐" } else { "  " }
    Write-Host "$priority $($album.Artist) - $($album.Album)" -ForegroundColor $(if ($album.Priority) { "Yellow" } else { "Gray" })
}
Write-Host ""

# Analyze each album
$analysisResults = @()
$allTracks = @()
$albumCount = 0

foreach ($album in $albumsToAnalyze) {
    $albumCount++
    Write-Host "🎵 [$albumCount/$($albumsToAnalyze.Count)] Analyzing: $($album.Artist) - $($album.Album)" -ForegroundColor Yellow
    
    try {
        # Get audio files
        $audioExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma')
        $audioFiles = Get-ChildItem -Path $album.Path -File | Where-Object { 
            $_.Extension.ToLower() -in $audioExtensions 
        } | Sort-Object Name
        
        if ($audioFiles.Count -eq 0) {
            Write-Host "  ⚠️ No audio files found" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "  📀 Found $($audioFiles.Count) tracks" -ForegroundColor Green
        
        # Extract track durations
        $albumTracks = @()
        $errorCount = 0
        
        foreach ($file in $audioFiles) {
            try {
                $tags = Get-TrackTags -Path $file.FullName -ErrorAction Stop
                
                $trackInfo = [PSCustomObject]@{
                    Artist = $album.Artist
                    Album = $album.Album
                    TrackTitle = $tags.Title
                    FileName = $file.Name
                    Duration = $tags.Duration
                    DurationSeconds = $tags.DurationSeconds
                    FilePath = $file.FullName
                    FileSize = $file.Length
                    TrackLength = if ($tags.DurationSeconds -lt 120) { "Short" }
                                 elseif ($tags.DurationSeconds -lt 420) { "Normal" }
                                 elseif ($tags.DurationSeconds -lt 600) { "Long" }
                                 else { "Epic" }
                }
                
                $albumTracks += $trackInfo
                $allTracks += $trackInfo
                
                if ($ShowDetailed) {
                    Write-Host "    ✅ $($tags.Title) - $($tags.Duration)" -ForegroundColor Green
                }
                
            } catch {
                $errorCount++
                if ($ShowDetailed) {
                    Write-Host "    ❌ Failed to read: $($file.Name)" -ForegroundColor Red
                }
            }
        }
        
        # Album statistics
        $albumDuration = ($albumTracks | Measure-Object -Property DurationSeconds -Sum).Sum
        $avgTrackLength = ($albumTracks | Measure-Object -Property DurationSeconds -Average).Average
        
        $albumResult = [PSCustomObject]@{
            Artist = $album.Artist
            Album = $album.Album
            Path = $album.Path
            TrackCount = $albumTracks.Count
            ErrorCount = $errorCount
            AlbumDurationSeconds = $albumDuration
            AlbumDurationFormatted = [TimeSpan]::FromSeconds($albumDuration).ToString("h\:mm\:ss")
            AverageTrackLength = [math]::Round($avgTrackLength, 1)
            ShortTracks = ($albumTracks | Where-Object { $_.TrackLength -eq "Short" }).Count
            NormalTracks = ($albumTracks | Where-Object { $_.TrackLength -eq "Normal" }).Count
            LongTracks = ($albumTracks | Where-Object { $_.TrackLength -eq "Long" }).Count
            EpicTracks = ($albumTracks | Where-Object { $_.TrackLength -eq "Epic" }).Count
            Tracks = $albumTracks
        }
        
        $analysisResults += $albumResult
        
        Write-Host "  📊 Album: $($albumResult.AlbumDurationFormatted), Avg track: $($albumResult.AverageTrackLength)s" -ForegroundColor Cyan
        Write-Host "  📈 Breakdown: $($albumResult.ShortTracks) short, $($albumResult.NormalTracks) normal, $($albumResult.LongTracks) long, $($albumResult.EpicTracks) epic" -ForegroundColor Gray
        
    } catch {
        Write-Host "  ❌ Error analyzing album: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Overall statistics
Write-Host "📊 OVERALL ANALYSIS RESULTS" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

$totalTracks = $allTracks.Count
$totalAlbums = $analysisResults.Count

Write-Host "🎵 Dataset Summary:" -ForegroundColor Yellow
Write-Host "   Albums analyzed: $totalAlbums" -ForegroundColor White
Write-Host "   Total tracks: $totalTracks" -ForegroundColor White
Write-Host ""

# Track length distribution
$shortTracks = $allTracks | Where-Object { $_.TrackLength -eq "Short" }
$normalTracks = $allTracks | Where-Object { $_.TrackLength -eq "Normal" }
$longTracks = $allTracks | Where-Object { $_.TrackLength -eq "Long" }
$epicTracks = $allTracks | Where-Object { $_.TrackLength -eq "Epic" }

Write-Host "📏 Track Length Distribution:" -ForegroundColor Yellow
Write-Host "   Short (0-2min):   $($shortTracks.Count) tracks ($([math]::Round(($shortTracks.Count/$totalTracks)*100,1))%)" -ForegroundColor Green
Write-Host "   Normal (2-7min):  $($normalTracks.Count) tracks ($([math]::Round(($normalTracks.Count/$totalTracks)*100,1))%)" -ForegroundColor Cyan
Write-Host "   Long (7-10min):   $($longTracks.Count) tracks ($([math]::Round(($longTracks.Count/$totalTracks)*100,1))%)" -ForegroundColor Yellow
Write-Host "   Epic (10min+):    $($epicTracks.Count) tracks ($([math]::Round(($epicTracks.Count/$totalTracks)*100,1))%)" -ForegroundColor Magenta
Write-Host ""

# Duration statistics by category
$categories = @("Short", "Normal", "Long", "Epic")
$durationStats = @{}

foreach ($category in $categories) {
    $categoryTracks = $allTracks | Where-Object { $_.TrackLength -eq $category }
    if ($categoryTracks.Count -gt 0) {
        $durations = $categoryTracks | Measure-Object -Property DurationSeconds -Average -Minimum -Maximum -StandardDeviation
        $durationStats[$category] = [PSCustomObject]@{
            Category = $category
            Count = $categoryTracks.Count
            AverageSeconds = [math]::Round($durations.Average, 1)
            MinSeconds = $durations.Minimum
            MaxSeconds = $durations.Maximum
            StdDevSeconds = [math]::Round($durations.StandardDeviation, 1)
            AverageFormatted = [TimeSpan]::FromSeconds($durations.Average).ToString("mm\:ss")
            MinFormatted = [TimeSpan]::FromSeconds($durations.Minimum).ToString("mm\:ss")
            MaxFormatted = [TimeSpan]::FromSeconds($durations.Maximum).ToString("mm\:ss")
        }
    }
}

Write-Host "📈 Duration Statistics by Category:" -ForegroundColor Yellow
foreach ($category in $categories) {
    if ($durationStats[$category]) {
        $stats = $durationStats[$category]
        Write-Host "   $($stats.Category): " -NoNewline -ForegroundColor White
        Write-Host "avg $($stats.AverageFormatted), " -NoNewline -ForegroundColor Cyan
        Write-Host "range $($stats.MinFormatted)-$($stats.MaxFormatted), " -NoNewline -ForegroundColor Gray
        Write-Host "±$($stats.StdDevSeconds)s" -ForegroundColor Yellow
    }
}
Write-Host ""

# Suggested tolerance thresholds based on real data
Write-Host "🎯 DATA-DRIVEN TOLERANCE RECOMMENDATIONS:" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

foreach ($category in $categories) {
    if ($durationStats[$category]) {
        $stats = $durationStats[$category]
        
        # Calculate recommended tolerances (based on standard deviation)
        $strictPercent = [math]::Round(($stats.StdDevSeconds / $stats.AverageSeconds) * 100, 1)
        $normalPercent = [math]::Round($strictPercent * 1.5, 1)
        $relaxedPercent = [math]::Round($strictPercent * 2.5, 1)
        
        $strictSeconds = [math]::Round($stats.StdDevSeconds)
        $normalSeconds = [math]::Round($stats.StdDevSeconds * 1.5)
        $relaxedSeconds = [math]::Round($stats.StdDevSeconds * 2.5)
        
        Write-Host "🎵 $($stats.Category) tracks (avg: $($stats.AverageFormatted)):" -ForegroundColor Cyan
        Write-Host "   Standard deviation: ±$($stats.StdDevSeconds)s" -ForegroundColor Gray
        Write-Host "   Strict:   $strictPercent% (${strictSeconds}s)" -ForegroundColor Red
        Write-Host "   Normal:   $normalPercent% (${normalSeconds}s)" -ForegroundColor Yellow
        Write-Host "   Relaxed:  $relaxedPercent% (${relaxedSeconds}s)" -ForegroundColor Green
        Write-Host ""
    }
}

# Find interesting examples
$pinkFloydTracks = $allTracks | Where-Object { $_.Artist -like "*Pink Floyd*" }
$shortestTrack = $allTracks | Sort-Object DurationSeconds | Select-Object -First 1
$longestTrack = $allTracks | Sort-Object DurationSeconds -Descending | Select-Object -First 1

Write-Host "🎶 Interesting Examples Found:" -ForegroundColor Magenta
Write-Host "==============================" -ForegroundColor Magenta
if ($pinkFloydTracks) {
    Write-Host "🌈 Pink Floyd tracks: $($pinkFloydTracks.Count)" -ForegroundColor Magenta
    $pinkFloydTracks | Sort-Object DurationSeconds -Descending | Select-Object -First 3 | ForEach-Object {
        Write-Host "   🎆 $($_.TrackTitle) - $($_.Duration)" -ForegroundColor White
    }
}
Write-Host "⚡ Shortest: $($shortestTrack.TrackTitle) by $($shortestTrack.Artist) - $($shortestTrack.Duration)" -ForegroundColor Green
Write-Host "🎆 Longest:  $($longestTrack.TrackTitle) by $($longestTrack.Artist) - $($longestTrack.Duration)" -ForegroundColor Magenta
Write-Host ""

# Save results to JSON for further analysis
$exportData = @{
    AnalysisDate = Get-Date
    LibraryPath = $LibraryPath
    TotalAlbums = $totalAlbums
    TotalTracks = $totalTracks
    DurationStats = $durationStats
    Albums = $analysisResults
    AllTracks = $allTracks
    Recommendations = @{
        Note = "Based on standard deviation of real music library"
        StrictTolerancePercent = 2.0
        NormalTolerancePercent = 5.0
        RelaxedTolerancePercent = 8.0
    }
}

$exportData | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8
Write-Host "💾 Results saved to: $OutputFile" -ForegroundColor Green

Write-Host "🎉 Real-world analysis complete!" -ForegroundColor Green
Write-Host "   Use these data-driven thresholds for much better accuracy!" -ForegroundColor Gray

return @{
    TotalTracks = $totalTracks
    DurationStats = $durationStats
    Results = $analysisResults
    ExportFile = $OutputFile
}