# Regression test: Invoke-MuFo should still run analysis under -WhatIf
Write-Host "=== Testing Invoke-MuFo -WhatIf preview pipeline ===" -ForegroundColor Cyan

$testRoot = Join-Path $env:TEMP "MuFo-InvokeMuFo-WhatIf"
if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $testRoot | Out-Null

. .\Public\Invoke-MuFo.ps1

function Connect-SpotifyService {}

function Add-MemoryOptimization {
    param(
        [Parameter()] [int]$AlbumCount,
        [Parameter()] [string]$Phase,
        [Parameter()] [switch]$ForceCleanup
    )
}

function Get-MuFoProcessingContext {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$ArtistAt,
        [Parameter()] [string[]]$ExcludeFolders,
        [Parameter()] [string]$ExcludedFoldersLoad,
        [Parameter()] [switch]$ExcludedFoldersReplace,
        [Parameter()] [switch]$ExcludedFoldersShow,
        [Parameter()] [switch]$Preview,
        [Parameter()] [bool]$WhatIfPreference
    )

    return [pscustomobject]@{
        EffectiveExclusions = @()
        ArtistPaths         = @($Path)
        IsPreview           = $Preview -or $WhatIfPreference
    }
}

$script:ArtistProcessingCalls = @()
function Invoke-MuFoArtistProcessing {
    param(
        [Parameter(Mandatory)] [string]$ArtistPath,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$EffectiveExclusions,
        [Parameter(Mandatory)] [ValidateSet('Automatic','Manual','Smart')] [string]$DoIt,
        [Parameter(Mandatory)] [double]$ConfidenceThreshold,
        [Parameter()] [string]$SpotifyAlbumId,
        [Parameter()] [switch]$IncludeSingles,
        [Parameter()] [switch]$IncludeCompilations,
        [Parameter()] [switch]$IncludeTracks,
        [Parameter()] [switch]$FixTags,
        [Parameter()] [string[]]$FixOnly,
        [Parameter()] [string[]]$DontFix,
        [Parameter()] [switch]$OptimizeClassicalTags,
        [Parameter()] [switch]$ValidateCompleteness,
        [Parameter()] [switch]$BoxMode,
        [Parameter()] [switch]$Preview,
        [Parameter()] [switch]$Detailed,
        [Parameter()] [switch]$ShowEverything,
        [Parameter()] [switch]$ValidateDurations,
        [Parameter()] [ValidateSet('Strict','Normal','Relaxed','DataDriven')] [string]$DurationValidationLevel = 'Normal',
        [Parameter()] [switch]$ShowDurationMismatches,
        [Parameter()] [string]$LogTo,
        [Parameter()] [string]$ExcludedFoldersSave,
        [Parameter()] [bool]$WhatIfPreference,
        [Parameter()] [System.Management.Automation.PSCmdlet]$CallerCmdlet
    )

    $script:ArtistProcessingCalls += [pscustomobject]@{
        ArtistPath       = $ArtistPath
        PreviewRequested = $Preview.IsPresent
        WhatIfPreference = $WhatIfPreference
    }

    return [pscustomobject]@{
        LocalArtist   = 'Test Artist (Spotify)'
        LocalFolder   = 'Old Album'
        SpotifyAlbum  = 'Forced Album'
        NewFolderName = 'New Album Name'
        Decision      = 'rename'
    }
}

$results = Invoke-MuFo -Path $testRoot -WhatIf -DoIt Automatic -ConfidenceThreshold 0.6
$resultsArray = @($results)

if ($script:ArtistProcessingCalls.Count -eq 1 -and $script:ArtistProcessingCalls[0].ArtistPath -eq $testRoot) {
    Write-Host "✓ Invoke-MuFoArtistProcessing invoked under -WhatIf" -ForegroundColor Green
} else {
    Write-Host "✗ Invoke-MuFoArtistProcessing was not called under -WhatIf" -ForegroundColor Red
}

if ($resultsArray.Count -eq 1 -and $resultsArray[0].Decision -eq 'rename') {
    Write-Host "✓ Invoke-MuFo emitted preview result during -WhatIf" -ForegroundColor Green
} else {
    Write-Host "✗ Invoke-MuFo did not emit expected preview result" -ForegroundColor Red
}

if (Test-Path $testRoot) {
    Remove-Item -Path $testRoot -Recurse -Force
}

Write-Host "=== Invoke-MuFo -WhatIf preview test complete ===" -ForegroundColor Cyan