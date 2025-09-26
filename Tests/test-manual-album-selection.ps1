# Tests for Manual mode album selection in Invoke-MuFoArtistProcessing# Tests for Manual mode album selection in Invoke-MuFoArtistProcessing

Write-Host "=== Testing Manual Mode Album Selection ===" -ForegroundColor CyanWrite-Host "=== Testing Manual Mode Album Selection ===" -ForegroundColor Cyan



$testRoot = Join-Path $env:TEMP "MuFo-ManualSelection"$testRoot = Join-Path $env:TEMP "MuFo-ManualSelection"

if (Test-Path $testRoot) {if (Test-Path $testRoot) {

    Remove-Item -Path $testRoot -Recurse -Force    Remove-Item -Path $testRoot -Recurse -Force

}}

New-Item -ItemType Directory -Path $testRoot | Out-NullNew-Item -ItemType Directory -Path $testRoot | Out-Null



$artistPath = Join-Path $testRoot 'Test Artist'$artistPath = Join-Path $testRoot 'Test Artist'

New-Item -ItemType Directory -Path $artistPath | Out-NullNew-Item -ItemType Directory -Path $artistPath | Out-Null

$albumPath = Join-Path $artistPath 'Old Album'$albumPath = Join-Path $artistPath 'Old Album'

New-Item -ItemType Directory -Path $albumPath | Out-NullNew-Item -ItemType Directory -Path $albumPath | Out-Null



# Stub dependencies used by the helper# Stub dependencies used by the helper

function Get-ExclusionsStorePath {function Get-ExclusionsStorePath {

    return [pscustomobject]@{ Dir = $testRoot; File = Join-Path $testRoot 'exclusions.json' }    return [pscustomobject]@{ Dir = $testRoot; File = Join-Path $testRoot 'exclusions.json' }

}}



function Get-SpotifyArtist {function Get-SpotifyArtist {

    param([string]$ArtistName)    param([string]$ArtistName)

    return @([pscustomobject]@{    return @([pscustomobject]@{

        Score  = 95        Score  = 95

        Artist = [pscustomobject]@{ Name = "$ArtistName (Spotify)"; Id = 'artist-123' }        Artist = [pscustomobject]@{ Name = "$ArtistName (Spotify)"; Id = 'artist-123' }

    })    })

}}



function Get-StringSimilarity {function Get-StringSimilarity {

    param([string]$String1, [string]$String2)    param([string]$String1, [string]$String2)

    return 0.95    return 0.95

}}



function Get-ArtistSelection {function Get-ArtistSelection {

    param([string]$LocalArtist, [object]$TopMatches)    param([string]$LocalArtist, [object]$TopMatches)

    return [pscustomobject]@{    return [pscustomobject]@{

        SelectedArtist   = [pscustomobject]@{ Name = "$LocalArtist (Spotify)"; Id = 'artist-123' }        SelectedArtist   = [pscustomobject]@{ Name = "$LocalArtist (Spotify)"; Id = 'artist-123' }

        SelectionSource  = 'search'        SelectionSource  = 'search'

    }    }

}}



function Write-ArtistTypoWarning {}function Write-ArtistTypoWarning {}



function Get-ArtistRenameProposal {function Get-ArtistRenameProposal {

    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string]$SelectionSource)    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string]$SelectionSource)

    return [pscustomobject]@{    return [pscustomobject]@{

        ProposedName = $SelectedArtist.Name        ProposedName = $SelectedArtist.Name

        TargetPath   = Join-Path -Path (Split-Path -Parent -Path $CurrentPath) -ChildPath $SelectedArtist.Name        TargetPath   = Join-Path -Path (Split-Path -Parent -Path $CurrentPath) -ChildPath $SelectedArtist.Name

    }    }

}}



$script:AlbumComparisonsCallCount = 0$script:AlbumComparisonsCallCount = 0

function Get-AlbumComparisons {function Get-AlbumComparisons {

    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string[]]$EffectiveExclusions, [object]$ForcedAlbum)    param([string]$CurrentPath, [pscustomobject]$SelectedArtist, [string[]]$EffectiveExclusions, [object]$ForcedAlbum)

    $script:AlbumComparisonsCallCount++    $script:AlbumComparisonsCallCount++

    if ($ForcedAlbum) {    if ($ForcedAlbum) {

        # When forced album is provided, return only that album        # When forced album is provided, return only that album

        return @(        return @(

            [pscustomobject]@{            [pscustomobject]@{

                MatchScore   = 1.0                MatchScore   = 1.0

                ProposedName = $ForcedAlbum.Name                ProposedName = $ForcedAlbum.Name

                LocalAlbum   = 'Old Album'                LocalAlbum   = 'Old Album'

                LocalNorm    = 'Old Album'                LocalNorm    = 'Old Album'

                MatchName    = $ForcedAlbum.Name                MatchName    = $ForcedAlbum.Name

                MatchType    = $ForcedAlbum.AlbumType                MatchType    = $ForcedAlbum.AlbumType

                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'

                MatchedItem  = [pscustomobject]@{                MatchedItem  = [pscustomobject]@{

                    Item = $ForcedAlbum                    Item = $ForcedAlbum

                }                }

            }            }

        )        )

    } else {    } else {

        # Return candidates for selection        # Return candidates for selection

        return @(        return @(

            [pscustomobject]@{            [pscustomobject]@{

                MatchScore   = 0.92                MatchScore   = 0.92

                ProposedName = 'Album One'                ProposedName = 'Album One'

                LocalAlbum   = 'Old Album'                LocalAlbum   = 'Old Album'

                LocalNorm    = 'Old Album'                LocalNorm    = 'Old Album'

                MatchName    = 'Album One'                MatchName    = 'Album One'

                MatchType    = 'album'                MatchType    = 'album'

                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'

                MatchedItem  = [pscustomobject]@{                MatchedItem  = [pscustomobject]@{

                    Item = [pscustomobject]@{ Id = 'album-1' }                    Item = [pscustomobject]@{ Id = 'album-1' }

                }                }

            },            },

            [pscustomobject]@{            [pscustomobject]@{

                MatchScore   = 0.85                MatchScore   = 0.85

                ProposedName = 'Album Two'                ProposedName = 'Album Two'

                LocalAlbum   = 'Old Album'                LocalAlbum   = 'Old Album'

                LocalNorm    = 'Old Album'                LocalNorm    = 'Old Album'

                MatchName    = 'Album Two'                MatchName    = 'Album Two'

                MatchType    = 'album'                MatchType    = 'album'

                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'                LocalPath    = Join-Path -Path $CurrentPath -ChildPath 'Old Album'

                MatchedItem  = [pscustomobject]@{                MatchedItem  = [pscustomobject]@{

                    Item = [pscustomobject]@{ Id = 'album-2' }                    Item = [pscustomobject]@{ Id = 'album-2' }

                }                }

            }            }

        )        )

    }    }

}}



function Add-MemoryOptimization { }function Add-MemoryOptimization { }



function Get-CollectionSizeRecommendations {function Get-CollectionSizeRecommendations {

    param([int]$AlbumCount)    param([int]$AlbumCount)

    return [pscustomobject]@{    return [pscustomobject]@{

        Warnings                  = @()        Warnings                  = @()

        Recommendations           = @()        Recommendations           = @()

        EstimatedProcessingMinutes = 1        EstimatedProcessingMinutes = 1

    }    }

}}



function Optimize-SpotifyTrackValidation {function Optimize-SpotifyTrackValidation {

    param($Comparisons)    param($Comparisons)

    return $Comparisons    return $Comparisons

}}



$script:RequestedAlbumId = $null$script:RequestedAlbumId = $null

function Get-Album {function Get-Album {

    param([string]$Id)    param([string]$Id)

    $script:RequestedAlbumId = $Id    $script:RequestedAlbumId = $Id

    return [pscustomobject]@{    return [pscustomobject]@{

        Name        = 'Selected Album'        Name        = 'Selected Album'

        AlbumType   = 'album'        AlbumType   = 'album'

        ReleaseDate = '2024-01-01'        ReleaseDate = '2024-01-01'

        Id          = $Id        Id          = $Id

        artists     = @([pscustomobject]@{ id = 'artist-123' })        artists     = @([pscustomobject]@{ id = 'artist-123' })

    }    }

}}



$script:CapturedRenameOps = $null$script:CapturedRenameOps = $null

function Write-RenameOperation {function Write-RenameOperation {

    param([object]$RenameMap, [string]$Mode)    param([object]$RenameMap, [string]$Mode)

    $mapCopy = @{}    $mapCopy = @{}

    if ($RenameMap -is [System.Collections.IDictionary]) {    if ($RenameMap -is [System.Collections.IDictionary]) {

        foreach ($key in $RenameMap.Keys) {        foreach ($key in $RenameMap.Keys) {

            $mapCopy[$key] = $RenameMap[$key]            $mapCopy[$key] = $RenameMap[$key]

        }        }

    }    }

    $script:CapturedRenameOps = [pscustomobject]@{ Mode = $Mode; Map = $mapCopy }    $script:CapturedRenameOps = [pscustomobject]@{ Mode = $Mode; Map = $mapCopy }

}}



function Write-ArtistRenameMessage {}function Write-ArtistRenameMessage {}

function Write-AlbumNoRenameNeeded {}function Write-AlbumNoRenameNeeded {}

function Write-NothingToRenameMessage {}function Write-NothingToRenameMessage {}

function Write-WhatIfMessage {}function Write-WhatIfMessage {}

function Test-AudioFileCompleteness {}function Test-AudioFileCompleteness {}

function Set-AudioFileTags {}function Set-AudioFileTags {}

function Get-AudioFileTags {}function Get-AudioFileTags {}

function Test-AlbumDurationConsistency {}function Test-AlbumDurationConsistency {}



# Mock Read-Host for Manual mode selection# Mock Read-Host for Manual mode selection

$script:ReadHostCalls = @()$script:ReadHostCalls = @()

function Read-Host {function Read-Host {

    param([string]$Prompt)    param([string]$Prompt)

    $script:ReadHostCalls += $Prompt    $script:ReadHostCalls += $Prompt

    # Simulate user choosing option 1 (first album)    # Simulate user choosing option 1 (first album)

    return '1'    return '1'

}}



# Load the helper under test# Load the helper under test

. .\Private\Invoke-MuFo-ArtistProcessing.ps1. .\Private\Invoke-MuFo-ArtistProcessing.ps1



# Reset counters# Reset counters

$script:AlbumComparisonsCallCount = 0$script:AlbumComparisonsCallCount = 0

$script:RequestedAlbumId = $null$script:RequestedAlbumId = $null

$script:ReadHostCalls = @()$script:ReadHostCalls = @()



# Test Manual mode album selection# Test Manual mode album selection

$results = Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview$results = Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview



# Verify Get-AlbumComparisons was called twice (once for selection, once for processing)# Verify Get-AlbumComparisons was called twice (once for selection, once for processing)

if ($script:AlbumComparisonsCallCount -eq 2) {if ($script:AlbumComparisonsCallCount -eq 2) {

    Write-Host "✓ Get-AlbumComparisons called twice (selection + processing)" -ForegroundColor Green    Write-Host "✓ Get-AlbumComparisons called twice (selection + processing)" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Get-AlbumComparisons call count unexpected: $script:AlbumComparisonsCallCount" -ForegroundColor Red    Write-Host "✗ Get-AlbumComparisons call count unexpected: $script:AlbumComparisonsCallCount" -ForegroundColor Red

}}



# Verify Read-Host was called for album selection# Verify Read-Host was called for album selection

if ($script:ReadHostCalls.Count -ge 1 -and $script:ReadHostCalls[0] -match 'Choose album') {if ($script:ReadHostCalls.Count -ge 1 -and $script:ReadHostCalls[0] -match 'Choose album') {

    Write-Host "✓ Read-Host called for album selection" -ForegroundColor Green    Write-Host "✓ Read-Host called for album selection" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Read-Host not called for album selection" -ForegroundColor Red    Write-Host "✗ Read-Host not called for album selection" -ForegroundColor Red

}}



# Verify the correct album ID was requested (album-1, the first choice)# Verify the correct album ID was requested (album-1, the first choice)

if ($script:RequestedAlbumId -eq 'album-1') {if ($script:RequestedAlbumId -eq 'album-1') {

    Write-Host "✓ Correct album ID requested for forced selection" -ForegroundColor Green    Write-Host "✓ Correct album ID requested for forced selection" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Incorrect album ID requested: $script:RequestedAlbumId" -ForegroundColor Red    Write-Host "✗ Incorrect album ID requested: $script:RequestedAlbumId" -ForegroundColor Red

}}



# Verify results contain the selected album# Verify results contain the selected album

$resultsArray = @($results)$resultsArray = @($results)

if ($resultsArray.Count -eq 1 -and $resultsArray[0].SpotifyAlbum -eq 'Selected Album') {if ($resultsArray.Count -eq 1 -and $resultsArray[0].SpotifyAlbum -eq 'Selected Album') {

    Write-Host "✓ Results reflect selected album" -ForegroundColor Green    Write-Host "✓ Results reflect selected album" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Results do not reflect selected album" -ForegroundColor Red    Write-Host "✗ Results do not reflect selected album" -ForegroundColor Red

}}



# Test Manual mode with pre-set SpotifyAlbumId (should skip selection)# Test Manual mode with pre-set SpotifyAlbumId (should skip selection)

$script:AlbumComparisonsCallCount = 0$script:AlbumComparisonsCallCount = 0

$script:RequestedAlbumId = $null$script:RequestedAlbumId = $null

$script:ReadHostCalls = @()$script:ReadHostCalls = @()



Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview -SpotifyAlbumId 'pre-set-id'Invoke-MuFoArtistProcessing -ArtistPath $artistPath -EffectiveExclusions @('Dummy') -DoIt 'Manual' -ConfidenceThreshold 0.6 -Preview -SpotifyAlbumId 'pre-set-id'



# Should only call Get-AlbumComparisons once (for processing, not selection)# Should only call Get-AlbumComparisons once (for processing, not selection)

if ($script:AlbumComparisonsCallCount -eq 1) {if ($script:AlbumComparisonsCallCount -eq 1) {

    Write-Host "✓ Pre-set SpotifyAlbumId skips selection phase" -ForegroundColor Green    Write-Host "✓ Pre-set SpotifyAlbumId skips selection phase" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Pre-set SpotifyAlbumId did not skip selection: $script:AlbumComparisonsCallCount calls" -ForegroundColor Red    Write-Host "✗ Pre-set SpotifyAlbumId did not skip selection: $script:AlbumComparisonsCallCount calls" -ForegroundColor Red

}}



# Verify Read-Host was not called# Verify Read-Host was not called

if ($script:ReadHostCalls.Count -eq 0) {if ($script:ReadHostCalls.Count -eq 0) {

    Write-Host "✓ Read-Host not called when SpotifyAlbumId pre-set" -ForegroundColor Green    Write-Host "✓ Read-Host not called when SpotifyAlbumId pre-set" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Read-Host called unexpectedly with pre-set ID" -ForegroundColor Red    Write-Host "✗ Read-Host called unexpectedly with pre-set ID" -ForegroundColor Red

}}



# Verify pre-set ID was requested# Verify pre-set ID was requested

if ($script:RequestedAlbumId -eq 'pre-set-id') {if ($script:RequestedAlbumId -eq 'pre-set-id') {

    Write-Host "✓ Pre-set SpotifyAlbumId used correctly" -ForegroundColor Green    Write-Host "✓ Pre-set SpotifyAlbumId used correctly" -ForegroundColor Green

} else {} else {

    Write-Host "✗ Pre-set SpotifyAlbumId not used: $script:RequestedAlbumId" -ForegroundColor Red    Write-Host "✗ Pre-set SpotifyAlbumId not used: $script:RequestedAlbumId" -ForegroundColor Red

}}



# Cleanup# Cleanup

if (Test-Path $testRoot) {if (Test-Path $testRoot) {

    Remove-Item -Path $testRoot -Recurse -Force    Remove-Item -Path $testRoot -Recurse -Force

}}



Write-Host "=== Manual Mode Album Selection tests complete ===" -ForegroundColor CyanWrite-Host "=== Manual Mode Album Selection tests complete ===" -ForegroundColor Cyan