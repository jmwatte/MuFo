function Get-MuFoProcessingContext {
    <#
    .SYNOPSIS
    Builds the reusable processing context needed by Invoke-MuFo.

    .DESCRIPTION
    Computes effective exclusions, optionally displays them, resolves the
    artist paths according to the selected mode, and returns a structured
    object that the main pipeline can iterate. The helper also determines
    whether the current invocation is running in preview mode.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Here','1U','2U','1D','2D')]
        [string]$ArtistAt,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeFolders,

        [Parameter(Mandatory = $false)]
        [string]$ExcludedFoldersLoad,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludedFoldersReplace,

        [Parameter(Mandatory = $false)]
        [switch]$ExcludedFoldersShow,

        [Parameter(Mandatory = $false)]
        [switch]$Preview,

        [Parameter(Mandatory = $false)]
        [bool]$WhatIfPreference
    )

    $isPreview = $Preview -or $WhatIfPreference

    $effectiveExclusions = Get-EffectiveExclusions -ExcludeFolders $ExcludeFolders -ExcludedFoldersLoad $ExcludedFoldersLoad -ExcludedFoldersReplace:$ExcludedFoldersReplace
    Write-Verbose "Final effective exclusions: $($effectiveExclusions -join ', ')"

    if ($ExcludedFoldersShow) {
        Show-Exclusions -EffectiveExclusions $effectiveExclusions -ExcludedFoldersLoad $ExcludedFoldersLoad
    }

    $artistPaths = switch ($ArtistAt) {
        'Here' { @($Path) }
        '1U' {
            $p = Split-Path $Path -Parent
            if (-not $p) {
                Write-Warning "Cannot go up from '$Path'"
                @()
            }
            else {
                @($p)
            }
        }
        '2U' {
            $p = $Path
            for ($i = 0; $i -lt 2; $i++) {
                $p = Split-Path $p -Parent
                if (-not $p) {
                    Write-Warning "Cannot go up $($i + 1) levels from '$Path'"
                    $p = $null
                    break
                }
            }
            if ($p) { @($p) } else { @() }
        }
        '1D' {
            Get-ChildItem -Directory $Path | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | Select-Object -ExpandProperty FullName
        }
        '2D' {
            Get-ChildItem -Directory $Path | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | ForEach-Object {
                Get-ChildItem -Directory $_.FullName | Where-Object { -not (Test-ExclusionMatch $_.Name $effectiveExclusions) } | Select-Object -ExpandProperty FullName
            }
        }
    }

    return [PSCustomObject]@{
        EffectiveExclusions = $effectiveExclusions
        ArtistPaths         = $artistPaths
        IsPreview           = $isPreview
    }
}
