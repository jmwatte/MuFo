function Get-MuFoStats {
    <#
    .SYNOPSIS
        Compares a local album folder to a Spotify album and returns detailed comparison statistics.

    .DESCRIPTION
        This function analyzes a local album folder (where the parent folder is the artist) against a Spotify album ID or album object.
        It returns a comprehensive object containing folder properties, local track data, Spotify data, and comparison metrics
        to help guide user decisions for renaming, tagging, or validation.

    .PARAMETER AlbumFolder
        The full path to the album folder to analyze.

    .PARAMETER SpotifyAlbumId
        The Spotify album ID to compare against.

    .PARAMETER SpotifyAlbumObject
        A pre-fetched Spotify album object from Get-Album to avoid additional API calls.

    .EXAMPLE
        $stats = Get-MuFoStats -AlbumFolder "C:\Music\Artist\Album" -SpotifyAlbumId "1234567890"
        $stats.Comparison.TrackCountDifference

    .EXAMPLE
        $album = Get-Album -Id "1234567890"
        $stats = Get-MuFoStats -AlbumFolder "C:\Music\Artist\Album" -SpotifyAlbumObject $album
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AlbumFolder,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string]$SpotifyAlbumId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByObject')]
        [object]$SpotifyAlbumObject
    )

    # Validate inputs
    if (-not (Test-Path $AlbumFolder)) {
        throw "Album folder does not exist: $AlbumFolder"
    }

    # Get folder info
    $folderInfo = Get-Item $AlbumFolder
    $artistFolder = Split-Path $AlbumFolder -Parent
    $artistName = Split-Path $artistFolder -Leaf

    # Get local audio files
    $audioFiles = Get-ChildItem $AlbumFolder -File | Where-Object {
        $_.Extension -in @('.mp3', '.flac', '.m4a', '.wav', '.aac', '.ogg')
    }

    # Get local tracks data
    $localTracks = @()
    $localTags = @{}
    foreach ($file in $audioFiles) {
        $tags = Get-AudioFileTags -Path $file.FullName
        if ($tags) {
            $localTracks += [PSCustomObject]@{
                FileName = $file.Name
                TrackNumber = $tags.Track
                Title = $tags.Title
                Artist = $tags.Artist
                AlbumArtist = $tags.AlbumArtist
                Album = $tags.Album
                Year = $tags.Year
                Duration = $tags.Duration
                DiscNumber = $tags.DiscNumber
            }

            # Collect all unique tag names dynamically
            $tagProperties = $tags | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
            foreach ($tagName in $tagProperties) {
                $tagValue = $tags.$tagName
                if (-not $localTags.ContainsKey($tagName)) {
                    $localTags[$tagName] = @()
                }
                $localTags[$tagName] += $tagValue
            }
        }
    }

    # Get Spotify album data
    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $spotifyAlbum = Get-Album -Id $SpotifyAlbumId
        if (-not $spotifyAlbum) {
            throw "Failed to retrieve Spotify album for ID: $SpotifyAlbumId"
        }
        $spotifyTracks = Get-SpotifyAlbumTracks -AlbumId $SpotifyAlbumId
    } else {
        $spotifyAlbum = $SpotifyAlbumObject
        $spotifyTracks = Get-SpotifyAlbumTracks -AlbumId $spotifyAlbum.Id
    }

    # Build Spotify tracks object
    $spotifyTrackList = @()
    foreach ($track in $spotifyTracks) {
        $trackArtists = $track.artists -join ', '
        $spotifyTrackList += [PSCustomObject]@{
            TrackNumber = $track.track_number
            Title = $track.name
            Artist = $trackArtists
            AlbumArtist = $spotifyAlbum.artists[0].name
            Album = $spotifyAlbum.name
            Year = [int]($spotifyAlbum.release_date -split '-')[0]
            Duration = [int]($track.duration_ms / 1000)
            DiscNumber = $track.disc_number
        }
    }

    # Collect Spotify tags (including genres if available)
    $spotifyTags = @{}
    if ($spotifyAlbum.genres) {
        $spotifyTags['Genres'] = $spotifyAlbum.genres
    }
    $spotifyTags['AlbumArtist'] = @($spotifyAlbum.artists[0].name)
    $spotifyTags['Album'] = @($spotifyAlbum.name)
    $spotifyTags['Year'] = @([int]($spotifyAlbum.release_date -split '-')[0])

    # Comparisons
    $localTrackCount = $localTracks.Count
    $spotifyTrackCount = $spotifyTrackList.Count
    $trackCountDifference = $localTrackCount - $spotifyTrackCount

    # Name similarities
    $albumSimilarity = Get-StringSimilarity -String1 ($localTracks | Where-Object { $_.Album } | Select-Object -First 1).Album -String2 $spotifyAlbum.name
    $artistSimilarity = Get-StringSimilarity -String1 $artistName -String2 $spotifyAlbum.artists[0].name

    # Track matching (basic count of matching titles)
    $matchingTracks = 0
    foreach ($localTrack in $localTracks) {
        $bestMatch = $spotifyTrackList | Where-Object { (Get-StringSimilarity -String1 $localTrack.Title -String2 $_.Title) -gt 0.8 } | Select-Object -First 1
        if ($bestMatch) { $matchingTracks++ }
    }

    # Multi-disc handling
    $localDiscs = $localTracks | Group-Object DiscNumber | Measure-Object | Select-Object -ExpandProperty Count
    $spotifyDiscs = $spotifyTrackList | Group-Object DiscNumber | Measure-Object | Select-Object -ExpandProperty Count

    # Return comprehensive object
    [PSCustomObject]@{
        Folder = [PSCustomObject]@{
            Path = $AlbumFolder
            ArtistName = $artistName
            AlbumName = $folderInfo.Name
            FileCount = $audioFiles.Count
            DiscCount = $localDiscs
        }
        Local = [PSCustomObject]@{
            Tracks = $localTracks
            TrackCount = $localTrackCount
            Tags = $localTags
            AlbumName = ($localTracks | Where-Object { $_.Album } | Select-Object -First 1).Album
            AlbumArtist = ($localTracks | Where-Object { $_.AlbumArtist } | Select-Object -First 1).AlbumArtist
            Year = ($localTracks | Where-Object { $_.Year } | Select-Object -First 1).Year
        }
        Spotify = [PSCustomObject]@{
            AlbumId = $SpotifyAlbumId
            AlbumName = $spotifyAlbum.name
            AlbumArtist = $spotifyAlbum.artists[0].name
            Year = [int]($spotifyAlbum.release_date -split '-')[0]
            Tracks = $spotifyTrackList
            TrackCount = $spotifyTrackCount
            Tags = $spotifyTags
            DiscCount = $spotifyDiscs
        }
        Comparison = [PSCustomObject]@{
            TrackCountDifference = $trackCountDifference
            AlbumNameSimilarity = $albumSimilarity
            ArtistNameSimilarity = $artistSimilarity
            MatchingTracks = $matchingTracks
            DiscCountDifference = $localDiscs - $spotifyDiscs
            DurationDifferences = @()  # Placeholder for duration comparisons
            YearDifference = [math]::Abs(($localTracks | Where-Object { $_.Year } | Select-Object -First 1).Year - [int]($spotifyAlbum.release_date -split '-')[0])
        }
    }
}