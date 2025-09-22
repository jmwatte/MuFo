# Debug the *_Live pattern issue
Write-Host "Debugging *_Live pattern..." -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object { . $_.FullName }

$testFolder = "Extra_Live_Recordings"
$pattern = "*_Live"

Write-Host "Testing: '$testFolder' vs '$pattern'" -ForegroundColor Yellow
$result = Test-ExclusionMatch -FolderName $testFolder -Exclusions @($pattern) -Verbose
Write-Host "Result: $result" -ForegroundColor White

Write-Host "`nTesting manually with -like operator:" -ForegroundColor Yellow
$manualResult = $testFolder -like $pattern
Write-Host "'$testFolder' -like '$pattern' = $manualResult" -ForegroundColor White

Write-Host "`nThe issue is that '$testFolder' ends with '_Recordings', not '_Live'" -ForegroundColor Red
Write-Host "Let's test with correct patterns:" -ForegroundColor Yellow

$correctTests = @(
    @{ Folder = "Something_Live"; Pattern = "*_Live" },
    @{ Folder = "Extra_Live_Recordings"; Pattern = "*_Live_*" },
    @{ Folder = "Extra_Live_Recordings"; Pattern = "*Live*" }
)

foreach ($test in $correctTests) {
    $result = Test-ExclusionMatch -FolderName $test.Folder -Exclusions @($test.Pattern)
    Write-Host "  '$($test.Folder)' vs '$($test.Pattern)' = $result" -ForegroundColor $(if ($result) { "Green" } else { "Gray" })
}