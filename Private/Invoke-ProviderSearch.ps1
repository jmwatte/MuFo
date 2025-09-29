function Invoke-ProviderSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Query,

        [Parameter(Mandatory)]
        [ValidateSet('artist')]
        [string]$Type
    )

    switch ($Provider) {
        'Spotify' { Search-Item -Query $Query -Type $Type }
        'Qobuz'   { Search-QItem -Query $Query -Type $Type }
    }
}