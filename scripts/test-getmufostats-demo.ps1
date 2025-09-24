<#
    test-getmufostats-demo.ps1

    Demonstration script for Get-MuFoStats function.
    Shows how to use Invoke-MuFo results to feed into Get-MuFoStats for detailed analysis.
#>

# Import the MuFo module
$modulePath = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $modulePath 'MuFo.psd1') -Force

# Artist folder to analyze
$artistFolder = "E:\_CorrectedMusic\Afrika Bambaataa and the Soul Sonic Force"

Write-Host "=== Get-MuFoStats Integration Demo ===" -ForegroundColor Cyan
Write-Host "Analyzing artist folder: $artistFolder" -ForegroundColor Yellow
Write-Host ""

# Step 1: Run Invoke-MuFo to get album matches with Spotify objects
Write-Host "Step 1: Running Invoke-MuFo to find Spotify matches..." -ForegroundColor Green
$mufoResults = Invoke-MuFo -Path $artistFolder -WhatIf -IncludeSpotifyObjects -ShowEverything 2>$null  # Get full objects with Spotify data

# Filter for albums that have Spotify matches (Decision = 'prompt' or 'auto')
$matchedAlbums = $mufoResults | Where-Object { $_.Decision -and $_.Decision -ne 'skip' }

if (-not $matchedAlbums) {
    Write-Host "No matched albums found in Invoke-MuFo results." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($matchedAlbums.Count) matched album(s)" -ForegroundColor Green
Write-Host ""

# Step 2: Pick the first matched album for detailed analysis
$selectedAlbum = $matchedAlbums | Select-Object -First 1
Write-Host "Step 2: Analyzing album: $($selectedAlbum.LocalFolder)" -ForegroundColor Green
Write-Host "Local Artist: $($selectedAlbum.LocalArtist)" -ForegroundColor Yellow
Write-Host "Spotify Artist: $($selectedAlbum.Artist)" -ForegroundColor Yellow
Write-Host "Local Album: $($selectedAlbum.LocalAlbum)" -ForegroundColor Yellow
Write-Host "Spotify Album: $($selectedAlbum.SpotifyAlbum)" -ForegroundColor Yellow
Write-Host ""

# Step 3: Construct the full album folder path
$albumFolderPath = Join-Path $artistFolder $selectedAlbum.LocalFolder

if (-not (Test-Path $albumFolderPath)) {
    Write-Host "Album folder not found: $albumFolderPath" -ForegroundColor Red
    exit 1
}

# Step 3: Get Spotify album object from Invoke-MuFo results
Write-Host "Step 3: Extracting Spotify album object from results..." -ForegroundColor Green

# Get the Spotify album object from the matched album
$spotifyAlbumObject = $selectedAlbum.SpotifyAlbumObject

if (-not $spotifyAlbumObject) {
    Write-Host "No Spotify album object found in results. This may indicate an issue with the matching process." -ForegroundColor Red
    Write-Host "Falling back to album ID approach..." -ForegroundColor Yellow

    # Fallback: try to get album by ID if object is not available
    try {
        $spotifyAlbumObject = Get-SpotifyAlbumTracks -AlbumId $selectedAlbum.SpotifyAlbumId
        Write-Host "Retrieved album data by ID: $($spotifyAlbumObject.Name)" -ForegroundColor Green
    } catch {
        Write-Host "Could not retrieve album data: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Using real Spotify album object: $($spotifyAlbumObject.Name) by $($spotifyAlbumObject.Artists[0].Name)" -ForegroundColor Green
}

# Step 4: Call Get-MuFoStats with the album object (API-efficient approach)
Write-Host "Step 4: Running Get-MuFoStats analysis..." -ForegroundColor Green

try {
    # Use the album object directly to save API calls
    $stats = Get-MuFoStats -AlbumFolder $albumFolderPath -SpotifyAlbumObject $spotifyAlbumObject

    # Display comprehensive results
    Write-Host "=== Detailed Analysis Results ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📁 FOLDER INFO:" -ForegroundColor Green
    Write-Host "   Path: $($stats.Folder.Path)"
    Write-Host "   Artist: $($stats.Folder.ArtistName)"
    Write-Host "   Album: $($stats.Folder.AlbumName)"
    Write-Host "   Files: $($stats.Folder.FileCount)"
    Write-Host "   Discs: $($stats.Folder.DiscCount)"
    Write-Host ""

    Write-Host "💿 LOCAL DATA:" -ForegroundColor Green
    Write-Host "   Tracks: $($stats.Local.TrackCount)"
    Write-Host "   Album: $($stats.Local.AlbumName)"
    Write-Host "   Artist: $($stats.Local.AlbumArtist)"
    Write-Host "   Year: $($stats.Local.Year)"
    if ($stats.Local.Tracks -and $stats.Local.Tracks.Count -gt 0) {
        Write-Host "   Sample tracks:"
        $stats.Local.Tracks | Select-Object -First 3 | ForEach-Object {
            Write-Host "     $($_.TrackNumber). $($_.Title) ($($_.Duration)s)"
        }
    }
    Write-Host ""

    Write-Host "🎵 SPOTIFY DATA:" -ForegroundColor Green
    Write-Host "   Album: $($stats.Spotify.AlbumName)"
    Write-Host "   Artist: $($stats.Spotify.AlbumArtist)"
    Write-Host "   Year: $($stats.Spotify.Year)"
    Write-Host "   Tracks: $($stats.Spotify.TrackCount)"
    Write-Host ""

    Write-Host "📊 COMPARISON ANALYSIS:" -ForegroundColor Green
    Write-Host "   Track Count Difference: $($stats.Comparison.TrackCountDifference)"
    Write-Host "   Album Name Similarity: $([math]::Round($stats.Comparison.AlbumNameSimilarity * 100, 1))%"
    Write-Host "   Artist Name Similarity: $([math]::Round($stats.Comparison.ArtistNameSimilarity * 100, 1))%"
    Write-Host "   Matching Tracks: $($stats.Comparison.MatchingTracks)/$($stats.Local.TrackCount)"
    Write-Host "   Year Difference: $($stats.Comparison.YearDifference) years"
    Write-Host ""

    # Genre analysis section
    Write-Host "🎼 TRACK ANALYSIS:" -ForegroundColor Green
    
    # Local track genres
    if ($stats.Local.Tracks -and $stats.Local.Tracks.Count -gt 0) {
        Write-Host "   Local Tracks:" -ForegroundColor Yellow
        foreach ($track in $stats.Local.Tracks) {
            $trackGenres = if ($stats.Local.Tags -and $stats.Local.Tags.ContainsKey('Genres') -and $stats.Local.Tags['Genres']) {
                ($stats.Local.Tags['Genres'] | Select-Object -Unique) -join ', '
            } elseif ($stats.Local.Tags -and $stats.Local.Tags.ContainsKey('Genre') -and $stats.Local.Tags['Genre']) {
                ($stats.Local.Tags['Genre'] | Select-Object -Unique) -join ', '
            } else {
                "No genre tags"
            }
            Write-Host "     $($track.TrackNumber). $($track.Title): $trackGenres"
        }
    }
    
    # Spotify track genres
    if ($stats.Spotify.Tracks -and $stats.Spotify.Tracks.Count -gt 0) {
        Write-Host "   Spotify Tracks:" -ForegroundColor Yellow
        foreach ($track in $stats.Spotify.Tracks) {
            Write-Host "     $($track.Title): $($track.Artist)"
        }
    }
    Write-Host ""

    # Tracks with missing album artist
    Write-Host "🎵 TRACKS WITH MISSING ALBUM ARTIST:" -ForegroundColor Magenta
    $tracksWithoutAlbumArtist = $stats.Local.Tracks | Where-Object { -not $_.AlbumArtist -or $_.AlbumArtist.Trim() -eq '' }
    if ($tracksWithoutAlbumArtist) {
        Write-Host "   Found $($tracksWithoutAlbumArtist.Count) track(s) with missing album artist:" -ForegroundColor Yellow
        foreach ($track in $tracksWithoutAlbumArtist) {
            Write-Host "     $($track.TrackNumber). $($track.Title) ($($track.FileName))"
        }
    } else {
        Write-Host "   All tracks have album artist tags ✓" -ForegroundColor Green
    }
    Write-Host ""

    # Decision recommendations
    Write-Host "🤖 DECISION RECOMMENDATIONS:" -ForegroundColor Cyan
    $recommendations = @()

    if ($stats.Comparison.TrackCountDifference -eq 0) {
        $recommendations += "✅ Safe for automatic processing - track counts match"
    } elseif ($stats.Comparison.TrackCountDifference -lt 3) {
        $recommendations += "⚠️ Minor track differences - review manually"
    } else {
        $recommendations += "❌ Significant track differences - requires manual intervention"
    }

    if ($stats.Comparison.AlbumNameSimilarity -gt 0.9) {
        $recommendations += "✅ Album names highly similar"
    } elseif ($stats.Comparison.AlbumNameSimilarity -gt 0.7) {
        $recommendations += "⚠️ Album names moderately similar - check details"
    } else {
        $recommendations += "❌ Album names differ significantly"
    }

    if ($stats.Comparison.YearDifference -gt 20) {
        $recommendations += "⚠️ Large year difference - possible reissue vs original"
    }

    if ($stats.Comparison.MatchingTracks -gt ($stats.Local.TrackCount * 0.8)) {
        $recommendations += "✅ Most tracks have potential matches"
    } else {
        $recommendations += "⚠️ Many tracks may not match - detailed review needed"
    }

    $recommendations | ForEach-Object { Write-Host "   $_" }

    Write-Host ""
    Write-Host "🎯 POTENTIAL ACTIONS:" -ForegroundColor Cyan
    Write-Host "   • Rename folder to: $($stats.Spotify.Year) - $($stats.Spotify.AlbumName)"
    Write-Host "   • Update metadata tags with Spotify information"
    Write-Host "   • Batch process similar albums automatically"
    Write-Host "   • Flag for manual review if confidence is low"

} catch {
    Write-Host "Error in Get-MuFoStats analysis: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This demonstrates how the function would work with real data." -ForegroundColor Yellow
}