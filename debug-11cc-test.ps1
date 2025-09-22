# Debug the failing test scenario
Write-Host "=== Debugging failing test scenario ===" -ForegroundColor Cyan

# Test what happens with a folder name that should trigger inference
try {
    Import-Module .\MuFo.psm1 -Force -ErrorAction Stop
    
    # Create a temporary test structure like the failing test
    $testPath = "C:\temp\TestMusic\11cc"
    $albumPath = "$testPath\1974 - Sheet Music"
    
    if (-not (Test-Path $testPath)) {
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        New-Item -ItemType Directory -Path $albumPath -Force | Out-Null
        Write-Host "Created test structure: $testPath" -ForegroundColor Gray
    }
    
    Write-Host "`n1. Testing Get-SpotifyArtist for '11cc'..." -ForegroundColor Yellow
    $topMatches = Get-SpotifyArtist -ArtistName "11cc"
    
    if ($topMatches) {
        Write-Host "Found $($topMatches.Count) matches for '11cc':" -ForegroundColor Gray
        foreach ($match in $topMatches | Select-Object -First 3) {
            Write-Host "  - $($match.Artist.Name) (score: $([math]::Round($match.Score, 3)))" -ForegroundColor White
        }
        Write-Host "  Top match score: $($topMatches[0].Score)" -ForegroundColor White
        Write-Host "  Confidence threshold: 0.6" -ForegroundColor White
        Write-Host "  Should trigger inference: $(if ($topMatches[0].Score -lt 0.6) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($topMatches[0].Score -lt 0.6) { 'Green' } else { 'Red' })
    } else {
        Write-Host "No matches found for '11cc'" -ForegroundColor Red
    }
    
    Write-Host "`n2. Testing Invoke-MuFo on '11cc'..." -ForegroundColor Yellow
    $result = Invoke-MuFo -Path $testPath -DoIt Smart -Preview -Verbose:$false -ErrorAction Stop
    
    if ($result) {
        Write-Host "Result:" -ForegroundColor Gray
        Write-Host "  SpotifyArtist: $($result.SpotifyArtist)" -ForegroundColor White
        Write-Host "  ArtistSource: $($result.ArtistSource)" -ForegroundColor White
        Write-Host "  NewFolderName: $($result.NewFolderName)" -ForegroundColor White
    } else {
        Write-Host "No result returned" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}