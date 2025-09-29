# Private/QGet-AlbumTracks.ps1
function Get-QAlbumTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id  # Album ID, e.g., "0603497922215"
    )

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
    }
    Import-Module PowerHTML

    # Construct the album page URL (assuming be-fr locale)
    $url = "https://www.qobuz.com/be-fr/album/album-slug/$Id"

    try {
        # Fetch the HTML
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $html = $response.Content

        # Parse with PowerHTML
        $doc = ConvertFrom-Html -Content $html

        # Select all track divs
        $trackDivs = $doc.SelectNodes('//div[@class="track"]')

        $tracks = @()
        $trackNumber = 1
        foreach ($trackDiv in $trackDivs) {
            $trackId = $trackDiv.GetAttributeValue('data-track', '')
            $durationMs = [int]($trackDiv.GetAttributeValue('data-duration', '0'))

            # Get title from track__item--name
            $nameDiv = $trackDiv.SelectSingleNode('.//div[@class="track__item track__item--name"]')
            $title = if ($nameDiv) { $nameDiv.InnerText.Trim() } else { '' }

            # Get artist from data-track-v2 JSON
            $trackV2 = $trackDiv.GetAttributeValue('data-track-v2', '')
            $artist = ''
            if ($trackV2) {
                try {
                    $json = $trackV2 | ConvertFrom-Json
                    $artist = $json.item_brand
                } catch {
                    # Fallback
                }
            }

            # Create the track object (similar to Spotify)
            $track = [PSCustomObject]@{
                id           = $trackId
                name         = $title
                disc_number  = 1  # Assume single disc
                track_number = $trackNumber
                duration_ms  = $durationMs
                artists      = [PSCustomObject]@{ name = $artist }
            }
            $tracks += $track
            $trackNumber++
        }

        $tracks
    }
    catch {
        Write-Warning "Qobuz album tracks fetch failed: $_"
        @()
    }
}