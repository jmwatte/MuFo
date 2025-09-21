# Debug script to diagnose Arvo Part album detection issues
param(
    [string]$Path = "E:\_CorrectedMusic\Arvo Part"
)

Write-Host "=== MuFo Debug Analysis ===" -ForegroundColor Cyan
Write-Host "Path: $Path" -ForegroundColor Yellow

# Import the module
Import-Module "$PSScriptRoot\MuFo.psd1" -Force

# Check if path exists
if (-not (Test-Path $Path)) {
    Write-Host "ERROR: Path does not exist: $Path" -ForegroundColor Red
    return
}

Write-Host "`n1. Checking folder structure:" -ForegroundColor Green
$albums = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
Write-Host "Found $($albums.Count) album folders:" -ForegroundColor Yellow
foreach ($album in $albums) {
    Write-Host "  - $($album.Name)" -ForegroundColor White
}

Write-Host "`n2. Testing Spotify connection:" -ForegroundColor Green
try {
    # Test if we can connect to Spotify
    $testArtist = Get-SpotifyArtist -ArtistName "Arvo Part" -ErrorAction Stop
    if ($testArtist) {
        Write-Host "✓ Spotify connection working" -ForegroundColor Green
        Write-Host "Found $($testArtist.Count) artist matches for 'Arvo Part'" -ForegroundColor Yellow
        foreach ($match in $testArtist | Select-Object -First 3) {
            Write-Host "  - $($match.Artist.Name) (Score: $([math]::Round($match.Score, 2)))" -ForegroundColor White
        }
    }
} catch {
    Write-Host "✗ Spotify connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This might explain why albums aren't being found." -ForegroundColor Yellow
}

Write-Host "`n3. Running MuFo with detailed verbose output:" -ForegroundColor Green
Write-Host "Command: Invoke-MuFo -Path '$Path' -WhatIf -Verbose" -ForegroundColor Yellow
Write-Host "Output:" -ForegroundColor White

# Run the actual command with verbose output
try {
    $results = Invoke-MuFo -Path $Path -WhatIf -Verbose 2>&1
    $results | ForEach-Object { 
        if ($_ -is [System.Management.Automation.VerboseRecord]) {
            Write-Host "VERBOSE: $($_.Message)" -ForegroundColor DarkGray
        } elseif ($_ -is [System.Management.Automation.WarningRecord]) {
            Write-Host "WARNING: $($_.Message)" -ForegroundColor Yellow
        } elseif ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            Write-Host $_ -ForegroundColor White
        }
    }
} catch {
    Write-Host "ERROR running MuFo: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`n4. Analysis summary:" -ForegroundColor Green
Write-Host "Expected: Multiple albums found (except 1 not on Spotify)" -ForegroundColor Yellow
Write-Host "Actual: Only 1 album found" -ForegroundColor Yellow
Write-Host "`nPossible causes:" -ForegroundColor White
Write-Host "- Spotify API issues or rate limiting" -ForegroundColor Gray
Write-Host "- Artist name matching problems" -ForegroundColor Gray
Write-Host "- Album search query failures" -ForegroundColor Gray
Write-Host "- Folder naming that doesn't match expected patterns" -ForegroundColor Gray
Write-Host "- Exclusion logic accidentally filtering albums" -ForegroundColor Gray