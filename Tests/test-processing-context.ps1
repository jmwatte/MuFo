# Tests for Get-MuFoProcessingContext helper
Write-Host "=== Testing Get-MuFoProcessingContext ===" -ForegroundColor Cyan

# Load required private helpers
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

$root = Join-Path $env:TEMP "MuFo-TestContext"
if (Test-Path $root) {
    Remove-Item -Path $root -Recurse -Force
}
New-Item -ItemType Directory -Path $root | Out-Null

$artists = @('ArtistA', 'ArtistB', 'Ignore-Me')
foreach ($artist in $artists) {
    New-Item -ItemType Directory -Path (Join-Path $root $artist) | Out-Null
}

Write-Host "Running context helper with ArtistAt=Here" -ForegroundColor Yellow
$contextHere = Get-MuFoProcessingContext -Path $root -ArtistAt 'Here'
$pathsHere = @($contextHere.ArtistPaths)
if ($pathsHere.Count -eq 1 -and $pathsHere[0] -eq $root) {
    Write-Host "  ✓ Returned root path when ArtistAt=Here" -ForegroundColor Green
} else {
    Write-Host "  ✗ Unexpected ArtistPaths for ArtistAt=Here: $($pathsHere -join ', ')" -ForegroundColor Red
}

Write-Host "Running context helper with ArtistAt=1D and exclusions" -ForegroundColor Yellow
$context1D = Get-MuFoProcessingContext -Path $root -ArtistAt '1D' -ExcludeFolders 'Ignore*'
$expectedPaths = @(
    (Join-Path -Path $root -ChildPath 'ArtistA'),
    (Join-Path -Path $root -ChildPath 'ArtistB')
)
$paths1D = @($context1D.ArtistPaths)
$missing = $expectedPaths | Where-Object { $_ -notin $paths1D }
$extra = $paths1D | Where-Object { $_ -notin $expectedPaths }
if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
    Write-Host "  ✓ Exclusions applied and child artist folders returned" -ForegroundColor Green
} else {
    Write-Host "  ✗ Mismatch in ArtistPaths for 1D. Missing: $($missing -join ', ') Extra: $($extra -join ', ')" -ForegroundColor Red
}

Write-Host "Verifying Preview detection" -ForegroundColor Yellow
$contextPreview = Get-MuFoProcessingContext -Path $root -ArtistAt 'Here' -Preview
if ($contextPreview.IsPreview) {
    Write-Host "  ✓ Preview switch sets IsPreview" -ForegroundColor Green
} else {
    Write-Host "  ✗ Preview switch failed to set IsPreview" -ForegroundColor Red
}

Write-Host "Verifying WhatIfPreference overrides preview" -ForegroundColor Yellow
$contextWhatIf = Get-MuFoProcessingContext -Path $root -ArtistAt 'Here' -WhatIfPreference $true
if ($contextWhatIf.IsPreview) {
    Write-Host "  ✓ WhatIfPreference propagates to IsPreview" -ForegroundColor Green
} else {
    Write-Host "  ✗ WhatIfPreference failed to set IsPreview" -ForegroundColor Red
}

# Cleanup
if (Test-Path $root) {
    Remove-Item -Path $root -Recurse -Force
}

Write-Host "=== Get-MuFoProcessingContext tests complete ===" -ForegroundColor Cyan
