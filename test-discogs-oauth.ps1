#Requires -Version 7.3

<#
.SYNOPSIS
Test Discogs OAuth configuration and API access.

.DESCRIPTION
Demonstrates setting up and testing Discogs OAuth 1.0a authentication.
#>

Write-Host "`n=== Discogs OAuth Configuration Test ===" -ForegroundColor Cyan

# Import module (force reload to pick up new functions)
Remove-Module MuFo -ErrorAction SilentlyContinue
Import-Module .\MuFo.psd1 -Force -Verbose:$false

# Force reload of Invoke-DiscogsRequest to get latest version
$requestFile = Join-Path $PSScriptRoot "Private\manual\Invoke-DiscogsRequest.ps1"
if (Test-Path $requestFile) {
    . $requestFile
    Write-Verbose "Reloaded Invoke-DiscogsRequest from file"
} else {
    Write-Error "Invoke-DiscogsRequest.ps1 not found at: $requestFile"
    exit 1
}

Write-Host "`n1. Checking current Discogs configuration..." -ForegroundColor Yellow

$config = Get-MuFoConfig -Provider Discogs -Verbose

if ($config) {
    Write-Host "`nCurrent Discogs configuration:" -ForegroundColor Green
    
    if ($config.ConsumerKey) {
        Write-Host "  ConsumerKey: $($config.ConsumerKey.Substring(0, [Math]::Min(10, $config.ConsumerKey.Length)))..." -ForegroundColor Cyan
    }
    if ($config.ConsumerSecret) {
        Write-Host "  ConsumerSecret: $('*' * 20)" -ForegroundColor Cyan
    }
    if ($config.Token) {
        Write-Host "  Token (legacy): $('*' * 20)" -ForegroundColor Yellow
    }
} else {
    Write-Warning "No Discogs configuration found"
    Write-Host "`nTo configure Discogs OAuth:" -ForegroundColor Yellow
    Write-Host "  Set-MuFoConfig -DiscogsConsumerKey 'YOUR_KEY' -DiscogsConsumerSecret 'YOUR_SECRET'" -ForegroundColor White
    Write-Host "`nGet credentials at: https://www.discogs.com/settings/developers" -ForegroundColor Cyan
}

Write-Host "`n2. Testing configuration validity..." -ForegroundColor Yellow

$testResult = Test-MuFoConfig -Provider Discogs

if ($testResult) {
    Write-Host "`nValidation result:" -ForegroundColor Green
    $testResult | Format-Table Provider, ConfigComplete, ValidationPassed, Message -AutoSize
} else {
    Write-Warning "Configuration test failed"
}

Write-Host "`n3. Example: How to set Discogs OAuth credentials" -ForegroundColor Yellow

Write-Host @"

# Step 1: Get your credentials from Discogs
# Visit: https://www.discogs.com/settings/developers
# Click "Create an App" or use existing app
# Copy your Consumer Key and Consumer Secret

# Step 2: Set credentials in MuFo
Set-MuFoConfig -DiscogsConsumerKey 'your_consumer_key_here' -DiscogsConsumerSecret 'your_consumer_secret_here'

# Step 3: Verify
Test-MuFoConfig -Provider Discogs

# Step 4: Use in your code
`$artists = Invoke-DiscogsRequest -Uri '/database/search?q=Pink Floyd&type=artist'
"@ -ForegroundColor Gray

Write-Host "`n4. Testing Discogs API access (if configured)..." -ForegroundColor Yellow

if ($config -and ($config.ConsumerKey -or $config.Token)) {
    try {
        Write-Host "Attempting test search for 'Beatles'..." -ForegroundColor Cyan
        
        # Test search
        $searchResult = Invoke-DiscogsRequest -Uri '/database/search?q=Beatles&type=artist&per_page=3'
        
        if ($searchResult -and $searchResult.results) {
            Write-Host "`n✓ Discogs API access successful!" -ForegroundColor Green
            Write-Host "`nFound artists:" -ForegroundColor Cyan
            
            $searchResult.results | Select-Object -First 3 | ForEach-Object {
                Write-Host "  - $($_.title) (ID: $($_.id))" -ForegroundColor White
            }
            
            Write-Host "`nRate limiting info:" -ForegroundColor Yellow
            Write-Host "  Requests made: $script:DiscogsRequestCount/60 per minute" -ForegroundColor White
        } else {
            Write-Warning "Search returned no results"
        }
    }
    catch {
        Write-Warning "API test failed: $_"
        Write-Host "`nPossible issues:" -ForegroundColor Yellow
        Write-Host "  - Check your Consumer Key and Secret are correct" -ForegroundColor Gray
        Write-Host "  - Ensure your Discogs app is active" -ForegroundColor Gray
        Write-Host "  - Verify network connectivity to api.discogs.com" -ForegroundColor Gray
    }
} else {
    Write-Host "⊘ Skipping API test - no credentials configured" -ForegroundColor Yellow
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host ""
