# Test Enhanced Wildcard Exclusions
Write-Host "=== Testing Enhanced Wildcard Exclusions ===" -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

Write-Host "`nTesting current Test-ExclusionMatch function:" -ForegroundColor Yellow

# Test Cases as specified in implementexcludefolders.md plus enhanced patterns
$testCases = @(
    # Basic wildcard patterns from spec
    @{ Folder = "E_test"; Pattern = "E_*"; Expected = $true; Description = "Prefix wildcard (*)" },
    @{ Folder = "test_Live"; Pattern = "*_Live"; Expected = $true; Description = "Suffix wildcard (*)" },
    @{ Folder = "Album1"; Pattern = "Album?"; Expected = $true; Description = "Single character wildcard (?)" },
    @{ Folder = "Album2"; Pattern = "Album?"; Expected = $true; Description = "Single character wildcard (?) variant" },
    @{ Folder = "Album10"; Pattern = "Album?"; Expected = $false; Description = "Single character wildcard (?) should not match longer" },
    
    # Enhanced character class patterns
    @{ Folder = "Album1"; Pattern = "Album[0-9]"; Expected = $true; Description = "Character class [0-9]" },
    @{ Folder = "Album2"; Pattern = "Album[0-9]"; Expected = $true; Description = "Character class [0-9] variant" },
    @{ Folder = "AlbumA"; Pattern = "Album[0-9]"; Expected = $false; Description = "Character class [0-9] should not match letters" },
    @{ Folder = "AlbumX"; Pattern = "Album[A-Z]"; Expected = $true; Description = "Character class [A-Z]" },
    @{ Folder = "Album9"; Pattern = "Album[A-Z]"; Expected = $false; Description = "Character class [A-Z] should not match digits" },
    
    # Negative tests
    @{ Folder = "MyE_test"; Pattern = "E_*"; Expected = $false; Description = "Prefix wildcard (*) should not match middle" },
    @{ Folder = "test_LiveExtra"; Pattern = "*_Live"; Expected = $false; Description = "Suffix wildcard (*) should not match if more after" },
    
    # Exact matches
    @{ Folder = "EXACT_MATCH"; Pattern = "EXACT_MATCH"; Expected = $true; Description = "Exact match" },
    @{ Folder = "exact_match"; Pattern = "EXACT_MATCH"; Expected = $true; Description = "Case insensitive exact match" },
    @{ Folder = "NoMatch"; Pattern = "Different"; Expected = $false; Description = "No match" },
    
    # Edge cases
    @{ Folder = ""; Pattern = "*"; Expected = $true; Description = "Empty folder name matches wildcard *" },
    @{ Folder = "test"; Pattern = ""; Expected = $false; Description = "Non-empty folder does not match empty pattern" },
    
    # Complex patterns
    @{ Folder = "2024_Live_Album"; Pattern = "*_Live_*"; Expected = $true; Description = "Multiple wildcards" },
    @{ Folder = "E_test_Live"; Pattern = "E_*_Live"; Expected = $true; Description = "Prefix and suffix with wildcard in middle" }
)

$passCount = 0
$totalCount = $testCases.Count

foreach ($testCase in $testCases) {
    $result = Test-ExclusionMatch -FolderName $testCase.Folder -Exclusions @($testCase.Pattern)
    $passed = $result -eq $testCase.Expected
    
    if ($passed) {
        Write-Host "  ✓ PASS: $($testCase.Description) - '$($testCase.Folder)' vs '$($testCase.Pattern)'" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  ✗ FAIL: $($testCase.Description) - '$($testCase.Folder)' vs '$($testCase.Pattern)' (got $result, expected $($testCase.Expected))" -ForegroundColor Red
    }
}

Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "  Passed: $passCount/$totalCount" -ForegroundColor $(if ($passCount -eq $totalCount) { 'Green' } else { 'Yellow' })

if ($passCount -eq $totalCount) {
    Write-Host "`n🎉 All wildcard exclusion tests PASSED! 🎉" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed - examining the implementation..." -ForegroundColor Yellow
}

# Test with multiple patterns
Write-Host "`nTesting multiple patterns:" -ForegroundColor Yellow
$multiResult1 = Test-ExclusionMatch -FolderName "E_bonus" -Exclusions @("E_*", "*_Live", "ExactMatch")
$multiResult2 = Test-ExclusionMatch -FolderName "some_Live" -Exclusions @("E_*", "*_Live", "ExactMatch")
$multiResult3 = Test-ExclusionMatch -FolderName "ExactMatch" -Exclusions @("E_*", "*_Live", "ExactMatch")
$multiResult4 = Test-ExclusionMatch -FolderName "NoMatch" -Exclusions @("E_*", "*_Live", "ExactMatch")

Write-Host "  E_bonus vs multiple patterns: $multiResult1 (expected True)" -ForegroundColor $(if ($multiResult1) { 'Green' } else { 'Red' })
Write-Host "  some_Live vs multiple patterns: $multiResult2 (expected True)" -ForegroundColor $(if ($multiResult2) { 'Green' } else { 'Red' })
Write-Host "  ExactMatch vs multiple patterns: $multiResult3 (expected True)" -ForegroundColor $(if ($multiResult3) { 'Green' } else { 'Red' })
Write-Host "  NoMatch vs multiple patterns: $multiResult4 (expected False)" -ForegroundColor $(if (-not $multiResult4) { 'Green' } else { 'Red' })

Write-Host "`nWildcard exclusions testing complete!" -ForegroundColor Cyan