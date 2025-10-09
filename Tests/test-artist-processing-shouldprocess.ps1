# WhatIf-mode test for Invoke-MuFoArtistProcessing helper
Write-Host "=== Testing Invoke-MuFoArtistProcessing ShouldProcess wiring ===" -ForegroundColor Cyan

function Initialize-TestEnvironment {
    param([string]$Suffix)

    $root = Join-Path $env:TEMP "MuFo-ArtistProcessing-ShouldProcess-$Suffix"
    if (Test-Path $root) {
        Remove-Item -Path $root -Recurse -Force
    }
    New-Item -ItemType Directory -Path $root | Out-Null

    $artist = Join-Path $root 'Test Artist'
    New-Item -ItemType Directory -Path $artist | Out-Null
    $album = Join-Path $artist 'Old Album'
    New-Item -ItemType Directory -Path $album | Out-Null

    $script:CurrentTestRoot = $root
    $script:CurrentArtistPath = $artist
    $script:CurrentAlbumPath = $album

    return [pscustomobject]@{
        Root       = $root
        ArtistPath = $artist
        AlbumPath  = $album
    }
}

# Stub dependencies used by the helper
function Get-ExclusionsStorePath {
    return [pscustomobject]@{ Dir = $script:CurrentTestRoot; File = Join-Path $script:CurrentTestRoot 'exclusions.json' }
}

function Get-SpotifyArtist {
    param([string]$ArtistName)
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
    param([string]$LocalArtist, [object]$TopMatches)
    return [pscustomobject]@{
        SelectedArtist  = [pscustomobject]@{ Name = "$LocalArtist (Spotify)"; Id = 'artist-123' }
        SelectionSource = 'search'
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

function Get-AlbumComparisons {
    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string[]]$EffectiveExclusions, $ForcedAlbum)
    return @(
        [pscustomobject]@{
            MatchScore   = 0.92
            ProposedName = 'New Album Name'
            LocalAlbum   = 'Old Album'
            LocalNorm    = 'Old Album'
            MatchName    = if ($ForcedAlbum) { $ForcedAlbum.AlbumName } else { 'New Album Name' }
            MatchType    = 'album'
            LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'
        }
    )
}

function Add-MemoryOptimization { }

function Get-CollectionSizeRecommendations {
    param([int]$AlbumCount)
    return [pscustomobject]@{
        Warnings                   = @()
        Recommendations            = @()
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
        Name        = 'Forced Album Name'
        AlbumType   = 'album'
        ReleaseDate = '2024-01-01'
        Id          = $Id
        artists     = @([pscustomobject]@{ id = 'artist-123' })
    }
}

$script:CapturedRenameOps = $null
function Write-RenameOperation {
    param([object]$RenameMap, [string]$Mode)
    $script:CapturedRenameOps = [pscustomobject]@{ Mode = $Mode; Map = $RenameMap }
}

function Write-AlbumNoRenameNeeded {}
function Write-NothingToRenameMessage {}
function Write-WhatIfMessage {}
function Set-AudioFileTags {}
function Get-AudioFileTags {}
function Test-AudioFileCompleteness {}
function Test-AlbumDurationConsistency {}

# Load the helper under test
. .\Private\Invoke-MuFo-ArtistProcessing.ps1

function Invoke-MuFoArtistProcessingHarness {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $null = $PSCmdlet.ShouldProcess($script:CurrentArtistPath, 'Invoke-MuFoArtistProcessingHarness')
    return Invoke-MuFoArtistProcessing -ArtistPath $script:CurrentArtistPath -EffectiveExclusions @('Dummy') -DoIt 'Automatic' -ConfidenceThreshold 0.6 -SpotifyAlbumId '3BXSE3G8iFAVTJ65gufjKD' -CallerCmdlet $PSCmdlet -WhatIfPreference:$false
}

# Normal run (ShouldProcess returns true by default)
$normalEnv = Initialize-TestEnvironment -Suffix 'Normal'
$script:RequestedAlbumId = $null
$normalResults = Invoke-MuFoArtistProcessingHarness
$normalArray = @($normalResults)

$normalSuccess = ($script:RequestedAlbumId -eq '3BXSE3G8iFAVTJ65gufjKD')
if ($normalSuccess) {
    Write-Host "✓ Forced Spotify album ID retrieved in normal run" -ForegroundColor Green
} else {
    Write-Host "✗ Forced Spotify album ID retrieval failed (normal run)" -ForegroundColor Red
}

if (-not (Test-Path -LiteralPath (Join-Path $normalEnv.ArtistPath 'Old Album')) -and (Test-Path -LiteralPath (Join-Path (Join-Path (Split-Path -Parent $normalEnv.ArtistPath) 'Test Artist (Spotify)') 'New Album Name'))) {
    Write-Host "✓ Rename executed when ShouldProcess allowed" -ForegroundColor Green
} else {
    Write-Host "✗ Rename did not execute as expected in normal run" -ForegroundColor Red
}

if ($normalArray.Count -eq 1 -and $normalArray[0].Decision -eq 'rename') {
    Write-Host "✓ Result reflects rename decision in normal run" -ForegroundColor Green
} else {
    Write-Host "✗ Result did not record rename decision" -ForegroundColor Red
}

# WhatIf run (ShouldProcess should decline)
$whatIfEnv = Initialize-TestEnvironment -Suffix 'WhatIf'
$script:RequestedAlbumId = $null
$whatIfResults = Invoke-MuFoArtistProcessingHarness -WhatIf
$whatIfArray = @($whatIfResults)

$whatIfSuccess = ($script:RequestedAlbumId -eq '3BXSE3G8iFAVTJ65gufjKD')
if ($whatIfSuccess) {
    Write-Host "✓ Forced Spotify album ID retrieved in WhatIf run" -ForegroundColor Green
} else {
    Write-Host "✗ Forced Spotify album ID retrieval failed (WhatIf run)" -ForegroundColor Red
}

if ((Test-Path -LiteralPath (Join-Path $whatIfEnv.ArtistPath 'Old Album')) -and (Test-Path -LiteralPath $whatIfEnv.ArtistPath)) {
    Write-Host "✓ Rename suppressed when running with -WhatIf" -ForegroundColor Green
} else {
    Write-Host "✗ Rename executed despite -WhatIf" -ForegroundColor Red
}

$whatIfDecision = if ($whatIfArray.Count -gt 0) { $whatIfArray[0].Decision } else { '<none>' }
$whatIfReason = if ($whatIfArray.Count -gt 0) { $whatIfArray[0].Reason } else { '<none>' }
Write-Host ("  WhatIf decision: {0}, reason: {1}" -f $whatIfDecision, ($whatIfReason ?? '<null>')) -ForegroundColor DarkGray

if ($whatIfArray.Count -eq 1 -and $whatIfArray[0].Decision -eq 'rename') {
    Write-Host "✓ Result indicates rename would occur without -WhatIf" -ForegroundColor Green
} else {
    Write-Host "✗ Result decision did not reflect expected rename intent" -ForegroundColor Red
}

# Cleanup
foreach ($root in @($normalEnv.Root, $whatIfEnv.Root)) {
    if (Test-Path $root) {
        Remove-Item -Path $root -Recurse -Force
    }
}

Write-Host "=== Invoke-MuFoArtistProcessing ShouldProcess test complete ===" -ForegroundColor Cyan