# Tests for selective track save helpers

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

. (Join-Path $root 'Private\manual\Expand-SelectionRange.ps1')
. (Join-Path $root 'Private\manual\Save-MuFoTrackSelection.ps1')

Write-Host 'Running selective track save tests...' -ForegroundColor Cyan

# Test Expand-SelectionRange basic parsing
$indices = Expand-SelectionRange -RangeText '1, 3,5-6, 8..10' -MaxIndex 12
$expected = @(1,3,5,6,8,9,10)
if ($indices.Count -ne $expected.Count -or (Compare-Object -ReferenceObject $expected -DifferenceObject $indices)) {
    throw "Expand-SelectionRange parsing mismatch. Expected $expected, got $indices"
}

$threw = $false
try {
    Expand-SelectionRange -RangeText '2-15' -MaxIndex 10 | Out-Null
}
catch {
    $threw = $true
}
if (-not $threw) {
    throw 'Expand-SelectionRange should throw for out-of-range selections.'
}

# Prepare sample data for Save-MuFoTrackSelection
function New-AudioFile {
    param(
        [string]$Path,
        [int]$Disc,
        [int]$Track
    )
    $audio = [PSCustomObject]@{
        FilePath    = $Path
        DiscNumber  = $Disc
        TrackNumber = $Track
        Title       = "Audio-$Track"
        TagFile     = $null
    }
    return $audio
}

function New-SpotifyTrack {
    param(
        [string]$Name,
        [int]$Disc,
        [int]$Track
    )
    return [PSCustomObject]@{
        name         = $Name
        disc_number  = $Disc
        track_number = $Track
        duration_ms  = 180000
    }
}

$audio1 = New-AudioFile -Path 'track1.flac' -Disc 1 -Track 1
$audio2 = New-AudioFile -Path 'track2.flac' -Disc 1 -Track 2
$audio3 = New-AudioFile -Path 'track3.flac' -Disc 1 -Track 3

$spotify1 = New-SpotifyTrack -Name 'Track 1' -Disc 1 -Track 1
$spotify2 = New-SpotifyTrack -Name 'Track 2' -Disc 1 -Track 2
$spotify3 = New-SpotifyTrack -Name 'Track 3' -Disc 1 -Track 3

$pairedTracks = @(
    [PSCustomObject]@{ SpotifyTrack = $spotify1; AudioFile = $audio1 },
    [PSCustomObject]@{ SpotifyTrack = $spotify2; AudioFile = $null },
    [PSCustomObject]@{ SpotifyTrack = $spotify3; AudioFile = $audio3 }
)

$tagCalls = @()
$saveCalls = @()

$tagFactory = {
    param($artist, $album, $track)
    $tag = [PSCustomObject]@{
        Disc  = if ($track) { $track.disc_number } else { 0 }
        Track = if ($track) { $track.track_number } else { 0 }
        Title = if ($track) { $track.name } else { 'Unknown' }
    }
    $tagCalls += $tag
    return $tag
}

$tagSaver = {
    param($filePath, $tags, $useWhatIf)
    $saveCalls += [PSCustomObject]@{ FilePath = $filePath; Title = $tags.Title; WhatIf = $useWhatIf }
    if ($filePath -like '*3*') {
        return [PSCustomObject]@{ Success = $false; Reason = 'Simulated failure' }
    }
    return [PSCustomObject]@{ Success = $true }
}

$result = Save-MuFoTrackSelection `
    -PairedTracks $pairedTracks `
    -SelectedIndices @(1,2,3) `
    -ProviderArtist @{ name = 'Artist' } `
    -ProviderAlbum @{ name = 'Album' } `
    -UseWhatIf:$false `
    -TagFactory $tagFactory `
    -TagSaver $tagSaver

if ($result.SavedDetails.Count -ne 1 -or $result.SavedDetails[0].FilePath -ne 'track1.flac') {
    throw 'Expected only track1 to be saved successfully.'
}

if ($result.Skipped.Count -ne 1 -or $result.Skipped[0].Index -ne 2) {
    throw 'Expected track index 2 to be skipped because it lacks audio.'
}

if ($result.Failed.Count -ne 1 -or $result.Failed[0].Index -ne 3) {
    throw 'Expected track index 3 to record a failure entry.'
}

if ($result.UpdatedPairs.Count -ne 2) {
    throw "UpdatedPairs count unexpected: $($result.UpdatedPairs.Count)"
}

if ($result.UpdatedAudioFiles.Count -ne 1 -or $result.UpdatedAudioFiles[0].FilePath -ne 'track3.flac') {
    throw 'UpdatedAudioFiles should retain unsaved audio entries.'
}

if ($result.UpdatedSpotifyTracks.Count -ne 2) {
    throw 'UpdatedSpotifyTracks should retain Spotify entries for unsaved tracks.'
}

Write-Host 'All selective track save tests passed.' -ForegroundColor Green
