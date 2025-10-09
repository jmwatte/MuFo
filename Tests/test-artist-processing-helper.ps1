# Tests for Invoke-MuFoArtistProcessing helper in preview mode
Write-Host "=== Testing Invoke-MuFoArtistProcessing helper ===" -ForegroundColor Cyan

$testRoot = Join-Path $env:TEMP "MuFo-ArtistProcessing"
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
    param(
        [string]$ArtistName
    )
    return @(
        [pscustomobject]@{
            Score  = 95
            Artist = [pscustomobject]@{ Name = "$ArtistName (Spotify)"; Id = 'artist-123' }
        }
    )
}

function Get-StringSimilarity {
    param([string]$String1, [string]$String2)
    return 0.95
}

function Get-ArtistSelection {
    param(
        [string]$LocalArtist,
        [object]$TopMatches
    )
    return [pscustomobject]@{
        SelectedArtist   = [pscustomobject]@{ Name = "$LocalArtist (Spotify)"; Id = 'artist-123' }
        SelectionSource  = 'search'
    }
}

function Write-ArtistTypoWarning {}

function Get-ArtistRenameProposal {
    param(
        [string]$CurrentPath,
        [pscustomobject]$SelectedArtist,
        [string]$SelectionSource
    )
    return [pscustomobject]@{
        ProposedName = $SelectedArtist.Name
        TargetPath   = Join-Path -Path (Split-Path -Parent -Path $CurrentPath) -ChildPath $SelectedArtist.Name
    }
}

function Get-AlbumComparisons {
    param(
        [string]$CurrentPath,
        [pscustomobject]$SelectedArtist,
        [string[]]$EffectiveExclusions
    )
    return @(
        [pscustomobject]@{
            MatchScore   = 0.92
            ProposedName = 'New Album Name'
            LocalAlbum   = 'Old Album'
            LocalNorm    = 'Old Album'
            MatchName    = 'New Album Name'
            MatchType    = 'album'
            LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'
        }
    )
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
    param(
        [string]$Id
    )
    $script:RequestedAlbumId = $Id
    return [pscustomobject]@{
        Name        = 'New Album Name'
        AlbumType   = 'album'
        ReleaseDate = '2024-01-01'
        Id          = $Id
        artists     = @([pscustomobject]@{ id = 'artist-123' })
    }
}

$script:CapturedRenameOps = $null
function Write-RenameOperation {
    param(
        [object]$RenameMap,
        [string]$Mode
    )
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

# Load the helper under test
. .\Private\Invoke-MuFo-ArtistProcessing.ps1

$results = Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Smart' -ConfidenceThreshold 0.6 -Preview

$resultsArray = @($results)
if ($resultsArray.Count -eq 1 -and $resultsArray[0].NewFolderName) {
    Write-Host "✓ Invoke-MuFoArtistProcessing returned expected preview record" -ForegroundColor Green
} else {
    Write-Host "✗ Unexpected results from Invoke-MuFoArtistProcessing" -ForegroundColor Red
}

if ($CapturedRenameOps -and $CapturedRenameOps.Mode -eq 'WhatIf' -and $CapturedRenameOps.Map.Count -ge 1) {
    Write-Host "✓ Preview rename map captured" -ForegroundColor Green
} else {
    Write-Host "✗ Rename map not captured as expected" -ForegroundColor Red
}

$script:CapturedRenameOps = $null
$script:RequestedAlbumId = $null
$forcedResults = Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Smart' -ConfidenceThreshold 0.6 -Preview -SpotifyAlbumId '3BXSE3G8iFAVTJ65gufjKD'
$forcedArray = @($forcedResults)
if ($script:RequestedAlbumId -eq '3BXSE3G8iFAVTJ65gufjKD') {
    Write-Host "✓ Forced Spotify album ID requested" -ForegroundColor Green
} else {
    Write-Host "✗ Forced Spotify album ID was not requested" -ForegroundColor Red
}

if ($forcedArray.Count -eq 1 -and $forcedArray[0].SpotifyAlbum -eq 'New Album Name') {
    Write-Host "✓ Forced album applied to comparison results" -ForegroundColor Green
} else {
    Write-Host "✗ Forced album did not appear in results" -ForegroundColor Red
}

if ($CapturedRenameOps -and $CapturedRenameOps.Mode -eq 'WhatIf' -and $CapturedRenameOps.Map.Count -ge 1) {
    Write-Host "✓ Forced album preserved preview rename map" -ForegroundColor Green
} else {
    Write-Host "✗ Forced album preview rename map missing" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

Write-Host "=== Invoke-MuFoArtistProcessing helper tests complete ===" -ForegroundColor Cyan
