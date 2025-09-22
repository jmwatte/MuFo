# Test exclusions refactoring
Write-Host "=== Testing Exclusions Refactoring ===" -ForegroundColor Cyan

try {
    # Import the module with new private functions
    Import-Module .\MuFo.psm1 -Force -ErrorAction Stop
    
    Write-Host "`n1. Testing exclusion functions are available..." -ForegroundColor Yellow
    
    # Test if functions are loaded
    $functions = @(
        'Get-ExclusionsStorePath',
        'Read-ExcludedFoldersFromDisk', 
        'Test-ExclusionMatch',
        'Write-ExcludedFoldersToDisk',
        'Get-EffectiveExclusions',
        'Show-Exclusions'
    )
    
    foreach ($func in $functions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ $func available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $func missing" -ForegroundColor Red
        }
    }
    
    Write-Host "`n2. Testing output formatting functions..." -ForegroundColor Yellow
    
    $formatFunctions = @(
        'Write-AlbumComparisonResult',
        'Write-RenameOperation',
        'Write-ArtistSelectionPrompt',
        'ConvertTo-SafeFileName',
        'ConvertTo-ComparableName'
    )
    
    foreach ($func in $formatFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ $func available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $func missing" -ForegroundColor Red
        }
    }
    
    Write-Host "`n3. Testing exclusion logic..." -ForegroundColor Yellow
    
    # Test wildcard exclusions
    $testResult1 = Test-ExclusionMatch -FolderName "E_test" -Exclusions @("E_*")
    $testResult2 = Test-ExclusionMatch -FolderName "test_Live" -Exclusions @("*_Live")
    $testResult3 = Test-ExclusionMatch -FolderName "Album1" -Exclusions @("Album?")
    $testResult4 = Test-ExclusionMatch -FolderName "Normal" -Exclusions @("E_*", "*_Live")
    
    if ($testResult1) { Write-Host "  ✓ Wildcard prefix matching works" -ForegroundColor Green }
    else { Write-Host "  ✗ Wildcard prefix matching failed" -ForegroundColor Red }
    
    if ($testResult2) { Write-Host "  ✓ Wildcard suffix matching works" -ForegroundColor Green }
    else { Write-Host "  ✗ Wildcard suffix matching failed" -ForegroundColor Red }
    
    if ($testResult3) { Write-Host "  ✓ Single character wildcard works" -ForegroundColor Green }
    else { Write-Host "  ✗ Single character wildcard failed" -ForegroundColor Red }
    
    if (-not $testResult4) { Write-Host "  ✓ Non-matching exclusion works" -ForegroundColor Green }
    else { Write-Host "  ✗ Non-matching exclusion failed" -ForegroundColor Red }
    
    Write-Host "`n4. Testing output formatting..." -ForegroundColor Yellow
    
    # Test output formatting
    Write-AlbumComparisonResult -Album "Test Album" -LocalArtist "abba" -SpotifyArtist "ABBA" -IsAlbumMatch $true -IsArtistMatch $false
    
    Write-Host "`n5. Testing main Invoke-MuFo still works..." -ForegroundColor Yellow
    
    # Quick test that main function still works
    if (Get-Command Invoke-MuFo -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ Invoke-MuFo function available" -ForegroundColor Green
        
        # Test with a simple path that should not break
        if (Test-Path "C:\temp\TestMusic\abba") {
            Write-Host "  Testing with abba example..." -ForegroundColor Gray
            $result = Invoke-MuFo -Path "C:\temp\TestMusic\abba" -WhatIf -ErrorAction SilentlyContinue
            if ($result) {
                Write-Host "  ✓ Invoke-MuFo executed successfully" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Invoke-MuFo returned no results (may be expected)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ⚠ Test path not available, skipping integration test" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ Invoke-MuFo function missing" -ForegroundColor Red
    }
    
    Write-Host "`n=== Refactoring Test Complete ===" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}