# Spotify Helper Functions for Invoke-MuFo
# These functions provide specialized logic for handling Spotify API responses

function Get-AlbumItemsFromSearchResult {
    <#
    .SYNOPSIS
    Flattens Spotishell Search-Item results into a simple albums array.
    
    .DESCRIPTION
    Processes complex nested Spotify search results and extracts album items
    into a flat array, handling various response formats from the API.
    
    .PARAMETER Result
    The search result object from Spotify API calls.
    
    .OUTPUTS
    Array of album objects extracted from the search result.
    
    .NOTES
    Handles both single results and arrays of results, extracting from
    Albums.Items or Items properties as appropriate. Works with both
    hashtables and PSCustomObjects.
    #>
    param([Parameter(Mandatory)]$Result)
    
    $albums = @()
    try {
        if ($null -eq $Result) { return @() }
        
        $resultsToProcess = if ($Result -is [System.Array]) { $Result } else { @($Result) }

        foreach ($p in $resultsToProcess) {
            if ($null -eq $p) { continue }
            
            # Handle both hashtables and PSCustomObjects for Albums.Items
            $hasAlbums = $false
            if ($p -is [hashtable]) {
                $hasAlbums = $p.ContainsKey('Albums') -and $null -ne $p.Albums
            } else {
                $hasAlbums = $p.PSObject.Properties.Match('Albums').Count -gt 0 -and $p.Albums
            }
            
            if ($hasAlbums) {
                $albumsObj = $p.Albums
                $hasItems = $false
                if ($albumsObj -is [hashtable]) {
                    $hasItems = $albumsObj.ContainsKey('Items') -and $null -ne $albumsObj.Items
                } else {
                    $hasItems = $albumsObj.PSObject.Properties.Match('Items').Count -gt 0 -and $albumsObj.Items
                }
                
                if ($hasItems) {
                    $albums += @($albumsObj.Items)
                }
            }
            
            # Handle direct Items property
            $hasDirectItems = $false
            if ($p -is [hashtable]) {
                $hasDirectItems = $p.ContainsKey('Items') -and $null -ne $p.Items
            } else {
                $hasDirectItems = $p.PSObject.Properties.Match('Items').Count -gt 0 -and $p.Items
            }
            
            if ($hasDirectItems) {
                $albums += @($p.Items)
            }
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Verbose ("Get-AlbumItemsFromSearchResult failed to parse result: {0}" -f $msg)
    }
    
    # Ensure flat, non-null array
    return @($albums | Where-Object { $_ })
}