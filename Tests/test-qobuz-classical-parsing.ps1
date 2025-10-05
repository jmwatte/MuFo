# Test enhanced Qobuz classical music metadata parsing
# This tests the ParsePerformer function with real classical music data

Import-Module "$PSScriptRoot\..\MuFo.psm1" -Force

Write-Host "`n=== Testing ParsePerformer with Classical Music Data ===" -ForegroundColor Cyan

# Test case from Bach album
$classicalInfo = "Johann Sebastian Bach, Composer - Christian Friedrich Henrici, Composer - Jan De Winne, Producer - il Gardellino, Ensemble, MainArtist - Alexander Grychtolik, Conductor, MainArtist"

Write-Host "`nInput:" -ForegroundColor Yellow
Write-Host $classicalInfo

# Load the ParsePerformer function from Get-QAlbumTracks
$parsePerformerCode = @'
function ParsePerformer($inputb) {
    if (-not $inputb -or $inputb -eq "Unknown Performer") {
        return @{ 
            Composers = @()
            Performers = @()
            MainArtists = @()
            Conductor = $null
            Ensemble = $null
        }
    }
    
    # Parse format: "Name, Role, Role - Name, Role - Name, Role"
    $entries = $inputb -split " - "
    $composers = @()
    $performers = @()
    $mainArtists = @()
    $conductor = $null
    $ensemble = $null
    
    foreach ($entry in $entries) {
        $parts = $entry -split ", "
        if ($parts.Length -lt 2) { continue }
        
        $name = $parts[0].Trim()
        $roles = $parts[1..($parts.Length - 1)]
        
        foreach ($role in $roles) {
            $role = $role.Trim()
            
            # Categorize by role
            if ($role -match '^Composer') {
                $composers += $name
            }
            if ($role -eq 'Conductor' -or $role -match '^Conductor,') {
                $conductor = $name
                $performers += $name
            }
            if ($role -eq 'Ensemble' -or $role -match '^Ensemble,') {
                $ensemble = $name
                $performers += $name
            }
            if ($role -eq 'MainArtist' -or $role -match '^MainArtist,') {
                $mainArtists += $name
                if ($name -notin $performers) {
                    $performers += $name
                }
            }
            # Add other performer roles (Artist, Producer, etc.)
            if ($role -in @('Artist', 'Producer', 'Performer', 'Soloist', 'Vocalist', 'Instrumentalist')) {
                if ($name -notin $performers) {
                    $performers += $name
                }
            }
        }
    }
    
    return @{
        Composers = $composers
        Performers = $performers
        MainArtists = $mainArtists
        Conductor = $conductor
        Ensemble = $ensemble
    }
}
'@

Invoke-Expression $parsePerformerCode

$result = ParsePerformer $classicalInfo

Write-Host "`nParsed Results:" -ForegroundColor Green
Write-Host "  Composers: $($result.Composers -join '; ')" -ForegroundColor White
Write-Host "  Performers: $($result.Performers -join '; ')" -ForegroundColor White
Write-Host "  MainArtists: $($result.MainArtists -join '; ')" -ForegroundColor White
Write-Host "  Conductor: $($result.Conductor)" -ForegroundColor White
Write-Host "  Ensemble: $($result.Ensemble)" -ForegroundColor White

Write-Host "`n=== Expected Results ===" -ForegroundColor Cyan
Write-Host "  Composers: Johann Sebastian Bach; Christian Friedrich Henrici" -ForegroundColor Yellow
Write-Host "  Performers: il Gardellino; Alexander Grychtolik" -ForegroundColor Yellow
Write-Host "  MainArtists: il Gardellino; Alexander Grychtolik" -ForegroundColor Yellow
Write-Host "  Conductor: Alexander Grychtolik" -ForegroundColor Yellow
Write-Host "  Ensemble: il Gardellino" -ForegroundColor Yellow

# Validation
Write-Host "`n=== Validation ===" -ForegroundColor Cyan
$tests = @(
    @{ Name = "Composers count"; Expected = 2; Actual = $result.Composers.Count }
    @{ Name = "Composers include Bach"; Expected = $true; Actual = ($result.Composers -contains "Johann Sebastian Bach") }
    @{ Name = "Composers include Henrici"; Expected = $true; Actual = ($result.Composers -contains "Christian Friedrich Henrici") }
    @{ Name = "Performers count"; Expected = 2; Actual = $result.Performers.Count }
    @{ Name = "Conductor is Grychtolik"; Expected = "Alexander Grychtolik"; Actual = $result.Conductor }
    @{ Name = "Ensemble is il Gardellino"; Expected = "il Gardellino"; Actual = $result.Ensemble }
    @{ Name = "MainArtists count"; Expected = 2; Actual = $result.MainArtists.Count }
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

# Now demonstrate how this maps to audio file tags
Write-Host "`n=== How This Maps to Audio File Tags ===" -ForegroundColor Cyan
Write-Host "  Tag Field         Value" -ForegroundColor Yellow
Write-Host "  ----------------- --------------------------------------------------------"
Write-Host "  Title:            [Track title from HTML]"
Write-Host "  Album:            [Album title]"
Write-Host "  Artist/Performers: $($result.Performers -join '; ')" -ForegroundColor White
Write-Host "  Composer:         $($result.Composers -join '; ')" -ForegroundColor White
Write-Host "  AlbumArtist:      $($result.MainArtists[0])" -ForegroundColor White
Write-Host "  Genre:            [categoryGenre; subCategoryGenre]"
Write-Host "  Year:             [From release date]"

Write-Host "`nNote: Conductor and Ensemble are also extracted and can be displayed in Show-Tracks," -ForegroundColor Magenta
Write-Host "      but standard audio file tags don't have dedicated fields for these roles." -ForegroundColor Magenta
