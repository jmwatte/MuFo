# Tests for Manual mode album selection in Get-ManualAlbumSelection
Write-Host "=== Testing Manual Mode Album Selection ===" -ForegroundColor Cyan

$testRoot = Join-Path $env:TEMP "MuFo-ManualSelection"
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $testRoot | Out-Null

$artistPath = Join-Path $testRoot 'Test Artist'
New-Item -ItemType Directory -Path $artistPath | Out-Null
$albumPath = Join-Path $artistPath 'Old Album'
New-Item -ItemType Directory -Path $albumPath | Out-Null

# Stub dependencies used by the helper
function Get-SpotifyArtistAlbums {
    param([string]$ArtistId, [switch]$IncludeSingles, [switch]$IncludeCompilations)
    return @(
        [pscustomobject]@{
            Name        = 'Album One'
            Id          = 'album-1'
            AlbumType   = 'album'
            ReleaseDate = '2024-01-01'
        },
        [pscustomobject]@{
            Name        = 'Album Two'
            Id          = 'album-2'
            AlbumType   = 'album'
            ReleaseDate = '2023-01-01'
        }
    )
}

function ConvertTo-ComparableName {
    param([string]$Name)
    return $Name.ToLower().Replace(' ', '').Replace('-', '')
}

function Get-StringSimilarity {
    param([string]$String1, [string]$String2)
    return 0.95
}

# Mock Read-Host for Manual mode selection
$script:ReadHostCalls = @()
function Read-Host {
    param([string]$Prompt)
    $script:ReadHostCalls += $Prompt
    # Simulate user choosing option 1 (first album)
    return '1'
}

# Load the helper under test
. .\Private\Get-ManualAlbumSelection.ps1

# Reset counters
$script:ReadHostCalls = @()

# Test the standalone helper function
$mockArtist = @{ Name = "Test Artist"; Id = "test-id" }
$result = Get-ManualAlbumSelection -ArtistPath $artistPath -SelectedArtist $mockArtist -EffectiveExclusions @() -IncludeSingles -IncludeCompilations

# Verify Read-Host was called for album selection
if ($script:ReadHostCalls.Count -ge 1 -and $script:ReadHostCalls[0] -match 'Choose album') {
    Write-Host "✓ Read-Host called for album selection" -ForegroundColor Green
} else {
    Write-Host "✗ Read-Host not called for album selection" -ForegroundColor Red
}

# Verify the correct album ID was returned (album-1, the first choice)
if ($result -eq 'album-1') {
    Write-Host "✓ Correct album ID returned from selection" -ForegroundColor Green
} else {
    Write-Host "✗ Incorrect album ID returned: $result" -ForegroundColor Red
}

# Test with no albums found
function Get-SpotifyArtistAlbums {
    param([string]$ArtistId, [switch]$IncludeSingles, [switch]$IncludeCompilations)
    return @()
}

$script:ReadHostCalls = @()
$result = Get-ManualAlbumSelection -ArtistPath $artistPath -SelectedArtist $mockArtist -EffectiveExclusions @() -IncludeSingles -IncludeCompilations

if ($result -eq $null) {
    Write-Host "✓ Null returned when no albums found" -ForegroundColor Green
} else {
    Write-Host "✗ Expected null when no albums found, got: $result" -ForegroundColor Red
}

# Test user skipping selection
function Get-SpotifyArtistAlbums {
    param([string]$ArtistId, [switch]$IncludeSingles, [switch]$IncludeCompilations)
    return @(
        [pscustomobject]@{
            Name        = 'Album One'
            Id          = 'album-1'
            AlbumType   = 'album'
            ReleaseDate = '2024-01-01'
        }
    )
}

function Read-Host {
    param([string]$Prompt)
    $script:ReadHostCalls += $Prompt
    # Simulate user choosing 0 to skip
    return '0'
}

$script:ReadHostCalls = @()
$result = Get-ManualAlbumSelection -ArtistPath $artistPath -SelectedArtist $mockArtist -EffectiveExclusions @() -IncludeSingles -IncludeCompilations

if ($result -eq $null) {
    Write-Host "✓ Null returned when user skips selection" -ForegroundColor Green
} else {
    Write-Host "✗ Expected null when user skips, got: $result" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

Write-Host "=== Manual Mode Album Selection tests complete ===" -ForegroundColor Cyan