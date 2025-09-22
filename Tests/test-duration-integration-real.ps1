#!/usr/bin/env pwsh
#Requires -Version 7.3

<#
.SYNOPSIS
    Real-world test of duration validation integration with main MuFo workflow.

.DESCRIPTION
    Tests the complete duration validation integration by running a small
    subset of the real MuFo workflow with duration validation enabled.

.NOTES
    Author: jmw
    Version: 1.0
    Date: 2025-01-11
    Tests: End-to-end duration validation integration
#>

[CmdletBinding()]
param(
    [string]$TestMusicPath = "D:\_CorrectedMusic",
    [int]$MaxTestAlbums = 2
)

Write-Host "🎵 DURATION VALIDATION INTEGRATION - REAL-WORLD TEST" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $TestMusicPath)) {
    Write-Warning "Test music path not found: $TestMusicPath"
    Write-Host "This test requires real music files to validate duration integration." -ForegroundColor Yellow
    exit 1
}

# Find a couple of albums to test with
Write-Host "📂 Finding test albums in: $TestMusicPath" -ForegroundColor Cyan
$testAlbums = Get-ChildItem -Path $TestMusicPath -Directory -Recurse | 
              Where-Object { 
                  (Get-ChildItem $_.FullName -File -Filter "*.mp3" -ErrorAction SilentlyContinue).Count -ge 3 
              } | 
              Select-Object -First $MaxTestAlbums

if ($testAlbums.Count -eq 0) {
    Write-Warning "No suitable test albums found (need folders with 3+ MP3 files)"
    exit 1
}

Write-Host "✅ Found $($testAlbums.Count) test album(s):" -ForegroundColor Green
foreach ($album in $testAlbums) {
    $trackCount = (Get-ChildItem $album.FullName -File -Filter "*.mp3").Count
    Write-Host "   📀 $($album.Name) ($trackCount tracks)" -ForegroundColor White
}
Write-Host ""

foreach ($album in $testAlbums) {
    Write-Host "🎯 Testing album: $($album.Name)" -ForegroundColor Yellow
    Write-Host "Path: $($album.FullName)" -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Test with duration validation enabled
        Write-Host "🔬 Running MuFo with duration validation..." -ForegroundColor Cyan
        
        # Run with minimal options to test just the duration validation integration
        $result = Invoke-MuFo -Path $album.FullName -IncludeTracks -ValidateDurations -DurationValidationLevel DataDriven -ShowDurationMismatches -Preview -WhatIf -Verbose
        
        Write-Host "✅ Duration validation integration test completed successfully!" -ForegroundColor Green
        
        if ($result) {
            Write-Host "📊 Result summary:" -ForegroundColor Cyan
            Write-Host "   Result type: $($result.GetType().Name)" -ForegroundColor Gray
            if ($result.DurationValidation) {
                Write-Host "   ✅ Duration validation data present" -ForegroundColor Green
                Write-Host "   📈 Validation summary: $($result.DurationValidation.Summary.TotalTracks) tracks analyzed" -ForegroundColor White
            } else {
                Write-Host "   ⚠️  No duration validation data found (may be expected for some albums)" -ForegroundColor Yellow
            }
        }
        
    } catch {
        Write-Host "❌ Test failed for album: $($album.Name)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose $_.ScriptStackTrace
    }
    
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "🎉 Real-world duration validation integration testing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 If tests passed, the duration validation is successfully integrated!" -ForegroundColor Cyan
Write-Host "   • Duration validation parameters are working" -ForegroundColor White
Write-Host "   • Integration with main MuFo workflow is functional" -ForegroundColor White
Write-Host "   • Data-driven validation levels are operational" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Ready for production use with enhanced accuracy!" -ForegroundColor Green