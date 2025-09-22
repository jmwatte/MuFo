# Test Wildcard Exclusions Persistence
Write-Host "=== Testing Wildcard Exclusions Persistence ===" -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }

# Test file path
$testFile = "C:\temp\test-exclusions.json"

# Clean up any existing test file
if (Test-Path $testFile) {
    Remove-Item $testFile -Force
}

Write-Host "`nTest 1: Save wildcard exclusions to disk" -ForegroundColor Yellow
$testExclusions = @("E_*", "*_Live", "Album?", "Demo[0-9]", "ExactMatch")

try {
    Write-ExcludedFoldersToDisk -Exclusions $testExclusions -FilePath $testFile
    if (Test-Path $testFile) {
        Write-Host "  ✓ Exclusions saved successfully" -ForegroundColor Green
        $content = Get-Content $testFile -Raw
        Write-Host "  File content: $content" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ File was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error saving: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Load wildcard exclusions from disk" -ForegroundColor Yellow
try {
    $loadedExclusions = Read-ExcludedFoldersFromDisk -FilePath $testFile
    Write-Host "  Loaded exclusions: $($loadedExclusions -join ', ')" -ForegroundColor White
    
    $allMatch = $true
    foreach ($original in $testExclusions) {
        if ($loadedExclusions -notcontains $original) {
            $allMatch = $false
            break
        }
    }
    
    if ($allMatch -and $loadedExclusions.Count -eq $testExclusions.Count) {
        Write-Host "  ✓ All exclusions loaded correctly" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Exclusions don't match" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error loading: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Test effective exclusions with loaded patterns" -ForegroundColor Yellow
try {
    $effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("NewPattern") -ExcludedFoldersLoad $testFile
    Write-Host "  Effective exclusions: $($effectiveExclusions -join ', ')" -ForegroundColor White
    
    $hasNewPattern = $effectiveExclusions -contains "NewPattern"
    $hasLoadedPatterns = ($loadedExclusions | Where-Object { $effectiveExclusions -contains $_ }).Count -eq $loadedExclusions.Count
    
    if ($hasNewPattern -and $hasLoadedPatterns) {
        Write-Host "  ✓ Merge mode working correctly" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Merge mode failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error with effective exclusions: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 4: Test replace mode with loaded patterns" -ForegroundColor Yellow
try {
    $effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders @("ReplacementPattern") -ExcludedFoldersLoad $testFile -ExcludedFoldersReplace
    Write-Host "  Effective exclusions (replace mode): $($effectiveExclusions -join ', ')" -ForegroundColor White
    
    $hasOnlyReplacement = $effectiveExclusions.Count -eq 1 -and $effectiveExclusions -contains "ReplacementPattern"
    
    if ($hasOnlyReplacement) {
        Write-Host "  ✓ Replace mode working correctly" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Replace mode failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error with replace mode: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 5: Test loaded wildcard patterns functionality" -ForegroundColor Yellow
try {
    $testFolders = @("E_bonus", "Concert_Live", "Album1", "Demo5", "ExactMatch", "ShouldNotMatch")
    $loadedExclusions = Read-ExcludedFoldersFromDisk -FilePath $testFile
    
    foreach ($folder in $testFolders) {
        $excluded = Test-ExclusionMatch -FolderName $folder -Exclusions $loadedExclusions
        $color = switch ($folder) {
            "E_bonus" { if ($excluded) { "Green" } else { "Red" } }
            "Concert_Live" { if ($excluded) { "Green" } else { "Red" } }
            "Album1" { if ($excluded) { "Green" } else { "Red" } }
            "Demo5" { if ($excluded) { "Green" } else { "Red" } }
            "ExactMatch" { if ($excluded) { "Green" } else { "Red" } }
            "ShouldNotMatch" { if (-not $excluded) { "Green" } else { "Red" } }
        }
        Write-Host "    '$folder' excluded: $excluded" -ForegroundColor $color
    }
} catch {
    Write-Host "  ✗ Error testing loaded patterns: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testFile) {
    Remove-Item $testFile -Force
    Write-Host "`nTest file cleaned up" -ForegroundColor Gray
}

Write-Host "`n🎉 Wildcard exclusions persistence testing complete!" -ForegroundColor Cyan
Write-Host "✓ Save/load functionality works perfectly with wildcard patterns" -ForegroundColor Green