# Debug the actual function execution
Write-Host "Deep debugging of Get-AlbumItemsFromSearchResult..." -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

# Override function with debug version
function Get-AlbumItemsFromSearchResult {
    param([Parameter(Mandatory)]$Result)
    
    Write-Host "DEBUG: Function called with result type: $($Result.GetType().Name)" -ForegroundColor Magenta
    
    $albums = @()
    try {
        if ($null -eq $Result) { 
            Write-Host "DEBUG: Result is null" -ForegroundColor Red
            return @() 
        }
        
        $resultsToProcess = if ($Result -is [System.Array]) { $Result } else { @($Result) }
        Write-Host "DEBUG: Processing $($resultsToProcess.Count) results" -ForegroundColor Magenta

        foreach ($p in $resultsToProcess) {
            Write-Host "DEBUG: Processing item type: $($p.GetType().Name)" -ForegroundColor Magenta
            if ($null -eq $p) { 
                Write-Host "DEBUG: Item is null, skipping" -ForegroundColor Yellow
                continue 
            }
            
            Write-Host "DEBUG: Item properties: $($p.PSObject.Properties.Name -join ', ')" -ForegroundColor Magenta
            
            if ($p.PSObject.Properties.Match('Albums').Count -gt 0 -and $p.Albums) {
                Write-Host "DEBUG: Found Albums property" -ForegroundColor Green
                if ($p.Albums.PSObject.Properties.Match('Items').Count -gt 0 -and $p.Albums.Items) {
                    Write-Host "DEBUG: Found Albums.Items with $($p.Albums.Items.Count) items" -ForegroundColor Green
                    $albums += @($p.Albums.Items)
                }
            }
            if ($p.PSObject.Properties.Match('Items').Count -gt 0 -and $p.Items) {
                Write-Host "DEBUG: Found direct Items with $($p.Items.Count) items" -ForegroundColor Green
                $albums += @($p.Items)
            }
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Host "DEBUG: Exception: $msg" -ForegroundColor Red
        Write-Verbose ("Get-AlbumItemsFromSearchResult failed to parse result: {0}" -f $msg)
    }
    
    Write-Host "DEBUG: Total albums collected: $($albums.Count)" -ForegroundColor Magenta
    # Ensure flat, non-null array
    $filtered = @($albums | Where-Object { $_ })
    Write-Host "DEBUG: After filtering: $($filtered.Count)" -ForegroundColor Magenta
    return $filtered
}

# Test with mock data
$mockResult = @{
    Albums = @{
        Items = @(
            @{ Name = 'Test Album 1' },
            @{ Name = 'Test Album 2' }
        )
    }
}

Write-Host "`nTesting with debug version:" -ForegroundColor Yellow
$result = Get-AlbumItemsFromSearchResult -Result $mockResult
Write-Host "Final result count: $($result.Count)" -ForegroundColor White