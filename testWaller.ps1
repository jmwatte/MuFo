# --- Configuration ---
# IMPORTANT: Replace this with your actual token from the Discogs developer settings.
$discogsToken = "kWRdoAaimXKsQUOYmxPIkgLATVfcIjredIopbenl" 

# --- Construct the Request ---
$uri = "https://api.discogs.com/database/search"

$headers = @{
    # Add the required User-Agent header
    "User-Agent"    = "MyFatsWallerScript/1.0" 
    # Add your authentication token
    "Authorization" = "Discogs token=$discogsToken"
}

# Use Body parameter instead of building query string manually
$params = @{
    type   = "release"
    title  = "the complete recorded works"
    artist = "fats waller"
}

# --- Make the API Call ---
try {
    Write-Host "Querying Discogs API..."
    Write-Host "Parameters: type=release, title='the complete recorded works', artist='fats waller'"
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -Body $params
    
    # --- Process the Results ---
    Write-Host "Found $($response.pagination.items) total items across $($response.pagination.pages) pages."
    
    # Display the title and ID of the first few results
    foreach ($release in $response.results) {
        Write-Host " - ID: $($release.id), Title: $($release.title)"
    }
    
    # To see the full raw data for the first result:
    # $response.results[0] | ConvertTo-Json -Depth 5

}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    # This will show you the full error response from the server
    $_.Exception.Response.GetResponseStream() | ForEach-Object {
        $reader = New-Object System.IO.StreamReader($_)
        $reader.ReadToEnd()
    }
}