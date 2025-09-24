# Safe Folder Structure for Multi-Format Classical Music Collections
# This script helps reorganize mixed-format folders to prevent MuFo track numbering issues

<#
.SYNOPSIS
    Reorganizes music folders to separate different audio formats and prevent track numbering conflicts.

.DESCRIPTION
    This script analyzes your music collection and moves files into format-specific subfolders
    to ensure MuFo can process each format separately without track numbering issues.

.PARAMETER Path
    Root path of your music collection (default: E:\_CorrectedMusic)

.PARAMETER WhatIf
    Show what would be done without making changes

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Reorganize-MusicFormats.ps1 -Path "E:\Music" -WhatIf

.EXAMPLE
    .\Reorganize-MusicFormats.ps1 -Path "E:\Music" -Force
#>

param(
    [string]$Path = "E:\_CorrectedMusic",
    [switch]$WhatIf,
    [switch]$Force
)

# Supported audio formats (same as MuFo)
$audioFormats = @('.mp3', '.flac', '.m4a', '.ogg', '.wav', '.wma', '.ape')

function Get-AudioFilesInDirectory {
    param([string]$DirectoryPath)

    $audioFiles = @()
    foreach ($format in $audioFormats) {
        $files = Get-ChildItem -Path $DirectoryPath -Filter "*$format" -File
        $audioFiles += $files
    }
    return $audioFiles
}

function Test-MixedFormats {
    param([string]$DirectoryPath)

    $audioFiles = Get-AudioFilesInDirectory -DirectoryPath $DirectoryPath
    $formats = $audioFiles | Group-Object Extension | Select-Object -ExpandProperty Name

    return @{
        HasMixedFormats = ($formats.Count -gt 1)
        Formats = $formats
        FileCount = $audioFiles.Count
    }
}

function New-FormatSubfolder {
    param(
        [string]$ParentPath,
        [string]$Format,
        [switch]$WhatIf
    )

    $formatName = $Format.TrimStart('.').ToUpper()
    $subfolderName = "$formatName"
    $subfolderPath = Join-Path -Path $ParentPath -ChildPath $subfolderName

    if (-not (Test-Path $subfolderPath)) {
        if ($WhatIf) {
            Write-Host "Would create: $subfolderPath" -ForegroundColor Cyan
        } else {
            New-Item -ItemType Directory -Path $subfolderPath -Force | Out-Null
            Write-Host "Created: $subfolderPath" -ForegroundColor Green
        }
    }

    return $subfolderPath
}

function Move-FilesToFormatFolders {
    param(
        [string]$DirectoryPath,
        [switch]$WhatIf,
        [switch]$Force
    )

    $analysis = Test-MixedFormats -DirectoryPath $DirectoryPath

    if (-not $analysis.HasMixedFormats) {
        Write-Host "✓ $DirectoryPath - No mixed formats detected" -ForegroundColor Green
        return
    }

    Write-Host "🔄 $DirectoryPath - Mixed formats detected: $($analysis.Formats -join ', ')" -ForegroundColor Yellow

    if (-not $Force -and -not $WhatIf) {
        $response = Read-Host "Reorganize this folder? (y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-Host "Skipped: $DirectoryPath" -ForegroundColor Gray
            return
        }
    }

    # Group files by format
    $audioFiles = Get-AudioFilesInDirectory -DirectoryPath $DirectoryPath
    $filesByFormat = $audioFiles | Group-Object Extension

    foreach ($formatGroup in $filesByFormat) {
        $format = $formatGroup.Name
        $files = $formatGroup.Group

        # Create format subfolder
        $subfolderPath = New-FormatSubfolder -ParentPath $DirectoryPath -Format $format -WhatIf:$WhatIf

        # Move files to subfolder
        foreach ($file in $files) {
            $destination = Join-Path -Path $subfolderPath -ChildPath $file.Name

            if ($WhatIf) {
                Write-Host "Would move: $($file.FullName) -> $destination" -ForegroundColor Cyan
            } else {
                Move-Item -Path $file.FullName -Destination $destination -Force
                Write-Host "Moved: $($file.Name) -> $format subfolder" -ForegroundColor Green
            }
        }
    }

    Write-Host "✓ Reorganized: $DirectoryPath" -ForegroundColor Green
}

# Main execution
Write-Host "🎵 Music Format Reorganization Tool" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

if (-not (Test-Path $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}

Write-Host "Analyzing: $Path" -ForegroundColor Yellow

# Get all directories recursively
$directories = Get-ChildItem -Path $Path -Directory -Recurse

$totalDirs = $directories.Count
$processedDirs = 0
$mixedFormatDirs = 0

Write-Host "Found $totalDirs directories to check..." -ForegroundColor Gray

foreach ($dir in $directories) {
    $processedDirs++
    Write-Progress -Activity "Analyzing directories" -Status "$processedDirs / $totalDirs" -PercentComplete (($processedDirs / $totalDirs) * 100)

    try {
        Move-FilesToFormatFolders -DirectoryPath $dir.FullName -WhatIf:$WhatIf -Force:$Force
    } catch {
        Write-Warning "Failed to process $($dir.FullName): $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Analyzing directories" -Completed

Write-Host "`n🎉 Reorganization complete!" -ForegroundColor Green
Write-Host "Your music collection is now safe for MuFo processing." -ForegroundColor Green