#Requires -Version 7.3

<#
.SYNOPSIS
Test script for MuFo configuration management.

.DESCRIPTION
Demonstrates how to set, get, and validate MuFo API credentials.
#>

Write-Host "`n=== MuFo Configuration Test ===" -ForegroundColor Cyan

# Import module
Import-Module .\MuFo.psd1 -Force

Write-Host "`n1. Testing configuration storage..." -ForegroundColor Yellow

# Example: Set configuration
Write-Host "`nSetting test configuration (these are fake credentials for demo)..."
$setResult = Set-MuFoConfig `
    -SpotifyClientId "test_client_id_123" `
    -SpotifyClientSecret "test_secret_456" `
    -DiscogsToken "test_discogs_token_789" `
    -Verbose `
    -WhatIf

if ($setResult.Success) {
    Write-Host "✓ Configuration saved successfully" -ForegroundColor Green
} else {
    Write-Warning "Configuration save failed"
}

Write-Host "`n2. Testing configuration retrieval..." -ForegroundColor Yellow

# Get all configuration
Write-Host "`nRetrieving all configuration..."
$config = Get-MuFoConfig -Verbose

if ($config) {
    Write-Host "`nFull configuration:" -ForegroundColor Green
    $config | Format-List
    
    # Get specific provider
    Write-Host "`n3. Testing provider-specific configuration..." -ForegroundColor Yellow
    
    $spotifyConfig = Get-MuFoConfig -Provider Spotify
    if ($spotifyConfig) {
        Write-Host "`nSpotify configuration:" -ForegroundColor Green
        Write-Host "  ClientId: $($spotifyConfig.ClientId)"
        Write-Host "  ClientSecret: $($spotifyConfig.ClientSecret -replace '.', '*')" # Masked
    }
    
    $discogsConfig = Get-MuFoConfig -Provider Discogs
    if ($discogsConfig) {
        Write-Host "`nDiscogs configuration:" -ForegroundColor Green
        Write-Host "  Token: $($discogsConfig.Token -replace '.', '*')" # Masked
    }
} else {
    Write-Warning "No configuration found"
}

Write-Host "`n4. Testing environment variable override..." -ForegroundColor Yellow

# Test environment variable override
$originalEnv = $env:SPOTIFY_CLIENT_ID
$env:SPOTIFY_CLIENT_ID = "env_override_test_123"

$configWithEnv = Get-MuFoConfig -Provider Spotify -Verbose
Write-Host "`nSpotify ClientId (with env override): $($configWithEnv.ClientId)"

if ($configWithEnv.ClientId -eq "env_override_test_123") {
    Write-Host "✓ Environment variable override works" -ForegroundColor Green
} else {
    Write-Warning "Environment variable override failed"
}

# Restore original
$env:SPOTIFY_CLIENT_ID = $originalEnv

Write-Host "`n5. Configuration file location..." -ForegroundColor Yellow

$expectedPath = if ($IsLinux -or $IsMacOS) {
    Join-Path $env:HOME '.mufo' 'config.json'
} else {
    Join-Path $env:USERPROFILE '.mufo' 'config.json'
}

Write-Host "Expected config path: $expectedPath"
Write-Host "Config exists: $(Test-Path $expectedPath)"

Write-Host "`n=== Configuration Test Complete ===" -ForegroundColor Cyan

Write-Host "`n" -NoNewline
Write-Host "To set your actual credentials, run:" -ForegroundColor Yellow
Write-Host "  Set-MuFoConfig -SpotifyClientId 'your_id' -SpotifyClientSecret 'your_secret'" -ForegroundColor White
Write-Host "`nTo view configuration guide:" -ForegroundColor Yellow
Write-Host "  Get-Content .\documentation\CONFIGURATION-GUIDE.md | more" -ForegroundColor White
Write-Host ""
