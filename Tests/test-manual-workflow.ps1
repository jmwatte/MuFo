# Test Manual Track Mapping Workflow
# Author: jmw
# Tests the complete manual workflow: generate mapping, edit, import

param(
    [string]$TestFolder = "C:\temp\mufo-manual-test",
    [switch]$Cleanup,
    [switch]$SkipGenerate,
    [switch]$SkipImport
)

# Import MuFo module
$moduleRoot = Split-Path $PSScriptRoot -Parent
if (Get-Module MuFo) { Remove-Module MuFo -Force }
Import-Module "$moduleRoot\MuFo.psd1" -Force

Write-Host "🧪 Testing Manual Track Mapping Workflow" -ForegroundColor Cyan
Write-Host "Test folder: $TestFolder" -ForegroundColor Gray

# Clean up previous test
if ($Cleanup -or (Test-Path $TestFolder)) {
    if (Test-Path $TestFolder) {
        Write-Host "🧹 Cleaning up previous test folder..." -ForegroundColor Yellow
        Remove-Item $TestFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Cleanup) {
    Write-Host "✅ Cleanup complete" -ForegroundColor Green
    return
}

# Create test environment
Write-Host "📁 Setting up test environment..." -ForegroundColor Yellow
New-Item $TestFolder -ItemType Directory -Force | Out-Null

# Create test audio files (empty files for testing)
$testFiles = @(
    "01 - Wrong First Song.mp3",
    "02 - Actually Second.mp3", 
    "03 - This Should Be First.mp3",
    "04 - Final Track.mp3"
)

foreach ($file in $testFiles) {
    $path = Join-Path $TestFolder $file
    New-Item $path -ItemType File -Force | Out-Null
    Write-Host "  Created: $file" -ForegroundColor Gray
}

# Test 1: Generate mapping files
if (-not $SkipGenerate) {
    Write-Host "`n🎵 Test 1: Generate mapping files" -ForegroundColor Cyan
    
    try {
        Invoke-ManualTrackMapping -Path $TestFolder -Action Generate -OutputName "test-mapping" | Out-Null
        
        # Check if files were created
        $playlistFile = Join-Path $TestFolder "test-mapping.m3u"
        $mappingFile = Join-Path $TestFolder "test-mapping.txt"
        
        if ((Test-Path $playlistFile) -and (Test-Path $mappingFile)) {
            Write-Host "✅ Mapping files created successfully" -ForegroundColor Green
            
            # Show contents
            Write-Host "📋 Playlist content:" -ForegroundColor Yellow
            Get-Content $playlistFile | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            
            Write-Host "`n📝 Mapping content:" -ForegroundColor Yellow
            Get-Content $mappingFile | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            
        } else {
            Write-Host "❌ Failed to create mapping files" -ForegroundColor Red
            return
        }
        
    } catch {
        Write-Host "❌ Error generating mapping: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

# Simulate user editing the mapping file
$mappingFile = Join-Path $TestFolder "test-mapping.txt"
if (Test-Path $mappingFile) {
    Write-Host "`n✏️ Simulating user editing mapping file..." -ForegroundColor Yellow
    
    # Read original mapping
    $originalLines = Get-Content $mappingFile
    
    # Create edited version (reorder tracks)
    $newLines = @()
    foreach ($line in $originalLines) {
        if ($line.StartsWith('#') -or -not $line.Trim()) {
            $newLines += $line
        } else {
            # Reorder: what was track 3 becomes track 1, etc.
            switch -Regex ($line) {
                '^1\.' { $newLines += "1. This Should Be First" }  # Was track 3
                '^2\.' { $newLines += "2. Wrong First Song" }      # Was track 1  
                '^3\.' { $newLines += "3. Actually Second" }       # Was track 2
                '^4\.' { $newLines += "4. Final Track" }           # Unchanged
            }
        }
    }
    
    # Write edited mapping
    $newLines | Out-File $mappingFile -Encoding UTF8 -Force
    Write-Host "  ✅ Mapping file edited (simulated user reordering)" -ForegroundColor Green
    
    Write-Host "📝 New mapping content:" -ForegroundColor Yellow
    Get-Content $mappingFile | Where-Object { -not $_.StartsWith('#') -and $_.Trim() } | 
        ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}

# Test 2: Import changes (WhatIf first)
if (-not $SkipImport) {
    Write-Host "`n🔍 Test 2: Preview import changes (WhatIf)" -ForegroundColor Cyan
    
    try {
        Invoke-ManualTrackMapping -Action Import -MappingFile $mappingFile -WhatIf
        Write-Host "✅ WhatIf preview completed" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Error in WhatIf preview: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    # Test 3: Actual import with file renaming
    Write-Host "`n📥 Test 3: Import changes with file renaming" -ForegroundColor Cyan
    
    try {
        # First, let's see what files exist before
        Write-Host "Files before import:" -ForegroundColor Yellow
        Get-ChildItem $TestFolder -Filter "*.mp3" | ForEach-Object { 
            Write-Host "  $($_.Name)" -ForegroundColor Gray 
        }
        
        $importResult = Invoke-ManualTrackMapping -Action Import -MappingFile $mappingFile -RenameFiles
        
        if ($importResult) {
            Write-Host "✅ Import completed successfully" -ForegroundColor Green
            
            # Show files after import
            Write-Host "`nFiles after import:" -ForegroundColor Yellow
            Get-ChildItem $TestFolder -Filter "*.mp3" | ForEach-Object { 
                Write-Host "  $($_.Name)" -ForegroundColor Gray 
            }
            
            # Check for backup files
            $backupFiles = Get-ChildItem $TestFolder -Filter "*.backup"
            if ($backupFiles) {
                Write-Host "`n💾 Backup files created:" -ForegroundColor Cyan
                $backupFiles | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
            }
            
        } else {
            Write-Host "❌ Import failed or returned no result" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ Error during import: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return
    }
}

# Test 4: Validate results
Write-Host "`n🔍 Test 4: Validate final results" -ForegroundColor Cyan

$finalFiles = Get-ChildItem $TestFolder -Filter "*.mp3" | Sort-Object Name
$expectedOrder = @(
    "01 - This Should Be First.mp3",
    "02 - Wrong First Song.mp3", 
    "03 - Actually Second.mp3",
    "04 - Final Track.mp3"
)

Write-Host "Expected file order:" -ForegroundColor Yellow
$expectedOrder | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host "`nActual file order:" -ForegroundColor Yellow
$finalFiles | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }

# Check if order matches
$orderMatches = $true
for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
    if ($i -ge $finalFiles.Count -or $finalFiles[$i].Name -ne $expectedOrder[$i]) {
        $orderMatches = $false
        break
    }
}

if ($orderMatches) {
    Write-Host "`n✅ SUCCESS: File order matches expected reordering!" -ForegroundColor Green
} else {
    Write-Host "`n❌ FAILURE: File order does not match expected reordering" -ForegroundColor Red
}

# Summary
Write-Host "`n📊 Test Summary:" -ForegroundColor Cyan
Write-Host "  Test folder: $TestFolder" -ForegroundColor White
Write-Host "  Files created: $($testFiles.Count)" -ForegroundColor White
Write-Host "  Mapping workflow: " -NoNewline -ForegroundColor White
if (Test-Path (Join-Path $TestFolder "test-mapping.m3u")) {
    Write-Host "✅ Generated" -ForegroundColor Green
} else {
    Write-Host "❌ Failed" -ForegroundColor Red
}
Write-Host "  Import workflow: " -NoNewline -ForegroundColor White
if ($orderMatches) {
    Write-Host "✅ Success" -ForegroundColor Green
} else {
    Write-Host "❌ Failed" -ForegroundColor Red
}

Write-Host "`n💡 To test manually:" -ForegroundColor Yellow
Write-Host "  1. cd '$TestFolder'" -ForegroundColor White
Write-Host "  2. Play test-mapping.m3u in media player" -ForegroundColor White
Write-Host "  3. Edit test-mapping.txt to match what you hear" -ForegroundColor White
Write-Host "  4. Run: Invoke-ManualTrackMapping -Action Import -MappingFile 'test-mapping.txt' -RenameFiles" -ForegroundColor White

Write-Host "`n🧹 To cleanup: $($MyInvocation.MyCommand.Name) -Cleanup" -ForegroundColor Gray