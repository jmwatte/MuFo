# Test script to debug Qobuz track data flow
# This helps us see what Get-QAlbumTracks returns and how Get-Tags processes it

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the module
Import-Module "$PSScriptRoot\..\MuFo.psd1" -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "QOBUZ TRACK DATA FLOW TEST" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Test album: Japan - Quiet Life
$albumId = "0060253780100"  # Adjust this to your actual Qobuz album ID

Write-Host "Step 1: Fetching Qobuz tracks for album ID: $albumId" -ForegroundColor Yellow
try {
    $tracks = Get-QAlbumTracks -Id $albumId
    Write-Host "✓ Successfully fetched $($tracks.Count) tracks`n" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to fetch tracks: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Examine first track in detail
if ($tracks.Count -gt 0) {
    $track = $tracks[8]  # Track 9 - All Tomorrow's Parties
    
    Write-Host "Step 2: Examining Track 9 (All Tomorrow's Parties)`n" -ForegroundColor Yellow
    
    Write-Host "Raw Track Object Properties:" -ForegroundColor Cyan
    $track.PSObject.Properties | ForEach-Object {
        $value = $_.Value
        if ($value -is [array]) {
            Write-Host "  $($_.Name): [Array with $($value.Count) items]" -ForegroundColor White
            if ($value.Count -gt 0 -and $value.Count -le 5) {
                foreach ($item in $value) {
                    Write-Host "    - $item" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  $($_.Name): $value" -ForegroundColor White
        }
    }
    
    Write-Host "`n" 
    Write-Host "Step 3: Testing Get-Tags with this track`n" -ForegroundColor Yellow
    
    # Create mock artist and album objects
    $mockArtist = [PSCustomObject]@{
        name = "Japan"
        id = "test-artist-id"
        genres = @("pop-rock", "new wave")
    }
    
    $mockAlbum = [PSCustomObject]@{
        name = "Quiet Life"
        id = $albumId
        release_date = "1979-11-01"
        genre = @("pop-rock")
    }
    
    Write-Host "Calling Get-Tags..." -ForegroundColor Cyan
    try {
        $tags = Get-Tags -Artist $mockArtist -Album $mockAlbum -SpotifyTrack $track
        
        Write-Host "✓ Get-Tags succeeded!`n" -ForegroundColor Green
        Write-Host "Returned Tag Hashtable:" -ForegroundColor Cyan
        $tags.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
        }
    } catch {
        Write-Host "✗ Get-Tags failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
    
    Write-Host "`n"
    Write-Host "Step 4: Checking Artist Property Details`n" -ForegroundColor Yellow
    
    Write-Host "track.artists property:" -ForegroundColor Cyan
    if ($track.artists) {
        Write-Host "  Type: $($track.artists.GetType().FullName)" -ForegroundColor White
        Write-Host "  Count: $($track.artists.Count)" -ForegroundColor White
        if ($track.artists -is [array]) {
            foreach ($artist in $track.artists) {
                Write-Host "  Item Type: $($artist.GetType().FullName)" -ForegroundColor White
                Write-Host "  Item Value: $artist" -ForegroundColor White
                if ($artist.PSObject.Properties['name']) {
                    Write-Host "    .name property: $($artist.name)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  Value: $($track.artists)" -ForegroundColor White
        }
    } else {
        Write-Host "  [NULL or missing]" -ForegroundColor Red
    }
    
    Write-Host "`ntrack.Artist property:" -ForegroundColor Cyan
    if ($track.Artist) {
        Write-Host "  Type: $($track.Artist.GetType().FullName)" -ForegroundColor White
        Write-Host "  Value: $($track.Artist)" -ForegroundColor White
    } else {
        Write-Host "  [NULL or missing]" -ForegroundColor Red
    }
    
    Write-Host "`n"
    Write-Host "Step 5: Testing Get-IfExists on track properties`n" -ForegroundColor Yellow
    
    $testProps = @('name', 'title', 'Title', 'artists', 'Artist', 'performer', 'track_number', 'TrackNumber')
    foreach ($prop in $testProps) {
        $result = Get-IfExists $track $prop
        $resultType = if ($result) { $result.GetType().Name } else { "NULL" }
        Write-Host "  Get-IfExists track '$prop': $result [$resultType]" -ForegroundColor White
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
