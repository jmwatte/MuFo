<#
    Tests basic combined pagination/command behaviour for Show-Tracks.
    The script is intentionally lightweight instead of using Pester so it matches
    the existing "tests/test-*.ps1" style in the repository.
#>

Set-StrictMode -Version Latest

$privateRoot = Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'Private'
. (Join-Path $privateRoot 'Get-IfExists.ps1')
. (Join-Path $privateRoot 'manual\Show-Tracks.ps1')

function New-TestPair {
    param(
        [int]$Index
    )

    $spotify = [PSCustomObject]@{
        name         = "Track $Index"
        disc_number  = 1
        track_number = $Index
        artists      = @([PSCustomObject]@{ name = 'Sample Artist' })
    }

    $audio = [PSCustomObject]@{
        Title      = "Track $Index"
        DiscNumber = 1
        TrackNumber= $Index
        Name       = "Track$Index.flac"
        FilePath   = "C:\\Music\\Track$Index.flac"
        Artist     = 'Sample Artist'
        Composer   = @('Composer')
        TagFile    = [PSCustomObject]@{
            tag = [PSCustomObject]@{ Genres = @('Genre') }
        }
    }

    return [PSCustomObject]@{
        SpotifyTrack = $spotify
        AudioFile    = $audio
    }
}

$pairedTracks = 1..15 | ForEach-Object { New-TestPair -Index $_ }
$commandList = @('d','t','n','l','h','m','r','st','sf','sa','b','w','whatif','skip')

function Invoke-ShowTracksScenario {
    param(
        [Parameter(Mandatory)]
        [string[]]$Inputs,

        [Parameter(Mandatory)]
        [string]$Expected,

        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    $script:__ShowTracksQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($entry in $Inputs) {
        $null = $script:__ShowTracksQueue.Enqueue($entry)
    }

    $reader = {
        param($prompt)
        if ($script:__ShowTracksQueue.Count -gt 0) {
            return $script:__ShowTracksQueue.Dequeue()
        }
        return ''
    }

    $result = Show-Tracks -PairedTracks $pairedTracks -AlbumName 'Test Album' -SpotifyArtist $null -OptionsText 'Test options' -ValidCommands $commandList -InputReader $reader
    if ($result -ne $Expected) {
        throw ($ErrorMessage -f $result)
    }
}

# Test 1: Paging forward once, then issuing a command.
Invoke-ShowTracksScenario -Inputs @('', 'st') -Expected 'st' -ErrorMessage "Expected 'st' after paging, but received '{0}'."

# Test 2: Next, previous, then command.
Invoke-ShowTracksScenario -Inputs @('n', 'p', 'sa') -Expected 'sa' -ErrorMessage "Expected 'sa' after navigation sequence, but received '{0}'."

# Test 3: Returning to classic options via 'q'.
Invoke-ShowTracksScenario -Inputs @('q') -Expected 'q' -ErrorMessage "Expected 'q' when quitting, but received '{0}'."

# Test 4: Invalid input handled before a valid command.
Invoke-ShowTracksScenario -Inputs @('foo', 'sf') -Expected 'sf' -ErrorMessage "Expected 'sf' after invalid retry, but received '{0}'."

Write-Host "All Show-Tracks pagination tests passed." -ForegroundColor Green
