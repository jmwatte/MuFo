function Invoke-ProviderGetAlbums {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$ArtistId,  # For Spotify: ID; for Qobuz: full href

        [Parameter()]
        [string]$AlbumType = 'Album'  # For Spotify compatibility
    )

    switch ($Provider) {
        'Spotify' { Get-ArtistAlbums -Id $ArtistId -Album }
        'Qobuz'   { QGet-ArtistAlbums -Id $ArtistId }  # $ArtistId is $href
    }
}