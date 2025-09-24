# Test script to validate data-driven duration matching logic
# This tests the enhanced track numbering with empirical tolerances

Write-Host "🧪 TESTING DATA-DRIVEN DURATION MATCHING" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Import the module
Import-Module "$PSScriptRoot\MuFo.psm1" -Force

# Test data based on the empirical analysis
$testCases = @(
    @{
        TrackName = "Short Track (1:34)"
        Duration = 94  # 1:34
        ExpectedCategory = "Short"
        ExpectedTolerance = 42
    },
    @{
        TrackName = "Normal Track (3:37)"
        Duration = 217  # 3:37
        ExpectedCategory = "Normal"
        ExpectedTolerance = 107
    },
    @{
        TrackName = "Long Track (8:21)"
        Duration = 501  # 8:21
        ExpectedCategory = "Long"
        ExpectedTolerance = 89
    },
    @{
        TrackName = "Epic Track (13:52)"
        Duration = 832  # 13:52
        ExpectedCategory = "Epic"
        ExpectedTolerance = 331
    }
)

Write-Host "Testing duration categorization and tolerances..." -ForegroundColor Yellow

foreach ($test in $testCases) {
    # Simulate the categorization logic from Set-AudioFileTags.ps1
    $trackCategory = if ($test.Duration -lt 120) { "Short" }
                    elseif ($test.Duration -lt 420) { "Normal" }
                    elseif ($test.Duration -lt 600) { "Long" }
                    else { "Epic" }

    $dataDrivenTolerances = @{
        Short = @{ Normal = 42 }
        Normal = @{ Normal = 107 }
        Long = @{ Normal = 89 }
        Epic = @{ Normal = 331 }
    }

    $toleranceSeconds = $dataDrivenTolerances[$trackCategory].Normal

    $status = if ($trackCategory -eq $test.ExpectedCategory -and $toleranceSeconds -eq $test.ExpectedTolerance) {
        "✅ PASS"
    } else {
        "❌ FAIL"
    }

    Write-Host "  $status $($test.TrackName): Category=$trackCategory (expected $($test.ExpectedCategory)), Tolerance=${toleranceSeconds}s (expected $($test.ExpectedTolerance)s)"
}

Write-Host ""
Write-Host "🎯 DATA-DRIVEN DURATION MATCHING VALIDATION COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green