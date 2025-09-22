function Get-ExclusionsStorePath {
<#
.SYNOPSIS
    Gets the path for storing exclusions files.

.DESCRIPTION
    Returns the directory and file path for exclusions storage.

.OUTPUTS
    PSCustomObject with Dir and File properties
#>
    $storeDir = Join-Path $PSScriptRoot '..\Public\Exclusions'
    $storeFile = Join-Path $storeDir 'excluded-folders.json'
    return [PSCustomObject]@{ Dir = $storeDir; File = $storeFile }
}

function Read-ExcludedFoldersFromDisk {
<#
.SYNOPSIS
    Reads excluded folders from disk storage.

.PARAMETER FilePath
    Path to the exclusions JSON file.

.OUTPUTS
    Array of excluded folder patterns
#>
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        try {
            $content = Get-Content $FilePath -Raw | ConvertFrom-Json
            if ($content) {
                # Handle both array format and single-item format
                if ($content -is [array]) {
                    return @($content)
                } else {
                    return @($content.ToString())
                }
            }
        } catch {
            Write-Warning "Failed to read exclusions from '$FilePath': $($_.Exception.Message)"
        }
    }
    return @()
}

function Test-ExclusionMatch {
<#
.SYNOPSIS
    Tests if a folder name matches any exclusion pattern.

.PARAMETER FolderName
    The folder name to test.

.PARAMETER Exclusions
    Array of exclusion patterns (supports wildcards: *, ?, []).

.OUTPUTS
    Boolean indicating if the folder should be excluded

.EXAMPLE
    Test-ExclusionMatch -FolderName "E_bonus" -Exclusions @("E_*")
    Returns True (matches prefix wildcard)

.EXAMPLE
    Test-ExclusionMatch -FolderName "Album1" -Exclusions @("Album[0-9]")
    Returns True (matches character class wildcard)

.NOTES
    Supports PowerShell wildcard patterns:
    - * : Matches zero or more characters
    - ? : Matches exactly one character  
    - [] : Matches any character in the brackets (character classes)
    All matches are case-insensitive for backward compatibility.
#>
    param([string]$FolderName, [string[]]$Exclusions)
    
    if (-not $Exclusions -or $Exclusions.Count -eq 0) { 
        return $false 
    }
    
    foreach ($pattern in $Exclusions) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { 
            # Empty or whitespace pattern matches only empty folder names
            if ([string]::IsNullOrWhiteSpace($FolderName)) {
                Write-Verbose "Empty folder name matched empty pattern"
                return $true
            }
            continue 
        }
        
        try {
            # Check if pattern contains any wildcard characters
            $hasWildcards = $pattern.IndexOfAny(@('*', '?', '[', ']')) -ge 0
            
            if ($hasWildcards) {
                # Use PowerShell's -like operator for wildcard matching (case-insensitive)
                if ($FolderName -like $pattern) { 
                    Write-Verbose "Folder '$FolderName' matched wildcard pattern '$pattern'"
                    return $true 
                }
            } else {
                # Use exact case-insensitive matching for non-wildcard patterns
                if ([string]::Equals($FolderName, $pattern, [StringComparison]::InvariantCultureIgnoreCase)) { 
                    Write-Verbose "Folder '$FolderName' matched exact pattern '$pattern'"
                    return $true 
                }
            }
        } catch {
            # If pattern is invalid, skip it and continue with a warning
            Write-Verbose ("Invalid exclusion pattern '{0}': {1}" -f $pattern, $_.Exception.Message)
            continue
        }
    }
    return $false
}

function Write-ExcludedFoldersToDisk {
<#
.SYNOPSIS
    Writes excluded folders to disk storage.

.PARAMETER Exclusions
    Array of exclusion patterns to save.

.PARAMETER FilePath
    Path to save the exclusions JSON file.
#>
    param([string[]]$Exclusions, [string]$FilePath)
    
    try {
        $dir = Split-Path $FilePath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Exclusions | ConvertTo-Json | Set-Content -Path $FilePath -Encoding UTF8
        Write-Verbose "Saved exclusions to '$FilePath'"
    } catch {
        Write-Warning "Failed to save exclusions to '$FilePath': $($_.Exception.Message)"
    }
}

function Get-EffectiveExclusions {
<#
.SYNOPSIS
    Computes the effective exclusions based on command-line and file-based exclusions.

.PARAMETER ExcludeFolders
    Command-line exclusions.

.PARAMETER ExcludedFoldersLoad
    Path to load file-based exclusions from.

.PARAMETER ExcludedFoldersReplace
    Whether to replace (true) or merge (false) exclusions.

.OUTPUTS
    Array of effective exclusion patterns
#>
    param(
        [string[]]$ExcludeFolders = @(),
        [string]$ExcludedFoldersLoad,
        [switch]$ExcludedFoldersReplace
    )

    $effectiveExclusions = @()

    # First, add command-line exclusions if provided
    if ($ExcludeFolders -and $ExcludeFolders.Count -gt 0) {
        $effectiveExclusions += $ExcludeFolders
        Write-Verbose "Added command-line exclusions: $($ExcludeFolders -join ', ')"
    }

    # Then handle file-based exclusions
    if ($ExcludedFoldersLoad -and (Test-Path $ExcludedFoldersLoad)) {
        $loadedResult = Read-ExcludedFoldersFromDisk -FilePath $ExcludedFoldersLoad
        if ($loadedResult -and $loadedResult.Count -gt 0) {
            Write-Verbose "Loaded exclusions from file '$ExcludedFoldersLoad': $($loadedResult -join ', ')"
            
            if ($ExcludedFoldersReplace) {
                # Replace mode: clear existing exclusions and use only command line
                $effectiveExclusions = @()
                Write-Verbose "Replace mode: cleared existing exclusions"
                
                if ($ExcludeFolders -and $ExcludeFolders.Count -gt 0) {
                    $effectiveExclusions += $ExcludeFolders
                    Write-Verbose "Replace mode: re-added command-line exclusions: $($ExcludeFolders -join ', ')"
                }
            } else {
                # Merge mode: add file exclusions to existing command-line exclusions
                $effectiveExclusions += $loadedResult
                Write-Verbose "Merge mode: added file exclusions to existing ones"
            }
        }
    }

    # Remove duplicates and return (ensure we always return an array, never null)
    $result = @($effectiveExclusions | Select-Object -Unique)
    if ($null -eq $result) {
        return @()
    }
    return $result
}

function Show-Exclusions {
<#
.SYNOPSIS
    Displays current effective and persisted exclusions.

.PARAMETER EffectiveExclusions
    Array of current effective exclusions.

.PARAMETER ExcludedFoldersLoad
    Path to persisted exclusions file.
#>
    param(
        [string[]]$EffectiveExclusions,
        [string]$ExcludedFoldersLoad
    )

    Write-Host "Effective Exclusions:" -ForegroundColor Cyan
    if ($EffectiveExclusions -and $EffectiveExclusions.Count -gt 0) {
        foreach ($exclusion in $EffectiveExclusions) {
            Write-Host "  $exclusion" -ForegroundColor White
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }

    Write-Host "Persisted Exclusions:" -ForegroundColor Cyan
    if ($ExcludedFoldersLoad -and (Test-Path $ExcludedFoldersLoad)) {
        $persistedExclusions = Read-ExcludedFoldersFromDisk -FilePath $ExcludedFoldersLoad
        if ($persistedExclusions -and $persistedExclusions.Count -gt 0) {
            foreach ($exclusion in $persistedExclusions) {
                Write-Host "  $exclusion" -ForegroundColor White
            }
        } else {
            Write-Host "  (none)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
}