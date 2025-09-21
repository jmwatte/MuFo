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
            }
            
            Install-Package @installParams
            Write-Host "✓ TagLib-Sharp installed via PackageManagement" -ForegroundColor Green
        }
        else {
            throw "PackageManagement not available"
        }
    }
    catch {
        Write-Warning "PackageManagement installation failed: $($_.Exception.Message)"
        
        # Method 2: Try NuGet directly  
        try {
            Write-Host "Trying direct NuGet installation..." -ForegroundColor Yellow
            
            $nugetPath = "$env:TEMP\nuget.exe"
            if (-not (Test-Path $nugetPath)) {
                Write-Host "Downloading NuGet.exe..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath
            }
            
            $packagesDir = "$env:USERPROFILE\.nuget\packages"
            if (-not (Test-Path $packagesDir)) {
                New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null
            }
            
            & $nugetPath install TagLibSharp -OutputDirectory $packagesDir
            Write-Host "✓ TagLib-Sharp installed via NuGet" -ForegroundColor Green
        }
        catch {
            Write-Error "All installation methods failed. Please install manually:"
            Write-Host ""
            Write-Host "Option 1: PowerShell Package Manager" -ForegroundColor Yellow
            Write-Host "  Install-Package TagLibSharp -Scope CurrentUser" -ForegroundColor White
            Write-Host ""
            Write-Host "Option 2: Download manually" -ForegroundColor Yellow
            Write-Host "  1. Download TagLib-Sharp from: https://github.com/mono/taglib-sharp" -ForegroundColor White
            Write-Host "  2. Extract TagLib-Sharp.dll" -ForegroundColor White
            Write-Host "  3. Place in MuFo module directory" -ForegroundColor White
            throw "Installation failed"
        }
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