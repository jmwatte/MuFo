#Requires -Version 7.3

<#
.SYNOPSIS
Test Discogs provider implementation for MuFo.

.DESCRIPTION
Tests the Discogs provider functions: Search, Get Albums, Get Tracks.
#>

Write-Host "`n=== Discogs Provider Implementation Test ===" -ForegroundColor Cyan

# Import module
Remove-Module MuFo -ErrorAction SilentlyContinue
Import-Module .\MuFo.psd1 -Force

# Manually load provider functions if needed (for development)
$providerFunctions = @(
    '.\Private\manual\Search-DItem.ps1'
    '.\Private\manual\Get-DArtistAlbums.ps1'
    '.\Private\manual\Get-DAlbumTracks.ps1'
    '.\Private\manual\Invoke-ProviderSearch.ps1'
    '.\Private\manual\Invoke-ProviderGetAlbums.ps1'
    '.\Private\manual\Invoke-ProviderGetTracks.ps1'
)

foreach ($func in $providerFunctions) {
    if (Test-Path $func) {
        . $func
        Write-Verbose "Loaded $func"
    }
}

# Test 1: Search for artist
Write-Host "`n1. Testing artist search..." -ForegroundColor Yellow
Write-Host "Searching for 'Fats Waller'..." -ForegroundColor Gray

try {
    $searchResult = Invoke-ProviderSearch -Provider 'Discogs' -Query 'Fats Waller' -Type 'artist'
    
    if ($searchResult.artists.items) {
        Write-Host "✓ Found $($searchResult.artists.items.Count) artists" -ForegroundColor Green
        $searchResult.artists.items | Select-Object -First 5 | Format-Table name, id, type
        
        # Select first artist for remaining tests
        $selectedArtist = $searchResult.artists.items[0]
        $artistId = $selectedArtist.id
        Write-Host "Selected artist: $($selectedArtist.name) (ID: $artistId)" -ForegroundColor Cyan
    } else {
        Write-Warning "No artists found"
        exit
    }
}
catch {
    Write-Error "Artist search failed: $_"
    exit
}

# Test 2: Get artist albums
Write-Host "`n2. Testing get artist albums..." -ForegroundColor Yellow
Write-Host "Getting albums for artist ID: $artistId..." -ForegroundColor Gray

try {
    $albums = Invoke-ProviderGetAlbums -Provider 'Discogs' -ArtistId $artistId
    
    if ($albums) {
        Write-Host "✓ Found $($albums.Count) releases" -ForegroundColor Green
        $albums | Select-Object -First 10 | Format-Table name, release_date, id, type, format
        
        # Select first album for track test
        $selectedAlbum = $albums[0]
        $albumId = $selectedAlbum.id
        Write-Host "Selected album: $($selectedAlbum.name) (ID: $albumId)" -ForegroundColor Cyan
    } else {
        Write-Warning "No albums found"
        exit
    }
}
catch {
    Write-Error "Get albums failed: $_"
    exit
}

# Test 3: Get album tracks
Write-Host "`n3. Testing get album tracks..." -ForegroundColor Yellow
Write-Host "Getting tracks for album ID: $albumId..." -ForegroundColor Gray

try {
    $tracks = Invoke-ProviderGetTracks -Provider 'Discogs' -AlbumId $albumId
    
    if ($tracks) {
        Write-Host "✓ Found $($tracks.Count) tracks" -ForegroundColor Green
        $tracks | Format-Table track_number, disc_number, name, duration_ms, position
    } else {
        Write-Warning "No tracks found"
    }
}
catch {
    Write-Error "Get tracks failed: $_"
}

# Test 4: Show rate limiting info
Write-Host "`n4. Rate limiting status..." -ForegroundColor Yellow
Write-Host "Requests made: $script:DiscogsRequestCount/60 per minute" -ForegroundColor White

Write-Host "`n=== All Discogs Provider Tests Complete! ===" -ForegroundColor Green
Write-Host "`nYou can now use: Invoke-MuFoManual 'E:\fats waller' -Provider Discogs -WhatIf" -ForegroundColor Cyan
Write-Host ""
