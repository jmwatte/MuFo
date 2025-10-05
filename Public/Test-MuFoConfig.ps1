function Test-MuFoConfig {
    <#
    .SYNOPSIS
    Tests MuFo configuration and validates API credentials.
    
    .DESCRIPTION
    Checks if configuration exists and optionally validates credentials by making test API calls.
    
    .PARAMETER Provider
    Test specific provider. If not specified, tests all configured providers.
    
    .PARAMETER SkipValidation
    Only check if configuration exists, don't make API calls to validate.
    
    .EXAMPLE
    Test-MuFoConfig
    Tests all configured providers and validates credentials.
    
    .EXAMPLE
    Test-MuFoConfig -Provider Spotify
    Tests only Spotify configuration.
    
    .EXAMPLE
    Test-MuFoConfig -SkipValidation
    Checks if config exists without validating credentials.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )

    $results = @()

    # Get configuration
    try {
        $config = Get-MuFoConfig
        if (-not $config) {
            Write-Warning "No configuration found. Run 'Set-MuFoConfig' to configure credentials."
            Write-Host "See: .\documentation\CONFIGURATION-GUIDE.md" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        return $null
    }

    # Determine which providers to test
    $providersToTest = if ($Provider) {
        @($Provider)
    } else {
        $config.PSObject.Properties.Name
    }

    foreach ($providerName in $providersToTest) {
        $providerConfig = $config.$providerName
        
        if (-not $providerConfig) {
            Write-Verbose "No configuration for $providerName"
            continue
        }

        $result = [PSCustomObject]@{
            Provider = $providerName
            ConfigExists = $true
            ConfigComplete = $false
            ValidationPassed = $null
            Message = ""
        }

        # Check if all required fields are present
        switch ($providerName) {
            'Spotify' {
                $result.ConfigComplete = ($providerConfig.ClientId -and $providerConfig.ClientSecret)
                
                if (-not $SkipValidation -and $result.ConfigComplete) {
                    try {
                        # Test Spotify connection
                        if (Get-Module -Name Spotishell) {
                            # Use existing Spotishell module
                            $testAuth = Get-SpotifyAccessToken -ClientId $providerConfig.ClientId -ClientSecret $providerConfig.ClientSecret
                            if ($testAuth) {
                                $result.ValidationPassed = $true
                                $result.Message = "✓ Spotify credentials valid"
                            }
                        } else {
                            $result.ValidationPassed = $null
                            $result.Message = "⚠ Spotishell module not loaded, cannot validate"
                        }
                    }
                    catch {
                        $result.ValidationPassed = $false
                        $result.Message = "✗ Spotify validation failed: $_"
                    }
                }
            }
            
            'Qobuz' {
                $result.ConfigComplete = ($providerConfig.AppId -and $providerConfig.Secret)
                
                if (-not $SkipValidation -and $result.ConfigComplete) {
                    # Qobuz validation would go here
                    $result.ValidationPassed = $null
                    $result.Message = "⚠ Qobuz validation not yet implemented"
                }
            }
            
            'Discogs' {
                # Check for token (recommended) or OAuth credentials
                $hasToken = ($null -ne $providerConfig.Token -and $providerConfig.Token -ne "")
                $hasOAuth = ($null -ne $providerConfig.ConsumerKey -and $providerConfig.ConsumerKey -ne "" -and
                            $null -ne $providerConfig.ConsumerSecret -and $providerConfig.ConsumerSecret -ne "")
                
                $result.ConfigComplete = ($hasToken -or $hasOAuth)
                
                if (-not $SkipValidation -and $result.ConfigComplete) {
                    try {
                        $headers = @{
                            'User-Agent' = 'MuFo/1.0 (https://github.com/jmwatte/MuFo)'
                        }
                        
                        # Personal Access Token is the recommended approach
                        if ($hasToken) {
                            $headers['Authorization'] = "Discogs token=$($providerConfig.Token)"
                            $testUri = "https://api.discogs.com/database/search?q=test&type=artist&per_page=1"
                            $null = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get -ErrorAction Stop
                            
                            $result.ValidationPassed = $true
                            $result.Message = "✓ Discogs Personal Access Token valid"
                        }
                        elseif ($hasOAuth) {
                            # OAuth 1.0a requires complex signature generation
                            $result.ValidationPassed = $null
                            $result.Message = "⚠ Discogs OAuth configured but requires OAuth 1.0a implementation. Consider using Personal Access Token instead."
                        }
                    }
                    catch {
                        $result.ValidationPassed = $false
                        $result.Message = "✗ Discogs validation failed: $($_.Exception.Message)"
                    }
                }
            }
        }

        # Set message if config is incomplete
        if (-not $result.ConfigComplete) {
            $result.Message = "⚠ Incomplete configuration (missing required fields)"
        }

        $results += $result
    }

    # Display results
    Write-Host "`nConfiguration Status:" -ForegroundColor Cyan
    $results | Format-Table Provider, ConfigExists, ConfigComplete, ValidationPassed, Message -AutoSize

    # Summary
    $configured = ($results | Where-Object { $_.ConfigComplete }).Count
    $validated = ($results | Where-Object { $_.ValidationPassed -eq $true }).Count
    
    Write-Host "Summary: $configured configured, $validated validated" -ForegroundColor $(if ($configured -gt 0) { 'Green' } else { 'Yellow' })
    
    if ($configured -eq 0) {
        Write-Host "`nTo configure credentials:" -ForegroundColor Yellow
        Write-Host "  Set-MuFoConfig -SpotifyClientId 'your_id' -SpotifyClientSecret 'your_secret'" -ForegroundColor White
        Write-Host "`nSee: .\documentation\CONFIGURATION-GUIDE.md" -ForegroundColor Yellow
    }

    return $results
}
