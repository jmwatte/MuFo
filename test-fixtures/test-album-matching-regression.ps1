# Album Matching Regression Test Suite
# Tests the album matching algorithm against known test fixtures

param(
    [switch]$Verbose,
    [switch]$Detailed
)

Write-Host "🎵 MuFo Album Matching Regression Tests" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Import required modules
Import-Module "$PSScriptRoot\..\MuFo.psd1" -Force

# Dot-source additional private functions we need
. "$PSScriptRoot\..\Private\Invoke-MuFo-Exclusions.ps1"

# Load test cases
$testCasesPath = Join-Path $PSScriptRoot "album-matching-tests.json"
if (-not (Test-Path $testCasesPath)) {
    Write-Error "Test cases file not found: $testCasesPath"
    exit 1
}

$testData = Get-Content $testCasesPath | ConvertFrom-Json
$testCases = $testData.testCases

Write-Host "Loaded $($testCases.Count) test cases" -ForegroundColor White
Write-Host ""

$results = @()
$passed = 0
$failed = 0

foreach ($testCase in $testCases) {
    Write-Host "🧪 Testing: $($testCase.name)" -ForegroundColor Yellow
    if ($Verbose) {
        Write-Host "   Path: $($testCase.path)" -ForegroundColor Gray
        Write-Host "   Expected: $($testCase.expectedAlbum) by $($testCase.expectedArtist)" -ForegroundColor Gray
    }

    $testPath = Join-Path $PSScriptRoot $testCase.path
    if (-not (Test-Path $testPath)) {
        Write-Host "   ❌ FAILED: Test path does not exist: $testPath" -ForegroundColor Red
        $results += [PSCustomObject]@{
            TestName = $testCase.name
            Status = "FAILED"
            Reason = "Test path not found"
            ActualScore = $null
            ActualArtistScore = $null
            ExpectedScore = $testCase.expectedScore
            ExpectedArtistScore = $testCase.expectedArtistScore
        }
        $failed++
        continue
    }

    try {
        # Extract artist name from path
        $pathParts = $testCase.path -split '\\|/'
        $artistName = $pathParts[1]  # Second part is artist name

        # Find the artist
        $spotifyArtists = Get-SpotifyArtist -ArtistName $artistName
        if (-not $spotifyArtists -or $spotifyArtists.Count -eq 0) {
            Write-Host "   ❌ FAILED: Could not find Spotify artist: $artistName" -ForegroundColor Red
            $results += [PSCustomObject]@{
                TestName = $testCase.name
                Status = "FAILED"
                Reason = "Artist not found"
                ActualScore = $null
                ActualArtistScore = $null
                ExpectedScore = $testCase.expectedScore
                ExpectedArtistScore = $testCase.expectedArtistScore
            }
            $failed++
            continue
        }

        $selectedArtist = $spotifyArtists[0].Artist

        # Extract album info from folder name
        $albumFolder = Split-Path $testPath -Leaf
        $albumName = $albumFolder -replace '^[\(\[]?\d{4}[\)\]]?\s*[-–—._ ]\s*',''
        $yearMatch = [regex]::Match($albumFolder, '^[\(\[]?(?<year>\d{4})[\)\]]?')
        $year = if ($yearMatch.Success) { $yearMatch.Groups['year'].Value } else { $null }

        if ($Verbose) {
            Write-Host "   Artist: $artistName" -ForegroundColor Gray
            Write-Host "   Album: $albumName" -ForegroundColor Gray
            Write-Host "   Year: $year" -ForegroundColor Gray
        }

        # Test the album matching
        $albumComparisons = Get-AlbumComparisons -CurrentPath (Split-Path $testPath -Parent) -SelectedArtist $selectedArtist -EffectiveExclusions @('')

        if (-not $albumComparisons -or $albumComparisons.Count -eq 0) {
            Write-Host "   ❌ FAILED: No album matches found" -ForegroundColor Red
            $results += [PSCustomObject]@{
                TestName = $testCase.name
                Status = "FAILED"
                Reason = "No matches found"
                ActualScore = $null
                ActualArtistScore = $null
                ExpectedScore = $testCase.expectedScore
                ExpectedArtistScore = $testCase.expectedArtistScore
            }
            $failed++
            continue
        }

        $bestMatch = $albumComparisons[0]  # Already sorted by score

        if ($Detailed) {
            Write-Host "   Best match: $($bestMatch.MatchName) by $($bestMatch.MatchArtist) (Score: $($bestMatch.MatchScore))" -ForegroundColor Gray
        }

        # Get artist score from the matched item if available
        $actualArtistScore = if ($bestMatch.MatchedItem -and $bestMatch.MatchedItem.ArtistScore) { 
            $bestMatch.MatchedItem.ArtistScore 
        } else { 
            0 
        }

        # Validate results
        $scoreOk = [math]::Abs($bestMatch.MatchScore - $testCase.expectedScore) -lt 0.3  # Allow some tolerance
        $artistScoreOk = [math]::Abs($actualArtistScore - $testCase.expectedArtistScore) -lt 0.3

        if ($scoreOk -and $artistScoreOk) {
            Write-Host "   ✅ PASSED" -ForegroundColor Green
            $results += [PSCustomObject]@{
                TestName = $testCase.name
                Status = "PASSED"
                Reason = ""
                ActualScore = $bestMatch.MatchScore
                ActualArtistScore = $actualArtistScore
                ExpectedScore = $testCase.expectedScore
                ExpectedArtistScore = $testCase.expectedArtistScore
            }
            $passed++
        } else {
            Write-Host "   ❌ FAILED: Score mismatch" -ForegroundColor Red
            Write-Host "      Expected Score: $($testCase.expectedScore), Actual: $($bestMatch.MatchScore)" -ForegroundColor Red
            Write-Host "      Expected Artist Score: $($testCase.expectedArtistScore), Actual: $($bestMatch.ArtistScore)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                TestName = $testCase.name
                Status = "FAILED"
                Reason = "Score mismatch"
                ActualScore = $bestMatch.MatchScore
                ActualArtistScore = $actualArtistScore
                ExpectedScore = $testCase.expectedScore
                ExpectedArtistScore = $testCase.expectedArtistScore
            }
            $failed++
        }

    } catch {
        Write-Host "   ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            TestName = $testCase.name
            Status = "FAILED"
            Reason = $_.Exception.Message
            ActualScore = $null
            ActualArtistScore = $null
            ExpectedScore = $testCase.expectedScore
            ExpectedArtistScore = $testCase.expectedArtistScore
        }
        $failed++
    }

    Write-Host ""
}

# Summary
Write-Host "📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Total Tests: $($testCases.Count)" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host ""

if ($failed -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed. Details:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAILED" } | Format-Table -AutoSize
    exit 1
}