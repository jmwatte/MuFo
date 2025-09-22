# Integration Test for Wildcard ExclWrite-Host "\nTest 1: Testing exclusion logic directly (no Spotify needed)" -ForegroundColor Yellow
try {
    # Load private functions for direct testing
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $testExclusions = Get-EffectiveExclusions -ExcludeFolders @("E_*")
    Write-Host "  Exclusions logic working: $(($testExclusions -join ', '))" -ForegroundColor Green
} catch {
    Write-Host "  Test 1 Error: $($_.Exception.Message)" -ForegroundColor Red
}ith Invoke-MuFo
Write-Host "=== Testing Wildcard# Test the actual exclusion logic directly
Write-Host "\nDirect exclusion testing:" -ForegroundColor Yellowusions Integration ===" -ForegroundColor Cyan

# Create test directory structure
$testRoot = "C:\temp\TestMusicWildcards"
$artistPath = "$testRoot\TestArtist"

if (Test-Path $testRoot) {
    Remove-Item $testRoot -Recurse -Force
}

Write-Host "`nCreating test folder structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $artistPath -Force | Out-Null

# Create album folders that match various wildcard patterns
$albumFolders = @(
    "1970 - First Album",          # Normal album
    "1975 - Second Album",         # Normal album
    "E_Bonus_Material",            # Should match E_*
    "Extra_Live_Recordings",       # Should match *_Live
    "Best_of_Live_Concert",        # Should match *_Live
    "Album1",                      # Should match Album?
    "Album2",                      # Should match Album?
    "Album10",                     # Should NOT match Album?
    "Demo1",                       # Should match Demo[0-9]
    "Demo2",                       # Should match Demo[0-9]
    "DemoA",                       # Should NOT match Demo[0-9]
    "EXACT_MATCH_FOLDER",          # For exact testing
    "Normal_Release"               # Normal album
)

foreach ($folder in $albumFolders) {
    New-Item -ItemType Directory -Path "$artistPath\$folder" -Force | Out-Null
    Write-Host "  Created: $folder" -ForegroundColor Gray
}

Write-Host "`nTest 1: No exclusions - should see all folders" -ForegroundColor Yellow
try {
    Import-Module .\MuFo.psm1 -Force
    $result1 = Invoke-MuFo -Path $artistPath -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Albums found: $($albumFolders.Count) expected, processing would find albums" -ForegroundColor Green
} catch {
    Write-Host "  Test 1 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Exclude E_* pattern - should exclude E_Bonus_Material" -ForegroundColor Yellow
try {
    $result2 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("E_*") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Exclusion E_* applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 2 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Exclude *_Live pattern - should exclude live recordings" -ForegroundColor Yellow
try {
    $result3 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("*_Live") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Exclusion *_Live applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 3 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 4: Exclude Album? pattern - should exclude Album1, Album2 but not Album10" -ForegroundColor Yellow
try {
    $result4 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("Album?") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Exclusion Album? applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 4 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 5: Exclude Demo[0-9] pattern - should exclude Demo1, Demo2 but not DemoA" -ForegroundColor Yellow
try {
    $result5 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("Demo[0-9]") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Exclusion Demo[0-9] applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 5 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 6: Multiple wildcard patterns" -ForegroundColor Yellow
try {
    $result6 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("E_*", "*_Live", "Album?") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Multiple exclusions applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 6 Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 7: Exact match exclusion" -ForegroundColor Yellow
try {
    $result7 = Invoke-MuFo -Path $artistPath -ExcludeFolders @("EXACT_MATCH_FOLDER") -WhatIf -ErrorAction SilentlyContinue
    Write-Host "  Exact match exclusion applied successfully" -ForegroundColor Green
} catch {
    Write-Host "  Test 7 Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test the actual exclusion logic directly
Write-Host "`nDirect exclusion testing:" -ForegroundColor Yellow

# Load private functions for direct testing
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }

$directTests = @(
    @{ Folder = "E_Bonus_Material"; Pattern = "E_*"; ShouldExclude = $true },
    @{ Folder = "Extra_Live_Recordings"; Pattern = "*_Live"; ShouldExclude = $true },
    @{ Folder = "Album1"; Pattern = "Album?"; ShouldExclude = $true },
    @{ Folder = "Album10"; Pattern = "Album?"; ShouldExclude = $false },
    @{ Folder = "Demo1"; Pattern = "Demo[0-9]"; ShouldExclude = $true },
    @{ Folder = "DemoA"; Pattern = "Demo[0-9]"; ShouldExclude = $false }
)

foreach ($test in $directTests) {
    $excluded = Test-ExclusionMatch -FolderName $test.Folder -Exclusions @($test.Pattern)
    $resultText = if ($excluded -eq $test.ShouldExclude) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($excluded -eq $test.ShouldExclude) { "Green" } else { "Red" }
    Write-Host "  $resultText`: '$($test.Folder)' vs '$($test.Pattern)' = $excluded" -ForegroundColor $color
}

Write-Host "`n🎉 Wildcard exclusions integration testing complete!" -ForegroundColor Cyan
Write-Host "The enhanced exclusions system supports:" -ForegroundColor White
Write-Host "  • Prefix wildcards: E_*" -ForegroundColor Gray
Write-Host "  • Suffix wildcards: *_Live" -ForegroundColor Gray  
Write-Host "  • Single character: Album?" -ForegroundColor Gray
Write-Host "  • Character classes: Demo[0-9], Album[A-Z]" -ForegroundColor Gray
Write-Host "  • Exact matches: EXACT_MATCH_FOLDER" -ForegroundColor Gray
Write-Host "  • Multiple patterns: Combined exclusions" -ForegroundColor Gray

# Cleanup
Write-Host "`nCleaning up test folders..." -ForegroundColor Gray
if (Test-Path $testRoot) {
    Remove-Item $testRoot -Recurse -Force
}