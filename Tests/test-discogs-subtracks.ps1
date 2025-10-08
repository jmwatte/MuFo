#Requires -Version 7.3

Write-Host "`n=== Discogs Sub-Track Parsing Test ===" -ForegroundColor Cyan

Remove-Module MuFo -ErrorAction SilentlyContinue

$moduleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $moduleRoot 'Private\manual\Get-DAlbumTracks.ps1')

function Invoke-DiscogsRequest {
    param(
        [string]$Uri
    )

    return [pscustomobject]@{
        artists  = @(
            [pscustomobject]@{ name = 'Berliner Philharmoniker' }
        )
        tracklist = @(
            [pscustomobject]@{
                position     = ''
                type_        = 'index'
                title        = 'Symphonie A-Dur KV 201'
                duration     = '23:08'
                extraartists = @(
                    [pscustomobject]@{ name = 'Wolfgang Amadeus Mozart'; role = 'Composed By' }
                    [pscustomobject]@{ name = 'Herbert von Karajan'; role = 'Conductor' }
                )
                sub_tracks   = @(
                    [pscustomobject]@{
                        position = '1-1'
                        type_    = 'track'
                        title    = 'Allegro Con Spirito'
                        duration = ''
                    }
                    [pscustomobject]@{
                        position = '1-2'
                        type_    = 'track'
                        title    = 'Andante'
                        duration = ''
                    }
                    [pscustomobject]@{
                        position = '1-3'
                        type_    = 'track'
                        title    = 'Menuetto Allegretto'
                        duration = ''
                    }
                    [pscustomobject]@{
                        position = '1-4'
                        type_    = 'track'
                        title    = 'Allegro Con Spirito'
                        duration = ''
                    }
                )
            }
        )
    }
}

$tracks = Get-DAlbumTracks -Id 999999

if ($tracks.Count -ne 4) {
    throw "Expected 4 sub-tracks, found $($tracks.Count)."
}

$expectedTitles = 'Allegro Con Spirito','Andante','Menuetto Allegretto','Allegro Con Spirito'

for ($i = 0; $i -lt $tracks.Count; $i++) {
    $track = $tracks[$i]
    $expectedTitle = $expectedTitles[$i]

    if ($track.name -ne $expectedTitle) {
        throw "Track $i title mismatch. Expected '$expectedTitle', got '$($track.name)'."
    }

    if ($track.track_number -ne ($i + 1)) {
        throw "Track $i number mismatch. Expected $($i + 1), got $($track.track_number)."
    }

    if (-not $track.composer -or -not ($track.composer -contains 'Wolfgang Amadeus Mozart')) {
        throw "Track $i missing composer metadata."
    }

    if ($track.Conductor -ne 'Herbert von Karajan') {
        throw "Track $i missing conductor metadata."
    }

    if (-not $track.artists -or $track.artists.Count -eq 0) {
        throw "Track $i has no artist entries."
    }
}

Write-Host "✓ Discogs sub-track parsing test passed" -ForegroundColor Green
