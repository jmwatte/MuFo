function Get-DArtistAlbums {
    <#
    .SYNOPSIS
    Get albums/releases for a Discogs artist.
    
    .DESCRIPTION
    Retrieves the list of releases (albums) for a given Discogs artist ID.
    Handles pagination automatically.
    
    .PARAMETER Id
    The Discogs artist ID (numeric).
    
    .PARAMETER Album
    For compatibility with Spotify API pattern. Only 'Album' is supported.
    
    .EXAMPLE
    Get-DArtistAlbums -Id 45467
    Gets all releases for Pink Floyd (artist ID 45467).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Album')]
        [string]$Album = 'Album'
    )

    try {
        $allReleases = @()
        $page = 1
        $perPage = 100  # Maximum per page
        
        do {
            Write-Verbose "Fetching Discogs artist releases page $page..."
            
            # Get releases page
            $response = Invoke-DiscogsRequest -Uri "/artists/$Id/releases?page=$page&per_page=$perPage&sort=year&sort_order=asc"
            
            if ($response.releases) {
                foreach ($release in $response.releases) {
                    # Filter to main releases (skip appearances on compilations, etc.)
                    # You can adjust this filter based on your needs
                    $includeRelease = $true
                    
                    # Skip if this is just an appearance (not main artist)
                    if ($release.role -and $release.role -ne 'Main') {
                        $includeRelease = $false
                    }
                    
                    if ($includeRelease) {
                        # Transform to match Spotify-like structure
                        $albumObj = [PSCustomObject]@{
                            name         = $release.title
                            id           = $release.id
                            release_date = $release.year  # Discogs uses year, not full date
                            type         = $release.type  # master, release, etc.
                            artist       = $release.artist
                            format       = $release.format  # CD, Vinyl, etc.
                            label        = $release.label
                            resource_url = $release.resource_url
                        }
                        
                        $allReleases += $albumObj
                    }
                }
            }
            
            # Check if there are more pages
            if ($response.pagination) {
                $totalPages = $response.pagination.pages
                Write-Verbose "Page $page of $totalPages"
                
                if ($page -ge $totalPages) {
                    break
                }
            } else {
                break
            }
            
            $page++
            Start-Sleep -Milliseconds 250  # Small delay between requests
            
        } while ($true)
        
        Write-Verbose "Found $($allReleases.Count) releases for artist $Id"
        return $allReleases
    }
    catch {
        Write-Warning "Failed to get Discogs artist albums: $_"
        return @()
    }
}
