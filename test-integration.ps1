# Comprehensive Integration Test for MuFo Refactoring
Write-Host "=== MuFo Refactoring Integration Test ===" -ForegroundColor Cyan
Write-Host "Testing all extracted functions and main module integration..." -ForegroundColor White

$testResults = @()
$testPassed = 0
$testFailed = 0

function Test-Function {
    param($Name, $TestBlock)
    try {
        Write-Host "`nTesting: $Name" -ForegroundColor Yellow
        $result = & $TestBlock
        if ($result) {
            Write-Host "✓ PASS: $Name" -ForegroundColor Green
            $script:testPassed++
            $script:testResults += [PSCustomObject]@{ Test = $Name; Result = "PASS"; Error = $null }
        } else {
            Write-Host "✗ FAIL: $Name - Test returned false" -ForegroundColor Red
            $script:testFailed++
            $script:testResults += [PSCustomObject]@{ Test = $Name; Result = "FAIL"; Error = "Test returned false" }
        }
    } catch {
        Write-Host "✗ FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        $script:testFailed++
        $script:testResults += [PSCustomObject]@{ Test = $Name; Result = "FAIL"; Error = $_.Exception.Message }
    }
}

# Test 1: Module Loading
Test-Function "Module Loading" {
    Import-Module './MuFo.psd1' -Force
    return $true
}

# Test 2: Main Function Availability
Test-Function "Main Function Availability" {
    $func = Get-Command Invoke-MuFo -ErrorAction SilentlyContinue
    return ($null -ne $func)
}

# Test 3: Exclusions Functions
Test-Function "Exclusions Functions" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $funcs = @('Get-EffectiveExclusions', 'Test-ExclusionMatch', 'Show-Exclusions')
    foreach ($f in $funcs) {
        if (-not (Get-Command $f -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    return $true
}

# Test 4: Exclusions Logic
Test-Function "Exclusions Logic" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $exclusions = Get-EffectiveExclusions -ExcludeFolders @('test1', 'test2')
    return ($exclusions.Count -eq 2 -and $exclusions -contains 'test1' -and $exclusions -contains 'test2')
}

# Test 5: Output Formatting Functions
Test-Function "Output Formatting Functions" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $funcs = @('Write-RenameOperation', 'Write-AlbumComparisonResult', 'ConvertTo-SafeFileName')
    foreach ($f in $funcs) {
        if (-not (Get-Command $f -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    return $true
}

# Test 6: Output Formatting Logic
Test-Function "Output Formatting Logic" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $testMap = [ordered]@{ 'C:\test\old' = 'C:\test\new' }
    # This should not throw an error
    Write-RenameOperation -RenameMap $testMap -Mode 'Test' | Out-Null
    return $true
}

# Test 7: Spotify Helper Functions
Test-Function "Spotify Helper Functions" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $func = Get-Command Get-AlbumItemsFromSearchResult -ErrorAction SilentlyContinue
    return ($null -ne $func)
}

# Test 8: Spotify Helper Logic
Test-Function "Spotify Helper Logic" {
    # Create a proper test structure that matches real Spotify API responses
    $mockResult = @{
        Albums = @{
            Items = @(
                @{ Name = 'Test Album 1' },
                @{ Name = 'Test Album 2' }
            )
        }
    }
    # Load private functions for testing since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $result = Get-AlbumItemsFromSearchResult -Result $mockResult
    return ($result.Count -eq 2)
}

# Test 9: Artist Selection Functions Available Internally
Test-Function "Artist Selection Functions Available Internally" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $funcs = @('Get-ArtistSelection', 'Get-ArtistFromInference', 'Get-ArtistRenameProposal')
    foreach ($f in $funcs) {
        if (-not (Get-Command $f -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    return $true
}

# Test 10: Album Processing Functions Available Internally
Test-Function "Album Processing Functions Available Internally" {
    # Load private functions manually since they're not exported
    Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    $funcs = @('Get-AlbumComparisons', 'Get-SingleAlbumComparison', 'Get-BestAlbumMatch')
    foreach ($f in $funcs) {
        if (-not (Get-Command $f -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    return $true
}

# Test 10: Main Function Syntax
Test-Function "Main Function Syntax" {
    # Check if the main function can be parsed without syntax errors
    $content = Get-Content './Public/Invoke-MuFo.ps1' -Raw
    $null = [scriptblock]::Create($content)
    return $true
}

# Test 11: Parameter Validation
Test-Function "Parameter Validation" {
    $func = Get-Command Invoke-MuFo
    $params = $func.Parameters.Keys
    $requiredParams = @('Path')
    foreach ($param in $requiredParams) {
        if ($param -notin $params) {
            return $false
        }
    }
    return $true
}

# Test 12: Help Documentation
Test-Function "Help Documentation" {
    $help = Get-Help Invoke-MuFo -ErrorAction SilentlyContinue
    return ($null -ne $help -and $help.Synopsis.Length -gt 0)
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($testPassed + $testFailed)" -ForegroundColor White
Write-Host "Passed: $testPassed" -ForegroundColor Green
Write-Host "Failed: $testFailed" -ForegroundColor Red

if ($testFailed -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host "The refactoring is working correctly!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️ SOME TESTS FAILED ⚠️" -ForegroundColor Red
    Write-Host "Failed tests:" -ForegroundColor Red
    $testResults | Where-Object { $_.Result -eq "FAIL" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)" -ForegroundColor Red
    }
}

# Line Count Verification
$currentLines = (Get-Content './Public/Invoke-MuFo.ps1' | Measure-Object -Line).Lines
$originalLines = 1385
$reduction = $originalLines - $currentLines
$percentage = [math]::Round(($reduction / $originalLines) * 100, 1)

Write-Host "`n=== REFACTORING STATS ===" -ForegroundColor Cyan
Write-Host "Original size: $originalLines lines" -ForegroundColor White
Write-Host "Current size: $currentLines lines" -ForegroundColor White  
Write-Host "Reduction: $reduction lines ($percentage%)" -ForegroundColor Green

return ($testFailed -eq 0)