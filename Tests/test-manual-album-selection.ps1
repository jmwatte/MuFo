# Tests for Manual mode album selection in Invoke-MuFoArtistProcessing
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
function Get-ExclusionsStorePath {
    return [pscustomobject]@{ Dir = $testRoot; File = Join-Path $testRoot 'exclusions.json' }
}

function Get-SpotifyArtist {
    param([string]$ArtistName)
    return @([pscustomobject]@{
        Score  = 95
        Artist = [pscustomobject]@{ Name = "$ArtistName (Spotify)"; Id = 'artist-123' }
    })
}

function Get-StringSimilarity {
    param([string]$String1, [string]$String2)
    return 0.95
}

function Get-ArtistSelection {
    param([string]$LocalArtist, [object]$TopMatches)
    return [pscustomobject]@{
        SelectedArtist   = [pscustomobject]@{ Name = "$LocalArtist (Spotify)"; Id = 'artist-123' }
        SelectionSource  = 'search'
    }
}

function Write-ArtistTypoWarning {}

function Get-ArtistRenameProposal {
    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string]$SelectionSource)
    return [pscustomobject]@{
        ProposedName = $SelectedArtist.Name
        TargetPath   = Join-Path -Path (Split-Path -Parent -Path $CurrentPath) -ChildPath $SelectedArtist.Name
    }
}

$script:AlbumComparisonsCallCount = 0
function Get-AlbumComparisons {
    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string[]]$EffectiveExclusions, [object]$ForcedAlbum)
    $script:AlbumComparisonsCallCount++
    if ($ForcedAlbum) {
        # When forced album is provided, return only that album
        return @(
            [pscustomobject]@{
                MatchScore   = 1.0
                ProposedName = $ForcedAlbum.Name
                LocalAlbum   = 'Old Album'
                LocalNorm    = 'Old Album'
                MatchName    = $ForcedAlbum.Name
                MatchType    = $ForcedAlbum.AlbumType
                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'
                MatchedItem  = [pscustomobject]@{
                    Item = $ForcedAlbum
                }
            }
        )
    } else {
        # Return candidates for selection
        return @(
            [pscustomobject]@{
                MatchScore   = 0.92
                ProposedName = 'Album One'
                LocalAlbum   = 'Old Album'
                LocalNorm    = 'Old Album'
                MatchName    = 'Album One'
                MatchType    = 'album'
                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'
                MatchedItem  = [pscustomobject]@{
                    Item = [pscustomobject]@{ Id = 'album-1' }
                }
            },
            [pscustomobject]@{
                MatchScore   = 0.85
                ProposedName = 'Album Two'
                LocalAlbum   = 'Old Album'
                LocalNorm    = 'Old Album'
                MatchName    = 'Album Two'
                MatchType    = 'album'
                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'
                MatchedItem  = [pscustomobject]@{
                    Item = [pscustomobject]@{ Id = 'album-2' }
                }
            }
        )
    }
}

function Add-MemoryOptimization { }

function Get-CollectionSizeRecommendations {
    param([int]$AlbumCount)
    return [pscustomobject]@{
        Warnings                  = @()
        Recommendations           = @()
        EstimatedProcessingMinutes = 1
    }
}

function Optimize-SpotifyTrackValidation {
    param($Comparisons)
    return $Comparisons
}

$script:RequestedAlbumId = $null
function Get-Album {
    param([string]$Id)
    $script:RequestedAlbumId = $Id
    return [pscustomobject]@{
        Name        = 'Selected Album'
        AlbumType   = 'album'
        ReleaseDate = '2024-01-01'
        Id          = $Id
        artists     = @([pscustomobject]@{ id = 'artist-123' })
    }
}

$script:CapturedRenameOps = $null
function Write-RenameOperation {
    param([object]$RenameMap, [string]$Mode)
    $mapCopy = @{}
    if ($RenameMap -is [System.Collections.IDictionary]) {
        foreach ($key in $RenameMap.Keys) {
            $mapCopy[$key] = $RenameMap[$key]
        }
    }
    $script:CapturedRenameOps = [pscustomobject]@{ Mode = $Mode; Map = $mapCopy }
}

function Write-ArtistRenameMessage {}
function Write-AlbumNoRenameNeeded {}
function Write-NothingToRenameMessage {}
function Write-WhatIfMessage {}
function Test-AudioFileCompleteness {}
function Set-AudioFileTags {}
function Get-AudioFileTags {}
function Test-AlbumDurationConsistency {}

# Mock Read-Host for Manual mode selection
$script:ReadHostCalls = @()
function Read-Host {
    param([string]$Prompt)
    $script:ReadHostCalls += $Prompt
    # Simulate user choosing option 1 (first album)
    return '1'
}

# Load the helper under test
. .\Private\Invoke-MuFo-ArtistProcessing.ps1

# Reset counters
$script:AlbumComparisonsCallCount = 0
$script:RequestedAlbumId = $null
$script:ReadHostCalls = @()

# Test Manual mode album selection
$results = Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview

# Verify Get-AlbumComparisons was called twice (once for selection, once for processing)
if ($script:AlbumComparisonsCallCount -eq 2) {
    Write-Host "✓ Get-AlbumComparisons called twice (selection + processing)" -ForegroundColor Green
} else {
    Write-Host "✗ Get-AlbumComparisons call count unexpected: $script:AlbumComparisonsCallCount" -ForegroundColor Red
}

# Verify Read-Host was called for album selection
if ($script:ReadHostCalls.Count -ge 1 -and $script:ReadHostCalls[0] -match 'Choose album') {
    Write-Host "✓ Read-Host called for album selection" -ForegroundColor Green
} else {
    Write-Host "✗ Read-Host not called for album selection" -ForegroundColor Red
}

# Verify the correct album ID was requested (album-1, the first choice)
if ($script:RequestedAlbumId -eq 'album-1') {
    Write-Host "✓ Correct album ID requested for forced selection" -ForegroundColor Green
} else {
    Write-Host "✗ Incorrect album ID requested: $script:RequestedAlbumId" -ForegroundColor Red
}

# Verify results contain the selected album
$resultsArray = @($results)
if ($resultsArray.Count -eq 1 -and $resultsArray[0].SpotifyAlbum -eq 'Selected Album') {
    Write-Host "✓ Results reflect selected album" -ForegroundColor Green
} else {
    Write-Host "✗ Results do not reflect selected album" -ForegroundColor Red
}

# Test Manual mode with pre-set SpotifyAlbumId (should skip selection)
$script:AlbumComparisonsCallCount = 0
$script:RequestedAlbumId = $null
$script:ReadHostCalls = @()

Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview -SpotifyAlbumId 'pre-set-id'

# Should only call Get-AlbumComparisons once (for processing, not selection)
if ($script:AlbumComparisonsCallCount -eq 1) {
    Write-Host "✓ Pre-set SpotifyAlbumId skips selection phase" -ForegroundColor Green
} else {
    Write-Host "✗ Pre-set SpotifyAlbumId did not skip selection: $script:AlbumComparisonsCallCount calls" -ForegroundColor Red
}

# Verify Read-Host was not called
if ($script:ReadHostCalls.Count -eq 0) {
    Write-Host "✓ Read-Host not called when SpotifyAlbumId pre-set" -ForegroundColor Green
} else {
    Write-Host "✗ Read-Host called unexpectedly with pre-set ID" -ForegroundColor Red
}

# Verify pre-set ID was requested
if ($script:RequestedAlbumId -eq 'pre-set-id') {
    Write-Host "✓ Pre-set SpotifyAlbumId used correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Pre-set SpotifyAlbumId not used: $script:RequestedAlbumId" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

Write-Host "=== Manual Mode Album Selection tests complete ===" -ForegroundColor Cyan