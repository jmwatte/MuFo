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
            # Parse album name and year
            $albumInfo = Get-AlbumInfoFromFolder -Folder $album

            # Initialize state
            $state = @{
                Stage = 'A'
                ArtistQuery = $artist
                ProviderArtist = $null
                ProviderAlbum = $null
                CachedAlbums = $null
                CachedArtistId = $null
                Page = 1
                MastersOnlyMode = $true
                UseWhatIf = $isWhatIf
            }

            # State machine: A → B → C
            $albumDone = $false
            while (-not $albumDone) {
                switch ($state.Stage) {
                    'A' {
                        $result = Invoke-MuFoStageA `
                            -ArtistQuery $state.ArtistQuery `
                            -Provider $Provider `
                            -ArtistId $ArtistId `
                            -AutoSelect:$AutoSelect `
                            -NonInteractive:$NonInteractive `
                            -goA:$goA

                        switch ($result.Action) {
                            'Selected' {
                                $state.ProviderArtist = $result.Artist
                                $state.Stage = 'B'
                            }
                            'NewSearch' {
                                $state.ArtistQuery = $result.Query
                            }
                            'Skip' {
                                $albumDone = $true
                            }
                        }
                    }

                    'B' {
                        $result = Invoke-MuFoStageB `
                            -ProviderArtist $state.ProviderArtist `
                            -AlbumName $albumInfo.Name `
                            -Year $albumInfo.Year `
                            -Provider $Provider `
                            -AlbumId $AlbumId `
                            -CachedAlbums $state.CachedAlbums `
                            -MastersOnlyMode $state.MastersOnlyMode `
                            -Page $state.Page `
                            -AutoSelect:$AutoSelect `
                            -NonInteractive:$NonInteractive `
                            -goB:$goB

                        switch ($result.Action) {
                            'Selected' {
                                $state.ProviderAlbum = $result.Album
                                $state.CachedAlbums = $result.CachedAlbums
                                $state.MastersOnlyMode = $result.MastersOnlyMode
                                $state.Page = $result.Page
                                $state.Stage = 'C'
                            }
                            'Back' {
                                $state.Stage = 'A'
                                $state.CachedAlbums = $null
                                $state.CachedArtistId = $null
                            }
                            'ProviderChanged' {
                                $Provider = $result.Provider
                                $state.Stage = 'A'
                                $state.CachedAlbums = $null
                                $state.CachedArtistId = $null
                            }
                        }
                    }

                    'C' {
                        $result = Invoke-MuFoStageC `
                            -ProviderArtist $state.ProviderArtist `
                            -ProviderAlbum $state.ProviderAlbum `
                            -Provider $Provider `
                            -Album $album `
                            -NonInteractive:$NonInteractive `
                            -goC:$goC `
                            -UseWhatIf:$state.UseWhatIf `
                            -ReverseSource:$ReverseSource

                        switch ($result.Action) {
                            'Completed' {
                                $albumDone = $true
                                # Update album folder if moved
                                if ($result.AlbumFolder) {
                                    $album = $result.AlbumFolder
                                }
                            }
                            'Back' {
                                $state.Stage = 'B'
                            }
                            'Skip' {
                                $albumDone = $true
                            }
                        }
                    }
                }
            }
        }
    }

    end {
        return [PSCustomObject]@{
            Path      = $Path
            Completed = $true
            WhatIf    = $useWhatIf
        }
    }
} # end function

