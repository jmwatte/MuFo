# Private/QGet-ArtistAlbums.ps1
function Get-QArtistAlbums {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Album')]
        [string]$Album  # For compatibility with Spotify API
    )

    # Ensure PowerHTML is available
    if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
        throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
    }
    Import-Module PowerHTML

    # Construct the artist page URL (assuming be-fr locale; artist slug is not needed for parsing)
    # Note: Qobuz artist pages are /be-fr/interpreter/slug/id, but we can fetch by ID if we know the slug, but since we don't, we'll assume the URL is provided or constructed.
    # For simplicity, we'll need the full URL or slug. In practice, you might need to store the slug from search.
    # For now, assuming we have the full URL or can construct it. Let's assume $Id is the full path or just ID.
    # To make it work, perhaps pass the artist URL.

    # For this example, assuming $Id is the artist ID, and we construct URL as /be-fr/interpreter/artist-slug/$Id, but slug is unknown.
    # Actually, from the search, we have the href like /be-fr/interpreter/zz-top/56332, so we can store the full href in the artist object.

    # To simplify, let's assume $Id is the full interpreter URL, e.g., "/be-fr/interpreter/zz-top/56332"
    if ($Id -notmatch '^/be-fr/interpreter/') {
        throw "Id must be the full Qobuz interpreter URL, e.g., /be-fr/interpreter/zz-top/56332"
    }

    $url = "https://www.qobuz.com$Id"

    try {
        # Fetch the HTML
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $html = $response.Content

        # Parse with PowerHTML
        $doc = ConvertFrom-Html -Content $html

        # Select album containers (assuming they are in divs with class containing 'product' or similar)
        # From the HTML, albums seem to be in sections with <a href="/be-fr/album/...">
        $albumLinks = $doc.SelectNodes('//a[contains(@href, "/album/")]')

        $albums = @()
        foreach ($link in $albumLinks) {
            $href = $link.GetAttributeValue('href', '')
            if (-not $href -or -not $href.Contains('/album/')) { continue }

            # Extract ID from href (e.g., /be-fr/album/tres-hombres-zz-top/0603497923984 -> 0603497923984)
            if ($href -match '/album/[^/]+/(\d+)$') {
                $albumId = $matches[1]
            } else {
                continue
            }

            # Find the associated product name and release date
            # The <a> is followed by <h3 class="product__name">
            $parent = $link.ParentNode
            $nameElement = $parent.SelectSingleNode('.//h3[@class="product__name"]')
            if (-not $nameElement) { continue }
            $name = $nameElement.GetAttributeValue('data-title', '') -or $nameElement.InnerText.Trim()

            $releaseElement = $parent.SelectSingleNode('.//p[@class="product__data--release"]')
            $releaseDate = if ($releaseElement) { $releaseElement.InnerText.Trim() } else { '' }



 # Extract genre
        $genreElement = $parent.SelectSingleNode('.//p[@class="product__data--genre"]')
        $genre = if ($genreElement) { $genreElement.InnerText.Trim() } else { '' }





            # Create the album object (similar to Spotify)
            $album = [PSCustomObject]@{
                name         = $name
                id           = $albumId
                release_date = $releaseDate
                genre        = $genre
            }
            $albums += $album
        }

        # Return the albums array
        $albums
    }
    catch {
        Write-Warning "Qobuz artist albums fetch failed: $_"
        @()
    }
}