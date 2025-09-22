# Test Artist Parameter Split - Comprehensive Examples
# This test demonstrates the new AlbumArtists vs TrackArtists distinction

Write-Host "=== MuFo Artist Parameter Split Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Default behavior (AlbumArtists only)
Write-Host "1. 🎵 DEFAULT BEHAVIOR: Fix AlbumArtists only (80% use case)" -ForegroundColor Green
Write-Host "   Command: Invoke-MuFo -Path 'Album' -FixTags"
Write-Host "   Behavior: Fixes album-level artist, preserves track performers"
Write-Host ""

# Test 2: Compilation album scenario  
Write-Host "2. 🎼 COMPILATION ALBUMS: Preserve track artists" -ForegroundColor Green
Write-Host "   Command: Invoke-MuFo -Path 'NowMusic45' -FixTags -DontFix 'TrackArtists'"
Write-Host "   Behavior: Sets album artist to 'Various Artists', keeps individual performers"
Write-Host ""

# Test 3: Fix only album artists
Write-Host "3. 🎯 ALBUM ARTIST ONLY: Targeted fixing" -ForegroundColor Green  
Write-Host "   Command: Invoke-MuFo -Path 'Album' -FixTags -FixOnly 'AlbumArtists'"
Write-Host "   Behavior: Only fixes album artist, leaves everything else untouched"
Write-Host ""

# Test 4: Classical music scenario
Write-Host "4. 🎭 CLASSICAL MUSIC: Composer optimization" -ForegroundColor Green
Write-Host "   Command: Invoke-MuFo -Path 'Beethoven' -FixTags -OptimizeClassicalTags"
Write-Host "   Behavior: Sets composer as album artist, preserves orchestra/conductor as track artists"
Write-Host ""

# Test 5: Show what would change
Write-Host "5. 🔍 PREVIEW CHANGES: See what would happen" -ForegroundColor Green
Write-Host "   Command: Invoke-MuFo -Path 'Album' -FixTags -WhatIf"
Write-Host "   Behavior: Shows artist changes without applying them"
Write-Host ""

# Test parameter validation
Write-Host "6. ✅ TESTING PARAMETER VALIDATION..." -ForegroundColor Yellow

try {
    # Test that new parameters are available
    $fixOnlyParams = (Get-Command Invoke-MuFo).Parameters.FixOnly.Attributes | Where-Object { $_.TypeId -like '*ValidateSetAttribute*' }
    $validValues = $fixOnlyParams.ValidValues
    
    Write-Host "   FixOnly valid values: $($validValues -join ', ')" -ForegroundColor Gray
    
    if ('AlbumArtists' -in $validValues -and 'TrackArtists' -in $validValues) {
        Write-Host "   ✅ AlbumArtists and TrackArtists parameters available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ New artist parameters not found" -ForegroundColor Red
    }
    
    # Test that old 'Artists' parameter is removed
    if ('Artists' -notin $validValues) {
        Write-Host "   ✅ Old ambiguous 'Artists' parameter removed" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Old 'Artists' parameter still present" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "   ❌ Error testing parameters: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== SMART BEHAVIOR EXAMPLES ===" -ForegroundColor Cyan

# Example scenarios
$scenarios = @(
    @{
        Title = "🎵 Regular Album"
        Example = "Pink Floyd - The Wall"
        Command = "-FixTags"
        Result = "Album Artist: Pink Floyd, Track Artists: Preserved/Fixed to Pink Floyd"
    },
    @{
        Title = "🎼 Compilation Album"  
        Example = "Now That's What I Call Music 45"
        Command = "-FixTags (auto-detects compilation)"
        Result = "Album Artist: Various Artists, Track Artists: Individual performers preserved"
    },
    @{
        Title = "🎭 Classical Album"
        Example = "Beethoven: Symphony No. 9"
        Command = "-FixTags -OptimizeClassicalTags"
        Result = "Album Artist: Ludwig van Beethoven, Track Artists: Orchestra/Conductor preserved"
    },
    @{
        Title = "🎯 Manual Control"
        Example = "Soundtrack Album"
        Command = "-FixTags -DontFix 'TrackArtists'"
        Result = "Album Artist: Fixed, Track Artists: Completely preserved"
    }
)

foreach ($scenario in $scenarios) {
    Write-Host $scenario.Title -ForegroundColor Green
    Write-Host "   Example: $($scenario.Example)" -ForegroundColor Gray
    Write-Host "   Command: Invoke-MuFo $($scenario.Command)" -ForegroundColor White
    Write-Host "   Result: $($scenario.Result)" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=== TEST COMPLETE ===" -ForegroundColor Cyan
Write-Host "The artist parameter split provides clear control over album vs track level artist information!" -ForegroundColor Green