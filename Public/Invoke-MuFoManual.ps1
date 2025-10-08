function Invoke-MuFoManual {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]  # Add more providers as needed
        [string]$Provider = 'Spotify',  # Default to Spotify for compatibility
        [Parameter(Mandatory = $false)]
        [string]$ArtistId,
        [Parameter(Mandatory = $false)]
        [string]$AlbumId,
        [Parameter(Mandatory = $false)]
        [switch]$AutoSelect,
        [Parameter(Mandatory = $false)]
        [switch]$NonInteractive,
        [Parameter(Mandatory = $false)]
        [switch]$goA,
        [Parameter(Mandatory = $false)]
        [switch]$goB,
        [Parameter(Mandatory = $false)]
        [switch]$goC,
        [Parameter(Mandatory = $false)]
        [switch]$ReverseSource

    )

    begin {
        $taglibloaded = Test-taglibloaded -ThrowOnError 
        if (-not $taglibloaded) {
            Install-TagLibSharp | Out-Null
        }
        # ensure TagLib is present for this function (Install-TagLibSharp should make TagLib available)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # detect whether the user passed -WhatIf to this function (comes from CmdletBinding)
        $isWhatIf = $PSBoundParameters.ContainsKey('WhatIf')

        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Path not found or not a directory: $Path"
        }

        # Ensure required external module Spotishell is present in the session
        if (-not (Get-Module -Name Spotishell)) {
            try { Import-Module Spotishell -ErrorAction Stop } catch { Write-Warning "Spotishell module not loaded: $_"; throw }
        }

        # Convert the switch into the debug-friendly object used by the helpers (optional)
        #   $whatIfObj = New-Object PSObject -Property @{ IsPresent = $isWhatIf }
    }

    # ... (begin block unchanged)
    
    process {
        $artist = Split-Path -Leaf $Path
        $albums = Get-ChildItem -LiteralPath $Path -Directory
        foreach ($album in $albums) {
            $useWhatIf = $isWhatIf
            if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
            # derive album name and year
                       # Try to extract year from the start of the folder name (e.g., "2023 - Album Name")
            if ($album.Name -match '^(\d{4})\s*[-]?\s*(.+)') {
                $year = $matches[1]
                $albumName = $matches[2].Trim()
            } else {
                $year = $null
                $albumName = $album.Name.Trim()
            }
            $artistQuery = $artist
            $stage = "A"
            $cachedAlbums = $null
            $cachedArtistId = $null
            $page = 1
            $pageSize = 25
            $albumDone = $false
            $mastersOnlyMode = $true  # Track Discogs filter state: true=masters only, false=all releases
            $ProviderArtist = $null
            while ($true) {
                $stageParams = @{
                    Provider = $Provider
                    ArtistQuery = $artistQuery
                    AlbumName = $albumName
                    Year = $year
                    ProviderArtist = $ProviderArtist
                    ProviderAlbum = $ProviderAlbum
                    CachedAlbums = $cachedAlbums
                    CachedArtistId = $cachedArtistId
                    Page = $page
                    MastersOnlyMode = $mastersOnlyMode
                    ReverseSource = $reverseSource
                    UseWhatIf = $useWhatIf
                    NonInteractive = $NonInteractive
                    GoA = $goA
                    GoB = $goB
                    GoC = $goC
                    ArtistId = $ArtistId
                    AlbumId = $AlbumId
                    Album = $album
                }

                $stageResult = switch ($stage) {
                    "A" { Invoke-MuFoStageA @stageParams }
                    "B" { Invoke-MuFoStageB @stageParams }
                    "C" { Invoke-MuFoStageC @stageParams }
                }

                # Update variables from stage result
                if ($stageResult.Provider) { $Provider = $stageResult.Provider }
                if ($stageResult.ProviderArtist) { $ProviderArtist = $stageResult.ProviderArtist }
                if ($stageResult.ProviderAlbum) { $ProviderAlbum = $stageResult.ProviderAlbum }
                if ($stageResult.CachedAlbums) { $cachedAlbums = $stageResult.CachedAlbums }
                if ($stageResult.CachedArtistId) { $cachedArtistId = $stageResult.CachedArtistId }
                if ($stageResult.Page) { $page = $stageResult.Page }
                if ($stageResult.MastersOnlyMode) { $mastersOnlyMode = $stageResult.MastersOnlyMode }

                # Handle stage progression based on action
                if ($stageResult.Action -eq 'ProviderChanged') {
                    $stage = 'A'  # Go back to Stage A when provider changes
                    $cachedAlbums = $null  # Clear cache when provider changes
                    $cachedArtistId = $null
                    continue
                } elseif ($stageResult.Action -eq 'Back') {
                    $stage = 'A'  # Go back to Stage A
                    continue
                } elseif ($stageResult.NextStage) {
                    $stage = $stageResult.NextStage
                } elseif ($stageResult.AlbumDone) {
                    break
                } else {
                    continue
                }
            } # end while
            if ($albumDone) { break } else { continue }
        } # end foreach albums
    } # end process

    end {
        return [PSCustomObject]@{
            Path      = $Path
            Completed = $true
            WhatIf    = $useWhatIf
        }
    }
} # end function

