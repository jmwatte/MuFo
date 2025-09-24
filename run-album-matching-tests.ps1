# Album Matching Regression Test Runner
# Run this from the main MuFo module directory to execute the test suite

param(
    [switch]$Verbose,
    [switch]$Detailed
)

Write-Host "🎵 Running MuFo Album Matching Regression Tests" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Change to test-fixtures directory
Push-Location "test-fixtures"

try {
    # Run the test script with any passed parameters
    $params = @{}
    if ($Verbose) { $params['Verbose'] = $true }
    if ($Detailed) { $params['Detailed'] = $true }

    & ".\test-album-matching-regression.ps1" @params

    # Return the exit code
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}