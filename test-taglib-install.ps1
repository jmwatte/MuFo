# Test TagLib-Sharp installation and detection

Import-Module "$PSScriptRoot\MuFo.psd1" -Force

Write-Host "=== Testing TagLib-Sharp Installation Experience ===" -ForegroundColor Cyan

# Test 1: Check if helper function is available
Write-Host "`n--- Test 1: Helper Function Availability ---" -ForegroundColor Green
try {
    $command = Get-Command Install-TagLibSharp -ErrorAction Stop
    Write-Host "✓ Install-TagLibSharp function is available" -ForegroundColor Green
    Write-Host "  Location: $($command.Source)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Install-TagLibSharp function not found" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Check current TagLib-Sharp status
Write-Host "`n--- Test 2: Current TagLib-Sharp Status ---" -ForegroundColor Green

$tagLibLoaded = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
if ($tagLibLoaded) {
    Write-Host "✓ TagLib-Sharp is currently loaded" -ForegroundColor Green
    Write-Host "  Assembly: $($tagLibLoaded.FullName)" -ForegroundColor Gray
} else {
    Write-Host "ℹ TagLib-Sharp is not currently loaded" -ForegroundColor Yellow
}

# Test 3: Check for existing installations
Write-Host "`n--- Test 3: Existing Installation Check ---" -ForegroundColor Green

$searchPaths = @(
    "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",
    "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll"
)

$found = $false
foreach ($path in $searchPaths) {
    $dlls = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq 'TagLib.dll' }
    
    if ($dlls) {
        Write-Host "✓ Found TagLib-Sharp installation(s):" -ForegroundColor Green
        foreach ($dll in $dlls) {
            Write-Host "  $($dll.FullName)" -ForegroundColor Gray
        }
        $found = $true
    }
}

if (-not $found) {
    Write-Host "ℹ No existing TagLib-Sharp installations found" -ForegroundColor Yellow
    Write-Host "  Search paths:" -ForegroundColor Gray
    foreach ($path in $searchPaths) {
        Write-Host "    $path" -ForegroundColor Gray
    }
}

# Test 4: Test the installation helper (dry run)
Write-Host "`n--- Test 4: Installation Helper Test ---" -ForegroundColor Green
Write-Host "To test the installation helper, run:" -ForegroundColor Yellow
Write-Host "  Install-TagLibSharp" -ForegroundColor White
Write-Host ""
Write-Host "This will:" -ForegroundColor Cyan
Write-Host "  • Check for existing installations" -ForegroundColor Gray
Write-Host "  • Offer to install if missing" -ForegroundColor Gray
Write-Host "  • Verify the installation" -ForegroundColor Gray
Write-Host "  • Test loading the library" -ForegroundColor Gray

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "Ready to test TagLib-Sharp installation experience!" -ForegroundColor Green