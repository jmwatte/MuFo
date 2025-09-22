# Track Artist Complexity Validation Script
# Tests how MuFo handles albums with multiple featured artists

Write-Host "🎭 TRACK ARTIST COMPLEXITY VALIDATION" -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta

# Test album path
$albumPath = "D:\_CorrectedMusic\Afrika Bambaataa and the Soul Sonic Force\Planet Rock The Album"

if (-not (Test-Path $albumPath)) {
    Write-Host "❌ Album path not found: $albumPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n📂 Album: $albumPath" -ForegroundColor Cyan
$audioFiles = Get-ChildItem -Path $albumPath -Filter "*.mp3"
Write-Host "   Found $($audioFiles.Count) audio files" -ForegroundColor Green

# Function to safely read tags
function Get-SafeAudioTags {
    param($FilePath)
    
    try {
        $tagFile = [TagLib.File]::Create($FilePath)
        $result = @{
            Title = $tagFile.Tag.Title
            Artist = $tagFile.Tag.FirstPerformer
            AlbumArtist = $tagFile.Tag.FirstAlbumArtist
            AllPerformers = $tagFile.Tag.Performers
            Album = $tagFile.Tag.Album
            Success = $true
        }
        $tagFile.Dispose()
        return $result
    }
    catch {
        return @{
            Error = $_.Exception.Message
            Success = $false
        }
    }
}

Write-Host "`n🔍 CURRENT TRACK ARTIST ANALYSIS:" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow

$trackAnalysis = @()

foreach ($file in $audioFiles | Select-Object -First 8) {
    $tags = Get-SafeAudioTags -FilePath $file.FullName
    
    if ($tags.Success) {
        $analysis = [PSCustomObject]@{
            FileName = $file.Name
            Title = $tags.Title
            Artist = $tags.Artist
            AlbumArtist = $tags.AlbumArtist
            AllPerformers = ($tags.AllPerformers -join ' | ')
            ComplexArtist = ($tags.AllPerformers.Count -gt 1)
            HasFeaturing = ($tags.Artist -like "*feat*" -or $tags.Artist -like "*ft*")
        }
        
        $trackAnalysis += $analysis
        
        Write-Host "`n🎵 $($file.Name)" -ForegroundColor Green
        Write-Host "   Title: '$($tags.Title)'" -ForegroundColor White
        Write-Host "   Artist: '$($tags.Artist)'" -ForegroundColor White
        Write-Host "   Album Artist: '$($tags.AlbumArtist)'" -ForegroundColor White
        Write-Host "   All Performers: $($tags.AllPerformers -join ', ')" -ForegroundColor Gray
        
        if ($analysis.ComplexArtist) {
            Write-Host "   ⚠️  COMPLEX: Multiple performers detected" -ForegroundColor Yellow
        }
        if ($analysis.HasFeaturing) {
            Write-Host "   🎤 FEATURING: Contains 'feat' or 'ft'" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "`n❌ $($file.Name): Error reading tags - $($tags.Error)" -ForegroundColor Red
    }
}

Write-Host "`n📊 SUMMARY ANALYSIS:" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Magenta

$complexTracks = $trackAnalysis | Where-Object { $_.ComplexArtist }
$featuringTracks = $trackAnalysis | Where-Object { $_.HasFeaturing }

Write-Host "   Total tracks analyzed: $($trackAnalysis.Count)" -ForegroundColor White
Write-Host "   Tracks with multiple performers: $($complexTracks.Count)" -ForegroundColor Yellow
Write-Host "   Tracks with 'featuring': $($featuringTracks.Count)" -ForegroundColor Cyan

if ($complexTracks.Count -gt 0) {
    Write-Host "`n🎭 COMPLEX ARTIST TRACKS:" -ForegroundColor Yellow
    foreach ($track in $complexTracks) {
        Write-Host "   • $($track.Title): $($track.AllPerformers)" -ForegroundColor Gray
    }
}

Write-Host "`n🔄 Now testing MuFo behavior on this album..." -ForegroundColor Cyan
Write-Host "Running: Invoke-MuFo -Path (parent folder) -Preview" -ForegroundColor Yellow

# Test MuFo on the parent artist folder
$artistPath = Split-Path $albumPath -Parent
Write-Host "`nTesting on artist folder: $artistPath" -ForegroundColor Green

try {
    Invoke-MuFo -Path $artistPath -Preview -Verbose
}
catch {
    Write-Host "❌ Error running MuFo: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✅ Track artist complexity validation complete!" -ForegroundColor Green