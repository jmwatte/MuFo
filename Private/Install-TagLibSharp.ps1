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
            
            # Method 3: Download directly to module folder (simplest approach)
            try {
                Write-Host "Downloading TagLib-Sharp directly to module folder..." -ForegroundColor Yellow
                
                $nugetUrl = "https://www.nuget.org/api/v2/package/TagLibSharp"
                $tempZip = "$env:TEMP\TagLibSharp.zip"
                $moduleDir = Split-Path $PSScriptRoot -Parent  # Get MuFo module root
                $libDir = Join-Path $moduleDir "lib"
                
                # Create lib directory if it doesn't exist
                if (-not (Test-Path $libDir)) {
                    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
                }
                
                # Download the package
                Invoke-WebRequest -Uri $nugetUrl -OutFile $tempZip -ErrorAction Stop
                
                # Extract to temp location first
                $tempExtract = "$env:TEMP\TagLibSharp_Extract"
                if (Test-Path $tempExtract) {
                    Remove-Item $tempExtract -Recurse -Force
                }
                
                # Extract using .NET
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)
                
                # Find the TagLib.dll and copy it to module lib folder
                $tagLibDll = Get-ChildItem -Path $tempExtract -Name "TagLib.dll" -Recurse | Select-Object -First 1
                if ($tagLibDll) {
                    $sourceDll = Join-Path $tempExtract $tagLibDll
                    $destDll = Join-Path $libDir "TagLib.dll"
                    Copy-Item $sourceDll $destDll -Force
                    Write-Host "✓ TagLib.dll installed to: $destDll" -ForegroundColor Green
                    $installSuccess = $true
                } else {
                    throw "TagLib.dll not found in downloaded package"
                }
                
                # Clean up
                Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
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
    
    $moduleDir = Split-Path $PSScriptRoot -Parent
    $verifyPaths = @(
        (Join-Path $moduleDir "lib\TagLib.dll"),                                    # Module lib folder (preferred)
        "$env:USERPROFILE\.nuget\packages\taglib*\lib\*\TagLib.dll",              # NuGet packages
        "$env:USERPROFILE\.nuget\packages\taglibsharp*\lib\*\TagLib.dll",
        "$env:USERPROFILE\.nuget\packages\taglibsharp*\**\TagLib.dll"
    )
    
    $verified = $false
    $foundDll = $null
    
    foreach ($path in $verifyPaths) {
        if ($path -like "*\*") {
            # Handle wildcard paths
            $dlls = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -eq 'TagLib.dll' }
            
            if ($dlls) {
                $foundDll = $dlls | Select-Object -First 1
                Write-Host "✓ Installation verified: $($foundDll.FullName)" -ForegroundColor Green
                $verified = $true
                break
            }
        } elseif (Test-Path $path) {
            $foundDll = Get-Item $path
            Write-Host "✓ Installation verified: $($foundDll.FullName)" -ForegroundColor Green
            $verified = $true
            break
        }
    }
    
    if (-not $verified) {
        # Try to find any TagLib.dll in the packages directory
        $packagesDir = "$env:USERPROFILE\.nuget\packages"
        if (Test-Path $packagesDir) {
            $anyTagLib = Get-ChildItem -Path $packagesDir -Name "TagLib.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($anyTagLib) {
                $foundDll = Get-Item (Join-Path $packagesDir $anyTagLib)
                Write-Host "✓ Found TagLib.dll: $($foundDll.FullName)" -ForegroundColor Green
                $verified = $true
            }
        }
    }
    
    if (-not $verified) {
        Write-Warning "Could not verify TagLib-Sharp installation. It may not be in the expected location."
        Write-Host "Please check: $env:USERPROFILE\.nuget\packages for TagLib-Sharp" -ForegroundColor Yellow
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