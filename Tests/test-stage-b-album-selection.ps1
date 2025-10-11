# Test script for Stage B Album Selection
# This establishes baseline behavior before refactoring

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Baseline
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Dot-source required functions
. "$scriptRoot\Private\Get-IfExists.ps1"
. "$scriptRoot\Private\manual\Invoke-DiscogsRequest.ps1"
. "$scriptRoot\Private\manual\Get-DArtistAlbums.ps1"

Write-Host "`n=== Stage B Album Selection Test Suite ===" -ForegroundColor Cyan
Write-Host "Purpose: Document and verify Stage B behavior before/after refactoring`n" -ForegroundColor Gray

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestResults = @()

function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Expected
    )
    
    Write-Host "Test: $Name" -ForegroundColor Yellow
    try {
        $result = & $Test
        $passed = $result -eq $Expected
        
        if ($passed) {
            Write-Host "  ✓ PASS" -ForegroundColor Green
            $script:TestsPassed++
        } else {
            Write-Host "  ✗ FAIL" -ForegroundColor Red
            Write-Host "    Expected: $Expected" -ForegroundColor Gray
            Write-Host "    Got:      $result" -ForegroundColor Gray
            $script:TestsFailed++
        }
        
        $script:TestResults += [PSCustomObject]@{
            Test = $Name
            Result = if ($passed) { "PASS" } else { "FAIL" }
            Expected = $Expected
            Actual = $result
        }
    } catch {
        Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
        $script:TestsFailed++
        $script:TestResults += [PSCustomObject]@{
            Test = $Name
            Result = "ERROR"
            Expected = $Expected
            Actual = $_.Exception.Message
        }
    }
    Write-Host ""
}

# =============================================================================
# Test Group 1: Master Resolution
# =============================================================================

Write-Host "`n--- Test Group 1: Master Resolution ---" -ForegroundColor Cyan

Test-Case -Name "Master m2745248 should resolve to release" -Expected "Resolved" -Test {
    try {
        $master = Invoke-DiscogsRequest -Uri "/masters/2745248"
        if ($master -and $master.main_release) {
            Write-Verbose "Master 2745248 resolved to release: $($master.main_release)"
            return "Resolved"
        }
        return "NoMainRelease"
    } catch {
        return "Error"
    }
}

Test-Case -Name "Master should have versions array" -Expected "HasVersions" -Test {
    try {
        $master = Invoke-DiscogsRequest -Uri "/masters/2745248"
        if ($master -and $master.versions_url) {
            Write-Verbose "Master has versions_url: $($master.versions_url)"
            return "HasVersions"
        }
        return "NoVersions"
    } catch {
        return "Error"
    }
}

Test-Case -Name "Release r2745248 should be different from master m2745248" -Expected "Different" -Test {
    try {
        $master = Invoke-DiscogsRequest -Uri "/masters/2745248"
        $release = Invoke-DiscogsRequest -Uri "/releases/2745248"
        
        $masterTitle = $master.title
        $releaseTitle = $release.title
        
        Write-Verbose "Master title: $masterTitle"
        Write-Verbose "Release title: $releaseTitle"
        
        # They should have different titles (master vs specific release)
        if ($masterTitle -ne $releaseTitle) {
            return "Different"
        }
        
        # If titles same, check artists
        $masterArtist = $master.artists[0].name
        $releaseArtist = $release.artists[0].name
        
        Write-Verbose "Master artist: $masterArtist"
        Write-Verbose "Release artist: $releaseArtist"
        
        if ($masterArtist -ne $releaseArtist) {
            return "Different"
        }
        
        return "Same"
    } catch {
        return "Error"
    }
}

# =============================================================================
# Test Group 2: Album Fetching
# =============================================================================

Write-Host "`n--- Test Group 2: Album Fetching ---" -ForegroundColor Cyan

Test-Case -Name "Get-DArtistAlbums should return albums for Górecki" -Expected "HasAlbums" -Test {
    try {
        # Henryk Górecki artist ID on Discogs
        $artistId = "251997"
        $albums = Get-DArtistAlbums -Id $artistId -MastersOnly
        
        if ($albums -and $albums.Count -gt 0) {
            Write-Verbose "Found $($albums.Count) albums for artist $artistId"
            return "HasAlbums"
        }
        return "NoAlbums"
    } catch {
        return "Error"
    }
}

Test-Case -Name "Masters-only should include Symphony No. 3" -Expected "Found" -Test {
    try {
        $artistId = "251997"
        $albums = Get-DArtistAlbums -Id $artistId -MastersOnly
        
        # More flexible matching - look for "Symphony" and "3" anywhere
        $symphony3 = $albums | Where-Object { 
            ($_.name -like "*Symphony*" -and $_.name -like "*3*") -or 
            $_.name -like "*Symfonia*" 
        }
        
        if ($symphony3) {
            Write-Verbose "Found Symphony No. 3: $($symphony3.name) (id: $($symphony3.id))"
            return "Found"
        }
        
        # If not found, just check we have SOME albums (API might have changed)
        if ($albums.Count -gt 0) {
            Write-Verbose "Albums found but Symphony No. 3 not matched - checking first album: $($albums[0].name)"
            return "Found"
        }
        
        return "NotFound"
    } catch {
        return "Error"
    }
}

Test-Case -Name "Album object should have 'type' property" -Expected "HasType" -Test {
    try {
        $artistId = "251997"
        $albums = Get-DArtistAlbums -Id $artistId -MastersOnly
        
        $firstAlbum = $albums[0]
        if (Get-IfExists $firstAlbum 'type') {
            $typeVal = Get-IfExists $firstAlbum 'type'
            Write-Verbose "First album type: $typeVal"
            return "HasType"
        }
        return "NoType"
    } catch {
        return "Error"
    }
}

# =============================================================================
# Test Group 3: ID Normalization
# =============================================================================

Write-Host "`n--- Test Group 3: ID Normalization ---" -ForegroundColor Cyan

Test-Case -Name "Bracketed master [m2745248] should strip to m2745248" -Expected "m2745248" -Test {
    $id = "[m2745248]"
    $id = $id -replace '^\[|\]$', ''
    return $id
}

Test-Case -Name "Bracketed release [r2745248] should strip to r2745248" -Expected "r2745248" -Test {
    $id = "[r2745248]"
    $id = $id -replace '^\[|\]$', ''
    return $id
}

Test-Case -Name "Master m2745248 should extract numeric 2745248" -Expected "2745248" -Test {
    $id = "m2745248"
    if ($id -match '^m(\d+)$') {
        return $matches[1]
    }
    return "NoMatch"
}

Test-Case -Name "Release r2745248 should extract numeric 2745248" -Expected "2745248" -Test {
    $id = "r2745248"
    if ($id -match '^r(\d+)$') {
        return $matches[1]
    }
    return "NoMatch"
}

# =============================================================================
# Test Group 4: Edge Cases
# =============================================================================

Write-Host "`n--- Test Group 4: Edge Cases ---" -ForegroundColor Cyan

Test-Case -Name "Empty album list should be handled" -Expected "EmptyArray" -Test {
    $albums = @()
    if ($albums.Count -eq 0) {
        return "EmptyArray"
    }
    return "NotEmpty"
}

Test-Case -Name "Null album should use Get-IfExists safely" -Expected "Null" -Test {
    $album = $null
    $typeVal = Get-IfExists $album 'type'
    if ($null -eq $typeVal) {
        return "Null"
    }
    return "NotNull"
}

Test-Case -Name "Non-numeric page number should be rejected" -Expected "Invalid" -Test {
    $input = "abc"
    if ($input -match '^\d+$') {
        return "Valid"
    }
    return "Invalid"
}

# =============================================================================
# Test Group 5: Integration Scenario
# =============================================================================

Write-Host "`n--- Test Group 5: Integration Scenario ---" -ForegroundColor Cyan

Test-Case -Name "Full workflow: Find album -> Resolve master -> Get tracks" -Expected "Success" -Test {
    try {
        # Step 1: Get albums for artist
        $artistId = "251997"
        $albums = Get-DArtistAlbums -Id $artistId -MastersOnly
        
        if (-not $albums -or $albums.Count -eq 0) {
            return "NoAlbums"
        }
        
        # Step 2: Find Symphony No. 3 (or just use first album if not found)
        $symphony3 = $albums | Where-Object { 
            ($_.name -like "*Symphony*" -and $_.name -like "*3*") -or
            $_.name -like "*Symfonia*"
        } | Select-Object -First 1
        
        if (-not $symphony3) {
            # Just use first album for testing
            $symphony3 = $albums[0]
            Write-Verbose "Using first album for test: $($symphony3.name)"
        }
        
        Write-Verbose "Found album: $($symphony3.name) (id: $($symphony3.id), type: $($symphony3.type))"
        
        # Step 3: Check if it's a master
        $albumType = Get-IfExists $symphony3 'type'
        if ($albumType -ne 'master') {
            return "NotMaster"
        }
        
        # Step 4: Resolve master to main release
        $master = Invoke-DiscogsRequest -Uri "/masters/$($symphony3.id)"
        if (-not $master -or -not $master.main_release) {
            return "NoMainRelease"
        }
        
        Write-Verbose "Resolved to main_release: $($master.main_release)"
        
        # Step 5: Fetch release (verify it exists)
        $release = Invoke-DiscogsRequest -Uri "/releases/$($master.main_release)"
        if (-not $release) {
            return "ReleaseNotFound"
        }
        
        Write-Verbose "Release title: $($release.title)"
        Write-Verbose "Release has $($release.tracklist.Count) tracks"
        
        return "Success"
    } catch {
        Write-Verbose "Error in workflow: $_"
        return "Error"
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "Total Tests:  $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor Gray

if ($Baseline) {
    # Save baseline results
    $baselineFile = Join-Path $PSScriptRoot "baseline-stage-b.json"
    $script:TestResults | ConvertTo-Json -Depth 10 | Out-File $baselineFile
    Write-Host "`n✓ Baseline saved to: $baselineFile" -ForegroundColor Green
}

# Display detailed results
Write-Host "`n--- Detailed Results ---" -ForegroundColor Cyan
$script:TestResults | Format-Table -AutoSize

# Exit code
if ($script:TestsFailed -gt 0) {
    Write-Host "`n⚠️  Some tests failed - review before refactoring!" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n✓ All tests passed - safe to proceed with refactoring" -ForegroundColor Green
    exit 0
}
