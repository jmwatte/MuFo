# Debug empty string matching
Write-Host "Debugging empty string matching..." -ForegroundColor Cyan

# Load private functions
Get-ChildItem -Path ".\Private" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

Write-Host "`nTesting empty patterns directly:" -ForegroundColor Yellow

$folderName = ""
$pattern = ""

Write-Host "FolderName: '$folderName'" -ForegroundColor Gray
Write-Host "Pattern: '$pattern'" -ForegroundColor Gray
Write-Host "IsNullOrWhiteSpace(FolderName): $([string]::IsNullOrWhiteSpace($folderName))" -ForegroundColor Gray
Write-Host "IsNullOrWhiteSpace(Pattern): $([string]::IsNullOrWhiteSpace($pattern))" -ForegroundColor Gray
Write-Host "Exclusions array count: $((@($pattern)).Count)" -ForegroundColor Gray

# Call the function directly
$result = Test-ExclusionMatch -FolderName $folderName -Exclusions @($pattern) -Verbose
Write-Host "Result: $result" -ForegroundColor White

Write-Host "`nTesting with null/empty exclusions:" -ForegroundColor Yellow
$result2 = Test-ExclusionMatch -FolderName $folderName -Exclusions @() -Verbose
Write-Host "Empty array result: $result2" -ForegroundColor White

$result3 = Test-ExclusionMatch -FolderName $folderName -Exclusions $null -Verbose
Write-Host "Null array result: $result3" -ForegroundColor White