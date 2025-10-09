# Test enhanced Qobuz jazz metadata parsing with full production credits
# This tests the ParsePerformer function with complex jazz/production data

Import-Module "$PSScriptRoot\..\MuFo.psm1" -Force

Write-Host "`n=== Testing ParsePerformer with Jazz/Production Credits ===" -ForegroundColor Cyan

# Test case from Melody Gardot jazz album
$jazzInfo = "Cliff Masterson, StringsConductor - Bernie Grundman, MasteringEngineer - Royal Philharmonic Orchestra, Strings, Woodwinds - Paulinho Da Costa, Percussion - Vinnie Colaiuta, DrumKit - Al Schmitt, MixingEngineer, RecordingEngineer - LARRY KLEIN, Producer - Andrew Dudman, RecordingEngineer - Rupert Coulson, RecordingEngineer - Steve Genewick, Engineer, RecordingEngineer - Ivy Skoff, ProductionCoordinator - Anthony Wilson, Guitar - Melody Gardot, Vocalist, MainArtist, ComposerLyricist - Antonio Zambujo, Vocalist, FeaturedArtist - John Leftwich, Bass - Pierre Aderne, ComposerLyricist - Chandler Harrod, RecordingSecondEngineer - Ian Maclay, StringsDirector - Dadi Carvalho, Guitar, ComposerLyricist - Gabe Burch, RecordingSecondEngineer"

Write-Host "`nInput (truncated for display):" -ForegroundColor Yellow
Write-Host "$($jazzInfo.Substring(0, 150))..."

# Load the ParsePerformer function from Get-QAlbumTracks
$parsePerformerCode = Get-Content "$PSScriptRoot\..\Private\manual\Get-QAlbumTracks.ps1" -Raw
$functionMatch = [regex]::Match($parsePerformerCode, 'function ParsePerformer\(\$inputb\)\s*{[\s\S]*?^        }', [System.Text.RegularExpressions.RegexOptions]::Multiline)
if ($functionMatch.Success) {
    Invoke-Expression $functionMatch.Value
} else {
    Write-Error "Could not extract ParsePerformer function"
    exit
}

$result = ParsePerformer $jazzInfo

Write-Host "`n=== Extracted for Standard Audio Tags ===" -ForegroundColor Green
Write-Host "  Composers (ComposerLyricist): $($result.Composers -join '; ')" -ForegroundColor White
Write-Host "  Performers (MainArtist + FeaturedArtist + Vocalists): $($result.Performers -join '; ')" -ForegroundColor White
Write-Host "  Conductor (StringsConductor): $($result.Conductor)" -ForegroundColor White
Write-Host "  Ensemble: $($result.Ensemble)" -ForegroundColor White
Write-Host "  FeaturedArtists: $($result.FeaturedArtists -join '; ')" -ForegroundColor White

Write-Host "`n=== Full Credits (for Comment field) ===" -ForegroundColor Green
Write-Host $result.FullCredits -ForegroundColor DarkGray

Write-Host "`n=== Detailed Role Breakdown (for Show-Tracks display) ===" -ForegroundColor Green
foreach ($person in ($result.DetailedRoles.Keys | Sort-Object)) {
    $roles = $result.DetailedRoles[$person]
    Write-Host "  $person : $roles" -ForegroundColor Cyan
}

# Validation
Write-Host "`n=== Validation ===" -ForegroundColor Cyan
$tests = @(
    @{ Name = "Composers include Melody Gardot"; Expected = $true; Actual = ($result.Composers -contains "Melody Gardot") }
    @{ Name = "Composers include Pierre Aderne"; Expected = $true; Actual = ($result.Composers -contains "Pierre Aderne") }
    @{ Name = "Composers include Dadi Carvalho"; Expected = $true; Actual = ($result.Composers -contains "Dadi Carvalho") }
    @{ Name = "Composers count"; Expected = 3; Actual = $result.Composers.Count }
    @{ Name = "FeaturedArtists include Antonio Zambujo"; Expected = $true; Actual = ($result.FeaturedArtists -contains "Antonio Zambujo") }
    @{ Name = "Performers include Melody Gardot"; Expected = $true; Actual = ($result.Performers -contains "Melody Gardot") }
    @{ Name = "Performers include Antonio Zambujo"; Expected = $true; Actual = ($result.Performers -contains "Antonio Zambujo") }
    @{ Name = "Conductor is Cliff Masterson"; Expected = "Cliff Masterson"; Actual = $result.Conductor }
    @{ Name = "Ensemble is Royal Philharmonic Orchestra"; Expected = "Royal Philharmonic Orchestra"; Actual = $result.Ensemble }
    @{ Name = "FullCredits not empty"; Expected = $true; Actual = ($result.FullCredits.Length -gt 0) }
    @{ Name = "DetailedRoles has entries"; Expected = $true; Actual = ($result.DetailedRoles.Count -gt 0) }
    @{ Name = "DetailedRoles includes Bernie Grundman"; Expected = $true; Actual = ($result.DetailedRoles.ContainsKey("Bernie Grundman")) }
)

$passed = 0
$failed = 0
foreach ($test in $tests) {
    if ($test.Expected -eq $test.Actual) {
        Write-Host "  ✓ $($test.Name)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  ✗ $($test.Name) - Expected: $($test.Expected), Actual: $($test.Actual)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nResults: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

# Demonstrate what gets saved to audio file tags
Write-Host "`n=== What Gets Saved to Audio File Tags ===" -ForegroundColor Cyan
Write-Host "  Tag Field         Value" -ForegroundColor Yellow
Write-Host "  ----------------- --------------------------------------------------------"
Write-Host "  Title:            [Track title]"
Write-Host "  Album:            [Album title]"
Write-Host "  Artist/Performers: $($result.Performers -join '; ')" -ForegroundColor White
Write-Host "  Composer:         $($result.Composers -join '; ')" -ForegroundColor White
Write-Host "  AlbumArtist:      $($result.Performers[0])" -ForegroundColor White
Write-Host "  Genre:            [categoryGenre; subCategoryGenre]"
Write-Host "  Year:             [From release date]"
Write-Host "  Comment:          [Full production credits - see above]" -ForegroundColor White

Write-Host "`nNote: The full production credits are stored in the Comment field," -ForegroundColor Magenta
Write-Host "      and detailed roles are displayed in Show-Tracks during Stage C." -ForegroundColor Magenta
Write-Host "      Engineers, producers, and other production staff are preserved!" -ForegroundColor Magenta
