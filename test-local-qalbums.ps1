# Test script for Get-QArtistAlbums parsing on local HTML file
param(
    [string]$HtmlFilePath = "c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QAlbumsForArtistSearch.html"
)

# Ensure PowerHTML is available
if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
    throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
}
Import-Module PowerHTML

# Load HTML from file
$html = Get-Content -Path $HtmlFilePath -Raw

# Parse with PowerHTML
$doc = ConvertFrom-Html -Content $html

# Select album containers (same as function)
# Select album containers (corrected XPath)
# Select album name elements directly
$albumNames = $doc.SelectNodes('//h3[@class="product__name"]')

$albums = @()
foreach ($nameElement in $albumNames) {
    $name = $nameElement.InnerText.Trim()
    
    # Get the link (parent of h3)
    $link = $nameElement.ParentNode
    $href = $link.GetAttributeValue('href', '')
    if (-not $href -or -not $href.Contains('/album/')) { continue }
    
    # Extract ID from href
    $hrefClean = if ($href -match '^[^?]+') { $matches[0] } else { $href }
# Extract last path segment (slug/id)
if ($hrefClean -match '/album/[^/]+/([^/?#]+)$') {
    $albumId = $matches[1]
} else {
    continue
}
    
    # Get the item (grandparent of link)
    $parent = $link.ParentNode  # product__container
    $item = $parent.ParentNode  # product__item
    
    $releaseElement = $item.SelectSingleNode('.//p[@class="product__data--release"]')
    $releaseDate = if ($releaseElement) { $releaseElement.InnerText.Trim() } else { '' }
    
    $genreElement = $item.SelectSingleNode('.//p[@class="product__data--genre"]')
    $genre = if ($genreElement) { $genreElement.InnerText.Trim() } else { '' }
    
    # Create the album object
    $albumItem = [PSCustomObject]@{
        name         = $name
        id           = $albumId
        release_date = $releaseDate
        genre        = $genre
    }
    $albums += $albumItem
}

# Output results
Write-Host "Found $($albums.Count) albums:"
$albums | ForEach-Object { Write-Host "  - $($_.name) (ID: $($_.id))" }