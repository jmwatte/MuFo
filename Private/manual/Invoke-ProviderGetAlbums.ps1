function Invoke-ProviderGetAlbums {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$ArtistId,  # For Spotify: ID; for Qobuz: full href; for Discogs: numeric ID

        [Parameter()]
        [string]$AlbumType = 'Album'  # For Spotify compatibility
    )

    switch ($Provider) {
        'Spotify' { Get-ArtistAlbums -Id $ArtistId -Album }
        'Qobuz'   { Get-QArtistAlbums -Id $ArtistId }  # $ArtistId is $href
        'Discogs' { Get-DArtistAlbums -Id $ArtistId }
    }
}