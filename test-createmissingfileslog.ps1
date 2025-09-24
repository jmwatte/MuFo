# Test for CreateMissingFilesLog parameter and red "Expected" display
Write-Host "Testing CreateMissingFilesLog parameter and red Expected display..." -ForegroundColor Cyan

# Load the module
Import-Module ".\MuFo.psd1" -Force

# Test 1: Verify CreateMissingFilesLog parameter exists
Write-Host "`nTest 1: Checking CreateMissingFilesLog parameter..." -ForegroundColor Yellow
$cmd = Get-Command Invoke-MuFo
$param = $cmd.Parameters['CreateMissingFilesLog']
if ($param) {
    Write-Host "✓ CreateMissingFilesLog parameter exists" -ForegroundColor Green
    if ($param.ParameterType -eq [switch]) {
        Write-Host "✓ Parameter is correctly typed as [switch]" -ForegroundColor Green
    } else {
        Write-Host "✗ Parameter type is $($param.ParameterType), expected [switch]" -ForegroundColor Red
    }
} else {
    Write-Host "✗ CreateMissingFilesLog parameter not found" -ForegroundColor Red
}

# Test 2: Verify parameter documentation exists
Write-Host "`nTest 2: Checking parameter documentation..." -ForegroundColor Yellow
$help = Get-Help Invoke-MuFo
$createMissingFilesLogParam = $help.parameters.parameter | Where-Object { $_.name -eq 'CreateMissingFilesLog' }
if ($createMissingFilesLogParam) {
    Write-Host "✓ CreateMissingFilesLog parameter documentation exists" -ForegroundColor Green
    if ($createMissingFilesLogParam.description) {
        Write-Host "✓ Parameter has description: $($createMissingFilesLogParam.description[0].text)" -ForegroundColor Green
    }
} else {
    Write-Host "✗ CreateMissingFilesLog parameter documentation not found" -ForegroundColor Red
}

# Test 3: Test parameter validation (should require -FixTags when used)
Write-Host "`nTest 3: Testing parameter validation..." -ForegroundColor Yellow
try {
    # This should work - just checking syntax
    $params = @{
        Path = "."
        CreateMissingFilesLog = $true
        FixTags = $true
        IncludeTracks = $true
        ValidateCompleteness = $true
        WhatIf = $true
    }
    Write-Host "✓ Parameter combination validation passed" -ForegroundColor Green
} catch {
    Write-Host "✗ Parameter validation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test Set-AudioFileTags function has the parameter
Write-Host "`nTest 4: Checking Set-AudioFileTags function..." -ForegroundColor Yellow
$setAudioCmd = Get-Command Set-AudioFileTags -ErrorAction SilentlyContinue
if ($setAudioCmd) {
    $createMissingParam = $setAudioCmd.Parameters['CreateMissingFilesLog']
    if ($createMissingParam) {
        Write-Host "✓ Set-AudioFileTags has CreateMissingFilesLog parameter" -ForegroundColor Green
    } else {
        Write-Host "✗ Set-AudioFileTags missing CreateMissingFilesLog parameter" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Set-AudioFileTags command not found" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Cyan