function Get-ManualAlbumSelection {
    <#
    .SYNOPSIS
        Presents album candidates for Manual mode selection.

    .PARAMETER ArtistPath
        Path to the artist folder.

    .PARAMETER SelectedArtist
        The selected Spotify artist object.

    .PARAMETER EffectiveExclusions
        Array of exclusion patterns.

    .PARAMETER IncludeSingles
        Include singles in album fetch.

    .PARAMETER IncludeCompilations
        Include compilations in album fetch.

    .OUTPUTS
        The Spotify album ID of the selected album, or $null if skipped.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ArtistPath,

        [Parameter(Mandatory)]
        [object]$SelectedArtist,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$EffectiveExclusions,

        [switch]$IncludeSingles,

        [switch]$IncludeCompilations
    )

    Write-Host "Fetching album candidates for '$($SelectedArtist.Name)'..." -ForegroundColor Cyan

    # Get all albums for the selected artist
    $spotifyAlbums = Get-SpotifyArtistAlbums -ArtistId $SelectedArtist.Id -IncludeSingles:$IncludeSingles -IncludeCompilations:$IncludeCompilations

    if (-not $spotifyAlbums -or $spotifyAlbums.Count -eq 0) {
        Write-Warning "No albums found for '$($SelectedArtist.Name)'"
        return $null
    }

    # Get local album folders
    $localAlbumPaths = Get-ChildItem -LiteralPath $ArtistPath -Directory | Where-Object {
        $folderName = $_.Name
        -not ($EffectiveExclusions | Where-Object { $folderName -like $_ })
    }

    if ($localAlbumPaths.Count -eq 0) {
        Write-Warning "No local album folders found in '$ArtistPath'"
        return $null
    }

    # For each local album, find best Spotify matches
    $candidates = @()
    foreach ($localAlbumPath in $localAlbumPaths) {
        $localAlbumName = $localAlbumPath.Name
        $localNormalized = ConvertTo-ComparableName -Name $localAlbumName

        $albumMatches = @()
        foreach ($spotifyAlbum in $spotifyAlbums) {
            $spotifyNormalized = ConvertTo-ComparableName -Name $spotifyAlbum.Name
            $score = Get-StringSimilarity -String1 $localNormalized -String2 $spotifyNormalized

            $albumMatches += [PSCustomObject]@{
                LocalAlbum     = $localAlbumName
                LocalPath      = $localAlbumPath.FullName
                SpotifyAlbum   = $spotifyAlbum.Name
                SpotifyId      = $spotifyAlbum.Id
                AlbumType      = $spotifyAlbum.AlbumType
                ReleaseDate    = $spotifyAlbum.ReleaseDate
                Score          = $score
            }
        }

        # Take top 3 matches for this local album
        $topMatches = $albumMatches | Sort-Object -Property Score -Descending | Select-Object -First 3
        $candidates += $topMatches
    }

    # Sort all candidates by score descending and display
    $candidates = $candidates | Sort-Object -Property Score -Descending

    $localArtist = Split-Path -Path $ArtistPath -Leaf
    Write-Host "`nAlbum candidates for $localArtist ($($SelectedArtist.Name)):" -ForegroundColor Yellow
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $c = $candidates[$i]
        $year = if ($c.ReleaseDate) { (Get-Date $c.ReleaseDate).Year } else { "Unknown" }
        Write-Host "$($i+1). $($c.SpotifyAlbum) ($year, $($c.AlbumType)) - Score: $([math]::Round($c.Score, 2)) [for '$($c.LocalAlbum)']"
    }

    $validChoice = $false
    $chosenIndex = -1
    while (-not $validChoice) {
        $choice = Read-Host "`nChoose album (1-$($candidates.Count)) or 0 to skip this artist"
        if ($choice -match '^\d+$') {
            $choiceNum = [int]$choice
            if ($choiceNum -eq 0) {
                Write-Host "Skipping album selection for this artist"
                return $null
            }
            elseif ($choiceNum -ge 1 -and $choiceNum -le $candidates.Count) {
                $chosenIndex = $choiceNum - 1
                $validChoice = $true
            }
            else {
                Write-Host "Invalid choice. Please enter a number between 0 and $($candidates.Count)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
        }
    }

    $chosen = $candidates[$chosenIndex]
    Write-Host "Selected album: $($chosen.SpotifyAlbum) (ID: $($chosen.SpotifyId)) for '$($chosen.LocalAlbum)'" -ForegroundColor Green
    return $chosen.SpotifyId
}