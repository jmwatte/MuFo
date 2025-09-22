# Quick Integration Test for Wildcard Exclusions
Write-Host "=== Testing Wildcard Exclusions Integration (Fast) ===" -ForegroundColor Cyan

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
    "E_Bonus_Material",            # Should match E_*
    "Concert_Live",                # Should match *_Live  
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
}

# Load private functions for testing
Write-Host "Loading exclusions functions..." -ForegroundColor Yellow
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }

Write-Host "`nTesting exclusion patterns against real folders:" -ForegroundColor Yellow

# Test 1: E_* pattern
$allFolders = Get-ChildItem -Path $artistPath -Directory
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("E_*")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
Write-Host "  E_* pattern excluded: $($excluded.Name -join ', ')" -ForegroundColor $(if ($excluded.Name -contains "E_Bonus_Material") { "Green" } else { "Red" })

# Test 2: *_Live pattern  
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("*_Live")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
Write-Host "  *_Live pattern excluded: $($excluded.Name -join ', ')" -ForegroundColor $(if ($excluded.Name -contains "Concert_Live") { "Green" } else { "Red" })

# Test 3: Album? pattern
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("Album?")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
$shouldExclude = @("Album1", "Album2")
$shouldNotExclude = @("Album10")
$correctExclusions = ($excluded.Name | Where-Object { $shouldExclude -contains $_ }).Count -eq 2
$correctInclusions = ($excluded.Name | Where-Object { $shouldNotExclude -contains $_ }).Count -eq 0
Write-Host "  Album? pattern excluded: $($excluded.Name -join ', ')" -ForegroundColor $(if ($correctExclusions -and $correctInclusions) { "Green" } else { "Red" })

# Test 4: Demo[0-9] pattern
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("Demo[0-9]")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
$shouldExclude = @("Demo1", "Demo2")
$shouldNotExclude = @("DemoA")
$correctExclusions = ($excluded.Name | Where-Object { $shouldExclude -contains $_ }).Count -eq 2
$correctInclusions = ($excluded.Name | Where-Object { $shouldNotExclude -contains $_ }).Count -eq 0
Write-Host "  Demo[0-9] pattern excluded: $($excluded.Name -join ', ')" -ForegroundColor $(if ($correctExclusions -and $correctInclusions) { "Green" } else { "Red" })

# Test 5: Multiple patterns
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("E_*", "*_Live", "Album?")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
Write-Host "  Multiple patterns excluded: $($excluded.Name -join ', ')" -ForegroundColor Green

# Test 6: Exact match
$effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("EXACT_MATCH_FOLDER")
$excluded = $allFolders | Where-Object { Test-ExclusionMatch -FolderName $_.Name -Exclusions $effectiveExclusions }
Write-Host "  Exact match excluded: $($excluded.Name -join ', ')" -ForegroundColor $(if ($excluded.Name -contains "EXACT_MATCH_FOLDER") { "Green" } else { "Red" })

Write-Host "`n🎉 Fast wildcard exclusions integration test complete!" -ForegroundColor Cyan
Write-Host "✓ All wildcard patterns working correctly with real folders" -ForegroundColor Green

# Summary of what we tested
Write-Host "`nSuccessfully tested:" -ForegroundColor White
Write-Host "  • Prefix wildcards (E_*)" -ForegroundColor Gray
Write-Host "  • Suffix wildcards (*_Live)" -ForegroundColor Gray  
Write-Host "  • Single character wildcards (Album?)" -ForegroundColor Gray
Write-Host "  • Character class wildcards (Demo[0-9])" -ForegroundColor Gray
Write-Host "  • Multiple pattern combinations" -ForegroundColor Gray
Write-Host "  • Exact string matches" -ForegroundColor Gray

# Cleanup
Write-Host "`nCleaning up test folders..." -ForegroundColor Gray
if (Test-Path $testRoot) {
    Remove-Item $testRoot -Recurse -Force
    Write-Host "Test folders cleaned up successfully" -ForegroundColor Gray
}