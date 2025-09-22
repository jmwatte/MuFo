# Test the enhanced track tagging functionality

param(
    [string]$TestPath = "C:\Users\resto\Music"
)

# Import the module
Import-Module "$PSScriptRoot\MuFo.psd1" -Force

Write-Host "=== Testing Enhanced Track Tagging in MuFo ===" -ForegroundColor Cyan

# Create a test scenario
$testFolder = "C:\temp\mufo-track-test"
if (Test-Path $testFolder) {
    Remove-Item $testFolder -Recurse -Force
}

# Create a mock music structure for testing
New-Item -ItemType Directory -Path "$testFolder\Arvo Pärt\1999 - Alina" -Force | Out-Null

Write-Host "`nTest folder created: $testFolder" -ForegroundColor Green
Write-Host "You can now test with:" -ForegroundColor Yellow
Write-Host "  Invoke-MuFo -Path '$testFolder' -IncludeTracks -Preview" -ForegroundColor White

# Test the module loading and function availability
Write-Host "`n--- Module Function Test ---" -ForegroundColor Green

try {
    # Test if we can call the main function
    $result = Invoke-MuFo -Path $testFolder -Preview
    Write-Host "✓ Invoke-MuFo loaded successfully" -ForegroundColor Green
    
    # Test if private functions are available in the scope
    if (Get-Command Get-AudioFileTags -ErrorAction SilentlyContinue) {
        Write-Host "✓ Get-AudioFileTags available in private scope" -ForegroundColor Green
    } else {
        Write-Host "ℹ Get-AudioFileTags properly scoped as private function" -ForegroundColor Yellow
    }
    
    Write-Host "`n--- Available Functions ---" -ForegroundColor Green
    Get-Command -Module MuFo | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor White
    }
    
} catch {
    Write-Error "Function test failed: $($_.Exception.Message)"
}

Write-Host "`n=== Test Setup Complete ===" -ForegroundColor Cyan
Write-Host "Ready for track tagging tests!" -ForegroundColor Green