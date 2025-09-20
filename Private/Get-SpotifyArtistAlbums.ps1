function Get-SpotifyArtistAlbums {
<#
.SYNOPSIS
    Retrieves albums for a Spotify artist and normalizes the output.

.PARAMETER ArtistId
    The Spotify artist ID.

.PARAMETER IncludeSingles
    Include singles in the returned list.

.PARAMETER IncludeCompilations
    Include compilations in the returned list.

.EXAMPLE
    Get-SpotifyArtistAlbums -ArtistId $artist.Id -Verbose
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ArtistId,
        [switch]$IncludeSingles,
        [switch]$IncludeCompilations
    )

    try {
        $albumsResult = Get-ArtistAlbums -Id $ArtistId -Album -ErrorAction Stop
        $items = @()
        if ($null -eq $albumsResult) { $albumsResult = @() }

        # Spotishell can return:
        # - An array of album objects
        # - An array of pages with .Items
        # - A single object with .Items
        # - A single object with .Albums.Items
        if ($albumsResult -is [System.Array]) {
            if (($albumsResult | Select-Object -First 1) -and ($albumsResult[0].PSObject.Properties.Match('Name').Count -gt 0)) {
                # Direct array of album objects
                $items = $albumsResult
            } else {
                foreach ($page in $albumsResult) {
                    if ($page.PSObject.Properties.Match('Items').Count -gt 0 -and $page.Items) { $items += $page.Items }
                    elseif ($page.PSObject.Properties.Match('Albums').Count -gt 0 -and $page.Albums -and $page.Albums.Items) { $items += $page.Albums.Items }
                }
            }
        } else {
            if ($albumsResult.PSObject.Properties.Match('Items').Count -gt 0 -and $albumsResult.Items) { $items = $albumsResult.Items }
            elseif ($albumsResult.PSObject.Properties.Match('Albums').Count -gt 0 -and $albumsResult.Albums -and $albumsResult.Albums.Items) { $items = $albumsResult.Albums.Items }
            elseif ($albumsResult.PSObject.Properties.Match('Name').Count -gt 0) { $items = @($albumsResult) }
        }
        Write-Verbose ("Artist album items collected: {0}" -f (($items | Measure-Object).Count))

        # Some items may vary in property naming; project to a normalized shape
        $normalized = foreach ($a in $items) {
            $name = $null
            $albumType = $null
            $releaseDate = $null

            # Try common property names
            if ($a.PSObject.Properties.Match('Name').Count) { $name = [string]$a.Name }
            elseif ($a.PSObject.Properties.Match('name').Count) { $name = [string]$a.name }

            if ($a.PSObject.Properties.Match('AlbumType').Count) { $albumType = [string]$a.AlbumType }
            elseif ($a.PSObject.Properties.Match('album_type').Count) { $albumType = [string]$a.album_type }

            if ($a.PSObject.Properties.Match('ReleaseDate').Count) { $releaseDate = [string]$a.ReleaseDate }
            elseif ($a.PSObject.Properties.Match('release_date').Count) { $releaseDate = [string]$a.release_date }

            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            [PSCustomObject]@{
                Name        = $name
                AlbumType   = $albumType
                ReleaseDate = $releaseDate
                Raw         = $a
            }
        }

        # Filter album types unless explicitly included
        $filtered = $normalized | Where-Object {
            if ($_.AlbumType) {
                $t = $_.AlbumType.ToLowerInvariant()
                if ($t -eq 'album') { return $true }
                if ($IncludeSingles -and $t -eq 'single') { return $true }
                if ($IncludeCompilations -and $t -eq 'compilation') { return $true }
                return $false
            } else {
                # Unknown type - keep it to avoid false negatives
                return $true
            }
        }

        return $filtered
    } catch {
        Write-Warning "Failed to retrieve albums for artist '$ArtistId': $_"
        return @()
    }
}