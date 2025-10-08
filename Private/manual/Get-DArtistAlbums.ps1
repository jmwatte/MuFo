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
        [string]$Album = 'Album',

        [Parameter(Mandatory = $false)]
        [switch]$MastersOnly = $true,  # DEFAULT: Only get master releases (canonical versions) - reduces duplicates

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSingles,  # Include singles

        [Parameter(Mandatory = $false)]
        [switch]$IncludeCompilations,  # Include compilations

        [Parameter(Mandatory = $false)]
        [switch]$IncludeAppearances  # Include guest appearances
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
                    # Apply filters based on parameters
                    $includeRelease = $true
                    
                    # Check role - skip appearances unless requested
                    $role = Get-IfExists $release 'role'
                    if ($role -and $role -ne 'Main' -and -not $IncludeAppearances) {
                        Write-Verbose "Skipping appearance: $($release.title)"
                        $includeRelease = $false
                    }
                    
                    # Check type - filter singles, compilations, etc.
                    $releaseType = Get-IfExists $release 'type'
                    if ($releaseType) {
                        $releaseType = $releaseType.ToLower()
                        
                        # Skip singles unless requested
                        if ($releaseType -match 'single' -and -not $IncludeSingles) {
                            Write-Verbose "Skipping single: $($release.title)"
                            $includeRelease = $false
                        }
                        
                        # Skip compilations unless requested
                        if ($releaseType -match 'compilation' -and -not $IncludeCompilations) {
                            Write-Verbose "Skipping compilation: $($release.title)"
                            $includeRelease = $false
                        }
                        
                        # If MastersOnly, skip non-master releases
                        if ($MastersOnly -and $releaseType -ne 'master') {
                            Write-Verbose "Skipping non-master release: $($release.title)"
                            $includeRelease = $false
                        }
                    }
                    
                    if ($includeRelease) {
                        # Transform to match Spotify-like structure
                        # Handle optional properties that may not be present
                        $albumObj = [PSCustomObject]@{
                            name         = if ($value = Get-IfExists $release 'title') { $value } else { "Unknown Album" }
                            id           = $release.id
                            release_date = if ($value = Get-IfExists $release 'year') { $value } else { "" }
                            type         = if ($value = Get-IfExists $release 'type') { $value } else { "release" }
                            artist       = if ($value = Get-IfExists $release 'artist') { $value } else { "" }
                            format       = if ($value = Get-IfExists $release 'format') { $value } else { "" }
                            label        = if ($value = Get-IfExists $release 'label') { $value } else { "" }
                            resource_url = if ($value = Get-IfExists $release 'resource_url') { $value } else { "" }
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
