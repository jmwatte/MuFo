function Install-TagLibSharp {
<#
.SYNOPSIS
    Helper function to install TagLib-Sharp for MuFo track tagging functionality.

.DESCRIPTION
    This function attempts to install TagLib-Sharp using various methods and validates
    the installation. It provides user-friendly feedback and handles common installation issues.

.PARAMETER Force
    Force reinstallation even if TagLib-Sharp is already available.

.PARAMETER Scope
    Installation scope: 'AllUsers' or 'CurrentUser'. Default is 'CurrentUser'.

.EXAMPLE
    Install-TagLibSharp
    
    Installs TagLib-Sharp for the current user.

.EXAMPLE
    Install-TagLibSharp -Force -Scope AllUsers
    
    Forces reinstallation for all users.

.NOTES
    This is a helper function for MuFo's track tagging capabilities.
    Author: jmw
#>
    [CmdletBinding()]
    param(
        [switch]$Force,
        
        [ValidateSet('AllUsers', 'CurrentUser')]
        [string]$Scope = 'CurrentUser'
    )
    
    Write-Host "=== TagLib-Sharp Installation Helper ===" -ForegroundColor Cyan
    
    # Check if already installed (unless forcing)
    if (-not $Force) {
        $existing = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' }
        if ($existing) {
            Write-Host "✓ TagLib-Sharp is already loaded in current session" -ForegroundColor Green
            return
        }
        
        # Check for installed packages
        $installedPaths = @(
            "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",
            "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll"
        )
        
        $found = $false
        foreach ($path in $installedPaths) {
            $dll = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Name -eq 'TagLib.dll' } | 
                   Select-Object -First 1
            if ($dll) {
                Write-Host "✓ TagLib-Sharp found at: $($dll.FullName)" -ForegroundColor Green
                $found = $true
                break
            }
        }
        
        if ($found) {
            Write-Host "TagLib-Sharp is available. Run Get-AudioFileTags to use it." -ForegroundColor Green
            return
        }
    }
    
    # Attempt installation
    Write-Host "Installing TagLib-Sharp..." -ForegroundColor Yellow
    
    $installSuccess = $false
    
    try {
        # Method 1: Try PackageManagement
        if (Get-Command Install-Package -ErrorAction SilentlyContinue) {
            Write-Host "Using PackageManagement to install TagLib-Sharp..." -ForegroundColor Yellow
            
            $installParams = @{
                Name = 'TagLibSharp'
                Scope = $Scope
                Force = $Force
                SkipDependencies = $true
                ProviderName = 'NuGet'
                ErrorAction = 'Stop'
            }
            
            Install-Package @installParams
            $installSuccess = $true
            Write-Host "✓ TagLib-Sharp installed via PackageManagement" -ForegroundColor Green
        }
        else {
            throw "PackageManagement not available"
        }
    }
    catch {
        Write-Warning "PackageManagement installation failed: $($_.Exception.Message)"
        
        # Method 2: Try alternative NuGet approach
        try {
            Write-Host "Trying alternative installation method..." -ForegroundColor Yellow
            
            # Try installing with different parameters
            $altParams = @{
                Name = 'TagLibSharp'
                Scope = $Scope
                Force = $true
                AllowClobber = $true
                ErrorAction = 'Stop'
            }
            
            Install-Package @altParams
            $installSuccess = $true
            Write-Host "✓ TagLib-Sharp installed via alternative method" -ForegroundColor Green
        }
        catch {
            Write-Warning "Alternative installation failed: $($_.Exception.Message)"
            
            # Method 3: Try direct NuGet download
            try {
                Write-Host "Trying direct NuGet download..." -ForegroundColor Yellow
                
                $nugetUrl = "https://www.nuget.org/api/v2/package/TagLibSharp"
                $tempZip = "$env:TEMP\TagLibSharp.zip"
                $extractDir = "$env:USERPROFILE\.nuget\packages\taglibsharp"
                
                # Download the package
                Invoke-WebRequest -Uri $nugetUrl -OutFile $tempZip -ErrorAction Stop
                
                # Extract it
                if (Test-Path $extractDir) {
                    Remove-Item $extractDir -Recurse -Force
                }
                Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
                
                # Clean up
                Remove-Item $tempZip -Force
                
                $installSuccess = $true
                Write-Host "✓ TagLib-Sharp downloaded and extracted manually" -ForegroundColor Green
            }
            catch {
                Write-Error "All installation methods failed:"
                Write-Host ""
                Write-Host "The automatic installation encountered errors. Please try manual installation:" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Option 1: PowerShell Package Manager (retry)" -ForegroundColor Cyan
                Write-Host "  Install-Package TagLibSharp -Scope CurrentUser -Force" -ForegroundColor White
                Write-Host ""
                Write-Host "Option 2: NuGet CLI" -ForegroundColor Cyan
                Write-Host "  nuget install TagLibSharp -OutputDirectory `$env:USERPROFILE\.nuget\packages" -ForegroundColor White
                Write-Host ""
                Write-Host "Option 3: Manual Download" -ForegroundColor Cyan
                Write-Host "  1. Visit: https://www.nuget.org/packages/TagLibSharp/" -ForegroundColor White
                Write-Host "  2. Download the .nupkg file" -ForegroundColor White
                Write-Host "  3. Extract TagLib.dll to the MuFo module directory" -ForegroundColor White
                
                return
            }
        }
    }
    
    if (-not $installSuccess) {
        Write-Warning "Installation may have failed. Proceeding with verification..."
    }
    
    # Verify installation
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    $verifyPaths = @(
        "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",
        "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll"
    )
    
    $verified = $false
    foreach ($path in $verifyPaths) {
        $dll = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
               Where-Object { $_.Name -eq 'TagLib.dll' } | 
               Select-Object -First 1
        if ($dll) {
            Write-Host "✓ Installation verified: $($dll.FullName)" -ForegroundColor Green
            $verified = $true
            break
        }
    }
    
    if (-not $verified) {
        Write-Warning "Could not verify TagLib-Sharp installation. It may not be in the expected location."
        return
    }
    
    # Test loading
    try {
        Add-Type -Path $dll.FullName
        Write-Host "✓ TagLib-Sharp loaded successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use MuFo's track tagging features:" -ForegroundColor Cyan
        Write-Host "  Invoke-MuFo -Path 'C:\Music' -IncludeTracks" -ForegroundColor White
    }
    catch {
        Write-Warning "TagLib-Sharp installed but failed to load: $($_.Exception.Message)"
        Write-Host "You may need to restart PowerShell." -ForegroundColor Yellow
    }
}