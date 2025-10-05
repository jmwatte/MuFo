function Invoke-ProviderGetTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$AlbumId
    )

    switch ($Provider) {
        'Spotify' { Get-AlbumTracks -Id $AlbumId }
        'Qobuz'   { Get-QAlbumTracks -Id $AlbumId }
        'Discogs' { Get-DAlbumTracks -Id $AlbumId }
    }
}