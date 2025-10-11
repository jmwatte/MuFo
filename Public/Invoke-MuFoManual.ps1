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
        # Helper function to normalize Discogs IDs (strip brackets, resolve masters)
        $normalizeDiscogsId = {
            param([string]$InputId)
            
            $id = $InputId.Trim()
            
            # Remove brackets if present: [r2388472] → r2388472, [m1764178] → m1764178
            $id = $id -replace '^\[|\]$', ''
            
            # Check if it's a master release (m prefix)
            if ($id -match '^m(\d+)$') {
                Write-Host "Detected Discogs master release: $id" -ForegroundColor Yellow
                Write-Host "Fetching master to resolve main release..." -ForegroundColor Cyan
                try {
                    $masterId = $matches[1]
                    $master = Invoke-DiscogsRequest -Uri "/masters/$masterId"
                    if ($master -and $master.main_release) {
                        $id = [string]$master.main_release
                        Write-Host "✓ Resolved to main release: $id" -ForegroundColor Green
                    } else {
                        Write-Warning "Could not resolve master $masterId to main release, using master ID"
                        $id = $masterId
                    }
                } catch {
                    Write-Warning "Failed to fetch master release: $_"
                    $id = $masterId
                }
            }
            # Strip 'r' prefix if present: r2388472 → 2388472
            elseif ($id -match '^r(\d+)$') {
                $id = $matches[1]
            }
            
            return $id
        }
        
        $artist = Split-Path -Leaf $Path
        $albums = Get-ChildItem -LiteralPath $Path -Directory
        foreach ($album in $albums) {
            # Initialize album artist override for this album
            $script:ManualAlbumArtist = $null
            
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
            while ($true) {
                switch ($stage) {
                    
                    "A" {
                        Clear-Host
                        Write-Host "Original Artist: $artist" -ForegroundColor Cyan
                        Write-Host ""
                        try { $r = Invoke-ProviderSearch -Provider $Provider -query $artistQuery -Type artist } catch { Write-Warning "Search failed: $_"; $r = $null }
                        $candidates = @()
                        if ($value = Get-IfExists $r.artists "items") { $candidates = $value }
                        #if ($r -and $r.artists -and $r.artists.items) { $candidates = $r.artists.items }
                        # Normalize to array so .Count is available even for single-item responses
                        $candidates = @($candidates)
    
                        if (-not $candidates -or $candidates.Count -eq 0) {
                            Write-Host "No artist candidates found for '$artistQuery'."
                            if ($NonInteractive) {
                                Write-Warning "NonInteractive: skipping album because no artist candidates were found for '$artistQuery'."
                                break
                            }
                            $inputF = Read-Host "Enter new search, '(cp)' change provider, '(s)kip' to skip album, or 'id:<id>' to select by id"
                            switch -Regex ($inputF) {
                                '^s(kip)?$' { 
                                    break 
                                }
                                '^cp$' {
                                    Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                                    Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
                                    $newProvider = Read-Host "Enter new provider name"
                                    if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                                        $Provider = $newProvider
                                        Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                        continue
                                    } else {
                                        Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                        continue
                                    }
                                }
                                '^id:(.+)$' { 
                                    $id = $matches[1].Trim()
                                    if ($Provider -eq 'Discogs') { $id = & $normalizeDiscogsId $id }
                                    $ProviderArtist = @{ id = $id; name = $id }
                                    $stage = 'B'
                                    continue 
                                }
                                default {
                                    if ($inputF) { 
                                        $artistQuery = $inputF
                                        continue 
                                    } else { 
                                        continue 
                                    }
                                }
                            }
                        }
    
                        Write-Host "Artist candidates for '$artistQuery':"
                        for ($i = 0; $i -lt $candidates.Count; $i++) {
                            Write-Host "[$($i+1)] $($candidates[$i].name) - $($candidates[$i].genres -join ', ') (id: $($candidates[$i].id))"
                        }
    
                        # Non-interactive selection: prefer explicit ArtistId, then goA, then AutoSelect/NonInteractive
                        if ($ArtistId) {
                            $ProviderArtist = @{ id = $ArtistId; name = $ArtistId }
                            $stage = 'B'; continue
                        }
                        if ($goA) {
                            $ProviderArtist = $candidates[0]
                            $stage = 'B'; continue
                        }
                        if ($AutoSelect -or $NonInteractive) {
                            $ProviderArtist = $candidates[0]
                            $stage = 'B'; continue
                        }

                        $inputF = Read-Host "Select artist [1] (Enter=first), number, 'skip', 'id:<id>', '(cp)' change provider, or new search term:"
                        if ($inputF -eq '') { $ProviderArtist = $candidates[0]; $stage = 'B'; continue }
                        if ($inputF -like 'id:*') { 
                            $id = $inputF.Substring(3)
                            if ($Provider -eq 'Discogs') { $id = & $normalizeDiscogsId $id }
                            $ProviderArtist = @{ id = $id; name = $id }; $stage = 'B'; continue 
                        }
                        if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $candidates.Count) { $ProviderArtist = $candidates[$idx - 1]; $stage = 'B'; continue } else { Write-Warning "Invalid"; continue } }
                        if ($inputF -eq 'skip') { break }
                        if ($inputF -eq 'cp') {
                            Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                            Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
                            $newProvider = Read-Host "Enter new provider name"
                            if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                                $Provider = $newProvider
                                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                continue
                            } else {
                                Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                continue
                            }
                        }
                        $artistQuery = $inputF; continue
                    }
    
                    "B" {
                        # Stage B: Album selection
                        $stageBResult = Invoke-StageB-AlbumSelection `
                            -Provider $Provider `
                            -ProviderArtist $ProviderArtist `
                            -AlbumName $albumName `
                            -Year $year `
                            -CachedAlbums $cachedAlbums `
                            -CachedArtistId $cachedArtistId `
                            -NormalizeDiscogsId $normalizeDiscogsId `
                            -Artist $artist `
                            -NonInteractive:$NonInteractive `
                            -AutoSelect:$AutoSelect `
                            -AlbumId $albumId `
                            -GoB:$goB
                        
                        # Handle results
                        $stage = $stageBResult.NextStage
                        $ProviderAlbum = $stageBResult.SelectedAlbum
                        $cachedAlbums = $stageBResult.UpdatedCache
                        $cachedArtistId = $stageBResult.UpdatedCachedArtistId
                        
                        # Handle provider changes
                        if ($stageBResult.UpdatedProvider -and $stageBResult.UpdatedProvider -ne $Provider) {
                            $Provider = $stageBResult.UpdatedProvider
                        }
                        
                        # Handle new artist query from Stage B (if provided)
                        if ($stageBResult.ContainsKey('NewArtistQuery') -and $stageBResult.NewArtistQuery) {
                            $artistQuery = $stageBResult.NewArtistQuery
                        }
                        
                        # Handle skip action (break out of stage loop)
                        if ($stage -eq 'Skip') {
                            break
                        }
                        
                        continue
                    }
                    "C" {
                        Clear-Host
                        if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                        
                        # Display appropriate header for single or combined albums
                        if (Get-IfExists $ProviderAlbum '_isCombined') {
                            Write-Host "Processing COMBINED album set:" -ForegroundColor Yellow
                            Write-Host "  Albums: $($ProviderAlbum._albumCount)" -ForegroundColor Cyan
                            Write-Host "  Tracks: $($ProviderAlbum._tracks.Count)" -ForegroundColor Cyan
                            foreach ($albumName in $ProviderAlbum._albumNames) {
                                Write-Host "    - $albumName" -ForegroundColor Gray
                            }
                            Write-Host ""
                        } else {
                            Write-Host "Searching tracks for album: $($ProviderAlbum.name) (id: $($ProviderAlbum.id))"
                        }
                        
                        # If the caller asked for non-interactive behavior, do not try to drive the
                        # interactive track-selection UI. This prevents Read-Host from blocking the
                        # process in unattended runs. The caller can run interactively to inspect and
                        # approve mappings, or add a future explicit flag to auto-apply changes.
                        if ($NonInteractive) {
                            Write-Warning "NonInteractive: skipping interactive track selection for album '$($ProviderAlbum.name)'."
                            # break out of the switch AND the enclosing stage while-loop to continue with next album
                            break 2
                        }
                        # collect audio files and tags
                        $audioFiles = Get-ChildItem -LiteralPath $album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                        $audioFiles = foreach ($f in $audioFiles) {
                            try {
                                $tagFile = [TagLib.File]::Create($f.FullName)
                                [PSCustomObject]@{
                                    FilePath    = $f.FullName
                                    DiscNumber  = $tagFile.Tag.Disc
                                    TrackNumber = $tagFile.Tag.Track
                                    Title       = $tagFile.Tag.Title
                                    TagFile     = $tagFile
                                    Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                    Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                    Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                    Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                                }
                            }
                            catch {
                                Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                continue
                            }
                        }
    
                        # Check if this is a combined album (tracks already fetched) or single album (need to fetch)
                        if (Get-IfExists $ProviderAlbum '_isCombined') {
                            Write-Verbose "Using pre-fetched tracks from combined album"
                            $tracksForAlbum = $ProviderAlbum._tracks
                        } else {
                            # For Discogs: if album is a master, resolve to main_release before fetching tracks
                            $albumIdToFetch = $ProviderAlbum.id
                            if ($Provider -eq 'Discogs' -and (Get-IfExists $ProviderAlbum 'type') -eq 'master') {
                                Write-Verbose "Album is a Discogs master (id: $albumIdToFetch), resolving to main_release..."
                                try {
                                    $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$albumIdToFetch"
                                    if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                                        $albumIdToFetch = [string]$masterDetails.main_release
                                        Write-Verbose "Resolved master to main_release: $albumIdToFetch"
                                        Write-Host "  ℹ️  Resolved master $($ProviderAlbum.id) → release $albumIdToFetch" -ForegroundColor Gray
                                    } else {
                                        Write-Warning "Master $albumIdToFetch has no main_release, using master ID"
                                    }
                                } catch {
                                    Write-Warning "Failed to resolve master to main_release: $_"
                                }
                            }
                            
                            try { 
                                $tracksForAlbum = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $albumIdToFetch
                            } catch { 
                                Write-Warning "Get-AlbumTracks failed: $_"
                                $tracksForAlbum = @() 
                            }
                        }
                        
                        # Auto-prompt for ambiguous album artist (classical music with multiple artists)
                        if (-not $NonInteractive -and $tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                            $isAmbiguous = Test-AlbumArtistAmbiguity -Artist $ProviderArtist -Album $ProviderAlbum -Tracks $tracksForAlbum
                            if ($isAmbiguous) {
                                Write-Host "`n⚠️  This classical album has ambiguous album artist assignment." -ForegroundColor Yellow
                                # Try different property names for album artist across providers
                                $currentAlbumArtist = Get-IfExists $ProviderAlbum 'album_artist'
                                if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderAlbum 'artist' }
                                if (-not $currentAlbumArtist -and $ProviderArtist) { $currentAlbumArtist = Get-IfExists $ProviderArtist 'name' }
                                if ($currentAlbumArtist) {
                                    Write-Host "   Album artist from API: $currentAlbumArtist" -ForegroundColor Gray
                                }
                                Write-Host "   Multiple artists found in tracks" -ForegroundColor Gray
                                Write-Host ""
                                $response = Read-Host "Press 'a' to build custom album artist, or Enter to use automatic detection"
                                if ($response -eq 'a') {
                                    $script:ManualAlbumArtist = Invoke-AlbumArtistBuilder -Tracks $tracksForAlbum
                                    if ($script:ManualAlbumArtist) {
                                        Write-Host "✓ Album artist set to: $script:ManualAlbumArtist" -ForegroundColor Green
                                    } else {
                                        Write-Host "Skipped - will use automatic detection" -ForegroundColor Gray
                                    }
                                    Write-Host ""
                                }
                            }
                        }
                        
                        # Normalize to array and defensively map properties (different providers may return different shapes)
                        <#   $tracksForAlbum = @($tracksForAlbum) | ForEach-Object {
                            # Defensive handling: some providers or earlier pipeline steps can emit ErrorRecord
                            # or Exception objects into the collection. Handle those explicitly so we don't
                            # accidentally use exception text as a track title (which caused the 'artists'
                            # missing-property messages to appear as Titles).
                            if ($_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Exception]) {
                                $errMsg = $_.ToString()
                                Write-Verbose "Skipping provider error object while mapping tracks: $errMsg"
                                [PSCustomObject]@{
                                    Id = $null
                                    Title = "[provider error] $errMsg"
                                    name = "[provider error] $errMsg"
                                    DiscNumber = 0
                                    TrackNumber = 0
                                    Duration = 0
                                    Artist = $null
                                    artists = @()
                                    FilePath = $null
                                    _RawProviderObject = $_
                                }
                                continue
                            }

                            try {
                                $artistName = $null
                                if ($_.PSObject.Properties.Match('artists')) {
                                    # artists might be an object with 'name' or an array; handle common shapes
                                    $a = $_.artists
                                    if ($a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) {
                                        $first = @($a) | Select-Object -First 1
                                        if ($first -and $first.name) { $artistName = $first.name }
                                    } else {
                                        if ($a -and $a.name) { $artistName = $a.name }
                                    }
                                } elseif ($_.PSObject.Properties.Match('artist')) {
                                    $artistName = $_.artist
                                }

                                # Normalize into a shape that satisfies existing code paths:
                                # - Title and name (some providers use 'name')
                                # - Artist (string) and artists (array of objects with .name) for compatibility
                                $titleVal = if ($_.PSObject.Properties.Match('name')) { $_.name } elseif ($_.PSObject.Properties.Match('title')) { $_.title } else { $_.ToString() }
                                $discVal = if ($_.PSObject.Properties.Match('disc_number')) { $_.disc_number } elseif ($_.PSObject.Properties.Match('discNumber')) { $_.discNumber } else { 0 }
                                $trackVal = if ($_.PSObject.Properties.Match('track_number')) { $_.track_number } elseif ($_.PSObject.Properties.Match('trackNumber')) { $_.trackNumber } else { 0 }
                                $durationVal = if ($_.PSObject.Properties.Match('duration_ms')) { $_.duration_ms } elseif ($_.PSObject.Properties.Match('durationMs')) { $_.durationMs } else { 0 }

                                # Build a defensive 'artists' array (objects with .name) when we only resolved a string
                                $artistsArray = @()
                                if ($_.PSObject.Properties.Match('artists')) {
                                    $rawA = $_.artists
                                    if ($rawA -is [System.Collections.IEnumerable] -and -not ($rawA -is [string])) {
                                        foreach ($it in @($rawA)) {
                                            if ($it -is [string]) { $artistsArray += [PSCustomObject]@{ name = $it } }
                                            elseif ($it.PSObject.Properties.Match('name')) { $artistsArray += [PSCustomObject]@{ name = $it.name } }
                                            else { $artistsArray += [PSCustomObject]@{ name = $it.ToString() } }
                                        }
                                    }
                                    else {
                                        if ($rawA -is [string]) { $artistsArray += [PSCustomObject]@{ name = $rawA } }
                                        elseif ($rawA.PSObject.Properties.Match('name')) { $artistsArray += [PSCustomObject]@{ name = $rawA.name } }
                                        else { $artistsArray += [PSCustomObject]@{ name = $rawA.ToString() } }
                                    }
                                }
                                elseif ($artistName) {
                                    $artistsArray += [PSCustomObject]@{ name = $artistName }
                                }

                                [PSCustomObject]@{
                                    Id          = ($_.PSObject.Properties.Match('id') ? $_.id : $null)
                                    Title       = $titleVal
                                    name        = $titleVal
                                    DiscNumber  = $discVal
                                    TrackNumber = $trackVal
                                    Duration    = $durationVal
                                    Artist      = $artistName
                                    artists     = $artistsArray
                                    FilePath    = $null
                                    _RawProviderObject = $_
                                }
                            }
                            catch {
                                $errText = $_.ToString()
                                Write-Verbose "Warning: unexpected track object shape while mapping (exception): $errText"
                                [PSCustomObject]@{
                                    Id = $null
                                    Title = "[mapping error] $errText"
                                    name = "[mapping error] $errText"
                                    DiscNumber = 0
                                    TrackNumber = 0
                                    Duration = 0
                                    Artist = $null
                                    artists = @()
                                    FilePath = $null
                                    _MappingException = $_
                                }
                            }
                        } #>
    
                        # Prefer sorting by disc/track when provider supplied disc numbers, otherwise keep name-sorting
                        $hasDiscNumbers = $false
                        try {
                            if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                                $hasDiscNumbers = ($tracksForAlbum | Where-Object { ($_.PSObject.Properties.Match('disc_Number') -and $_.disc_Number -gt 0) -or ($_.PSObject.Properties.Match('disc_number') -and $_.disc_number -gt 0) }).Count -gt 0
                            }
                        }
                        catch { $hasDiscNumbers = $false }
                        $sortMethod = if ($hasDiscNumbers) { 'byTrackNumber' } else { 'byName' }

                        # Debug: when verbose, print the raw provider track list so users can verify
                        # that disc numbers were parsed and normalized (helps compare with test output)
                        try {
                            if ($PSBoundParameters.ContainsKey('Verbose')) {
                                Write-Host "\n[DEBUG] Provider tracks for album: $($ProviderAlbum.name) (count: $($tracksForAlbum.Count))" -ForegroundColor Cyan
                                $tracksForAlbum | Select-Object id, name, disc_number, track_number | Format-Table -AutoSize
                            }
                        }
                        catch {
                            Write-Verbose "Failed to print debug provider tracks: $($_.Exception.Message)"
                        }
                        $exitdo = $false
                        $pairedTracks = $null
                        $refreshTracks = $true
                        $goCDisplayShown = $false
                        :doTracks do {
                            if ($refreshTracks -or -not $pairedTracks) {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $param = @{
                                    SortMethod    = $sortMethod
                                    AudioFiles    = $audioFiles
                                    SpotifyTracks = $tracksForAlbum
                                }
                                if ($reverseSource) { $param.Reverse = $true }
                                $pairedTracks = Set-Tracks @param
                                $refreshTracks = $false

                                if ($goC -and -not $goCDisplayShown) {
                                    $autoReader = { param($prompt) 'q' }
                                    $autoShowParams = @{
                                        PairedTracks  = $pairedTracks
                                        AlbumName     = $ProviderAlbum.name
                                        SpotifyArtist = $ProviderArtist
                                    }
                                    if ($reverseSource) { $autoShowParams.Reverse = $true }
                                    Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                                    $goCDisplayShown = $true
                                }
                            }

                            if ($goC) {
                                Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
                                $inputF = 'sa'
                            }
                            else {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $whatIfStatus = if ($useWhatIf) { "ON" } else { "OFF" }
                                $optionsLine = "`nOptions:SortByTit(l)e,(d)uration,(t)rackNumber,(n)ame,(h)ybrid,(m)anual,(r)everse,(s)ave Tags(st),(sf)older,(sa)ll,(aa)lbumArtist,(b)ack,(cp) change provider,(w)hatif $whatIfStatus (s)kip"
                                $commandList = @('d','t','n','l','h','m','r','st','sf','sa','aa','b','cp','w','whatif','s')
                                $paramshow = @{
                                    PairedTracks   = $pairedTracks
                                    AlbumName      = $ProviderAlbum.name
                                    SpotifyArtist  = $ProviderArtist
                                    OptionsText    = $optionsLine
                                    ValidCommands  = $commandList
                                    PromptColor    = $HostColor
                                    ProviderName   = $Provider
                                }
                                if ($reverseSource) { $paramshow.Reverse = $true }
                                
                                $inputF = Show-Tracks @paramshow

                                if ($null -eq $inputF) { continue }
                                if ($inputF -eq 'q') {
                                    Write-Host $optionsLine -ForegroundColor $HostColor
                                    $inputF = Read-Host "Select tracks or command"
                                }
                            }

                            switch -Regex ($inputF) {
                                '^d$' { $sortMethod = 'byDuration'; $refreshTracks = $true; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; $refreshTracks = $true; continue }
                                '^n$' { $sortMethod = 'byName'; $refreshTracks = $true; continue }
                                '^l$' { $sortMethod = 'byTitle'; $refreshTracks = $true; continue }
                                '^h$' { $sortMethod = 'Hybrid'; $refreshTracks = $true; continue }
                                '^m$' { $sortMethod = 'Manual'; $refreshTracks = $true; continue }
                                '^r$' { $ReverseSource = -not $ReverseSource; $refreshTracks = $true; continue }
                                '^aa$' {
                                    # Manual album artist builder
                                    if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                                        $script:ManualAlbumArtist = Invoke-AlbumArtistBuilder -Tracks $tracksForAlbum
                                        if ($script:ManualAlbumArtist) {
                                            Write-Host "`n✓ Album artist set to: $script:ManualAlbumArtist" -ForegroundColor Green
                                            $refreshTracks = $true
                                        } else {
                                            Write-Host "`nSkipped - album artist unchanged" -ForegroundColor Gray
                                        }
                                    } else {
                                        Write-Warning "No tracks available for album artist builder"
                                    }
                                    continue
                                }
                                '^b$' { 
                                    $script:ManualAlbumArtist = $null
                                    $stage = 'B'
                                    $exitdo = $true
                                    break 
                                }
                                '^cp$' {
                                    Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                                    Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
                                    $newProvider = Read-Host "Enter new provider name"
                                    if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                                        $Provider = $newProvider
                                        Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                        $cachedAlbums = $null
                                        $cachedArtistId = $null
                                        $stage = 'A'
                                        $exitdo = $true
                                        break
                                    } else {
                                        Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                        continue
                                    }
                                }
                                '^whatif$|^w$' {
                                    $useWhatIf = -not $useWhatIf
                                    $refreshTracks = $true
                                    continue
                                }
                                '^s$' { break 3 }
                                '^sf$' {
                                    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment (Get-IfExists $ProviderArtist 'name') -Replacement '_' -CollapseRepeating -Transliterate
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
                                    # call Move-AlbumFolder and pass -WhatIf from the caller (if requested)
                                    $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$useWhatIf
    
                                    if ($moveResult -and $moveResult.Success) {
                                        # If the move would not change the path, don't prompt or attempt to re-open.
                                        if ($useWhatIf) {
                                            Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                                            Write-Host -NoNewline -ForegroundColor Green "Old: "
                                            Write-Host $oldpath
                                            Write-Host -NoNewline -ForegroundColor Green "New: "
                                            Write-Host $moveResult.NewAlbumPath
                                            if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $goC) -and -not $useWhatIf) {
                                                # Only pause for an explicit interactive run. In preview/WhatIf or when
                                                # NonInteractive/goC is set, skip the blocking prompt so unattended
                                                # runs don't hang.
                                                Read-Host -Prompt "Press Enter to continue"
                                            }
                                            else {
                                                Write-Verbose "NonInteractive/goC/WhatIf or no-path-change: skipping pause after move."
                                            }
                                            $stage = 'C'
                                            $exitDo = $true
                                            break
                                        }
                                        else {
                                            # If the new path is identical to the current one, avoid reloading
                                            if ($moveResult.NewAlbumPath -eq $oldpath) {
                                                Write-Verbose "Move result indicates no change to album path; continuing."
                                                $stage = 'C'
                                                $exitDo = $true
                                                break
                                            }
                                            $album = Get-Item -LiteralPath $moveResult.NewAlbumPath
                                            $stage = "C"
                                            $exitDo = $true
                                            break 
                                        }
                                    }
                                    else {
                                        Write-Warning "Move failed or was skipped. Move result: $moveResult"
                                    }
                                }
                                '^st\s+(?<range>.+)$' {
                                    if (-not $pairedTracks -or $pairedTracks.Count -eq 0) {
                                        Write-Warning "No track matches available to save."
                                        continue doTracks
                                    }

                                    $rangeText = $matches['range'].Trim()
                                    if (-not $rangeText) {
                                        Write-Warning "No track numbers provided for 'st' command."
                                        continue doTracks
                                    }

                                    try {
                                        $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $pairedTracks.Count
                                    }
                                    catch {
                                        Write-Warning "Invalid track selection: $($_.Exception.Message)"
                                        continue doTracks
                                    }

                                    if (-not $selectedIndices -or $selectedIndices.Count -eq 0) {
                                        Write-Warning "No valid track numbers found in selection."
                                        continue doTracks
                                    }

                                    try {
                                        $saveResult = Save-MuFoTrackSelection -PairedTracks $pairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$useWhatIf
                                    }
                                    catch {
                                        Write-Warning "Failed to save selected tracks: $($_.Exception.Message)"
                                        continue doTracks
                                    }

                                    foreach ($info in $saveResult.SavedDetails) {
                                        $tags = $info.Tags
                                        $filePath = $info.FilePath
                                        $fileName = Split-Path -Leaf $filePath
                                        Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f $fileName, $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green
                                    }

                                    foreach ($info in $saveResult.Skipped) {
                                        $reasonText = switch ($info.Reason) {
                                            'NoAudio' { 'no matching audio file' }
                                            default { $info.Reason }
                                        }
                                        Write-Warning ("Skipping track {0}: {1}" -f $info.Index, $reasonText)
                                    }

                                    foreach ($info in $saveResult.Failed) {
                                        $reasonText = if ($info.Reason) { $info.Reason } else { 'unknown error' }
                                        Write-Warning ("Failed to save track {0}: {1}" -f $info.Index, $reasonText)
                                    }

                                    $pairedTracks = $saveResult.UpdatedPairs
                                    $audioFiles = $saveResult.UpdatedAudioFiles
                                    $tracksForAlbum = $saveResult.UpdatedSpotifyTracks

                                    if ($saveResult.SavedDetails.Count -gt 0) {
                                        Write-Host ("✓ Processed {0} track(s). Remaining: {1}" -f $saveResult.SavedDetails.Count, $pairedTracks.Count) -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host "No tracks were updated." -ForegroundColor Yellow
                                    }

                                    $refreshTracks = $false
                                    continue doTracks
                                }
                                '^st$' {
                                    try {


                                        foreach ($pair in $pairedTracks) {
                                            if ($null -ne $pair.AudioFile) {
                                                $filePath = $pair.AudioFile.FilePath
                                                $tagsParams = @{
                                                    Artist = $ProviderArtist
                                                    Album = $ProviderAlbum
                                                    SpotifyTrack = $pair.SpotifyTrack
                                                }
                                                if ($script:ManualAlbumArtist) {
                                                    $tagsParams['ManualAlbumArtist'] = $script:ManualAlbumArtist
                                                }
                                                $tags = Get-Tags @tagsParams
                                                Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                                Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                                $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
                                                if ($res.Success) { 
                                                    Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green 
                                                }
                                                else { 
                                                    Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) 
                                                }
                                            }
                                            else {
                                                Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.SpotifyTrack.name)
                                            }
                                        }
                                       
                                        <# for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                            $audioFile = $audioFiles[$i]
                                            $filePath = $audioFile.FilePath
                                            $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $tracksForAlbum[$i]                        
                                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                            if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green }
                                            else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
                                        } #>
                                        
                                        # Dispose old TagFile handles and reload to show updated tags
                                        if (-not $useWhatIf) {
                                            foreach ($af in $audioFiles) {
                                                if ($af.TagFile) {
                                                    try { $af.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile: $_" }
                                                    $af.TagFile = $null
                                                }
                                            }
                                            # Reload audio files with fresh TagLib handles
                                            $audioFiles = Get-ChildItem -LiteralPath $album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                                            $audioFiles = foreach ($f in $audioFiles) {
                                                try {
                                                    $tagFile = [TagLib.File]::Create($f.FullName)
                                                    [PSCustomObject]@{
                                                        FilePath    = $f.FullName
                                                        DiscNumber  = $tagFile.Tag.Disc
                                                        TrackNumber = $tagFile.Tag.Track
                                                        Title       = $tagFile.Tag.Title
                                                        TagFile     = $tagFile
                                                        Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                                        Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                                        Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                                        Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                                                    }
                                                }
                                                catch {
                                                    Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                                    continue
                                                }
                                            }
                                            $refreshTracks = $true
                                        }
                                        $stage = 'C'
                                        $exitDo = $true
                                        break
                                    }
                                    catch {
                                        Write-Host '---- ERROR in save-tags (st) handler ----' -ForegroundColor Red
                                        Write-Host "Message: $($_.Exception.Message)"
                                        Write-Host "Exception: $($_ | Out-String)"
                                        Write-Host "ScriptStackTrace: $($_.ScriptStackTrace)"
                                        # keep UI alive; set stage to C so outer loop continues
                                        $stage = 'C'
                                        $exitDo = $true
                                        break
                                    }
                                }
                                '^sa$' {




                                    foreach ($pair in $pairedTracks) {
                                        if ($null -ne $pair.AudioFile) {
                                            $filePath = $pair.AudioFile.FilePath
                                            $tagsParams = @{
                                                Artist = $ProviderArtist
                                                Album = $ProviderAlbum
                                                SpotifyTrack = $pair.SpotifyTrack
                                            }
                                            if ($script:ManualAlbumArtist) {
                                                $tagsParams['ManualAlbumArtist'] = $script:ManualAlbumArtist
                                            }
                                            $tags = Get-Tags @tagsParams
                                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
                                            if ($res.Success) { 
                                                Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green 
                                            }
                                            else { 
                                                Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) 
                                            }
                                        }
                                        else {
                                            Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.SpotifyTrack.name)
                                        }
                                    }
                                    <#  for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                        $audioFile = $audioFiles[$i]
                                        $filePath = $audioFile.FilePath

                                        $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $tracksForAlbum[$i]
                                     

                                        Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                        Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                        if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green }
                                        else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
                                    }
 #>




                                    <# for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                        $spotifyTrack = $tracksForAlbum[$i]
                                        $audioFile = $audioFiles[$i]
                                        $filePath = $audioFile.FilePath

                                        # Safe property access for genre across all providers
                                        $albumGenre = Get-IfExists $ProviderAlbum 'genre'
                                        $artistGenre = Get-IfExists $ProviderArtist 'genre'
                                        $genreTag = if ($null -ne $albumGenre) { $albumGenre -join '; ' } else { $artistGenre -join '; ' }
                                        
                                        $tags = @{
                                            Title       = $spotifyTrack.Title
                                            Track       = $spotifyTrack.TrackNumber
                                            Disc        = $spotifyTrack.DiscNumber
                                            Performers  = $spotifyTrack.artists.name -join '; '
                                            Genres      = $genreTag
                                            AlbumArtist = Get-IfExists $ProviderArtist 'name'
                                            Date        = $year
                                            Album       = Get-IfExists $ProviderAlbum 'name'
                                        }
                                        #if there is a $spotifyTrack.composer, add that to the $tags
                                        if ($spotifyTrack.composer) {
                                            $tags.Composer = $spotifyTrack.composer -join '; '
                                        }
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                        if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $spotifyTrack.DiscNumber, $spotifyTrack.TrackNumber, $spotifyTrack.Title) -ForegroundColor Green }
                                        else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
                                    } #>
    
                                    # dispose any lingering TagFile handles only when actually applying changes (not in -WhatIf)
                                    if (-not $useWhatIf) {
                                        foreach ($a in $audioFiles) {
                                            if ($a.TagFile) {
                                                try { $a.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($a.FilePath): $_" }
                                                $a.TagFile = $null
                                            }
                                        }
                                        # NOTE: Audio files will be reloaded AFTER the folder move (if move happens)
                                    }
                                    else {
                                        # In preview mode keep TagFile open so UI can continue to inspect tags.
                                        Write-Verbose "Preview: keeping TagFile handles open so interactive UI can display tags."
                                    }
                                    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment (Get-IfExists $ProviderArtist 'name') -Replacement '_' -CollapseRepeating -Transliterate
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
    
                                    $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$useWhatIf

                                    if ($moveResult -and $moveResult.Success) {
                                        if ($useWhatIf) {
                                            Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                                            Write-Host -NoNewline -ForegroundColor Green "Old: "
                                            Write-Host $oldpath
                                            Write-Host -NoNewline -ForegroundColor Green "New: "
                                            Write-Host $moveResult.NewAlbumPath
                                            if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $goC) -and -not $useWhatIf) {
                                                Read-Host -Prompt "Press Enter to continue"
                                            }
                                            else {
                                                Write-Verbose "NonInteractive/goC/WhatIf or no-path-change: skipping pause after move."
                                            }
                                            Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                                            continue
                                        }
                                        else {
                                            if ($moveResult.NewAlbumPath -eq $oldpath) {
                                                Write-Verbose "Move result indicates no change to album path; continuing."
                                                Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                                                continue
                                            }
                                            # Folder was moved - update $album and reload audio files from new location
                                            $album = Get-Item -LiteralPath $moveResult.NewAlbumPath
                                            
                                            # Reload audio files with fresh TagLib handles from the NEW album path
                                            $audioFiles = Get-ChildItem -LiteralPath $album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                                            $audioFiles = foreach ($f in $audioFiles) {
                                                try {
                                                    $tagFile = [TagLib.File]::Create($f.FullName)
                                                    [PSCustomObject]@{
                                                        FilePath    = $f.FullName
                                                        DiscNumber  = $tagFile.Tag.Disc
                                                        TrackNumber = $tagFile.Tag.Track
                                                        Title       = $tagFile.Tag.Title
                                                        TagFile     = $tagFile
                                                        Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                                        Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                                        Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                                        Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                                                    }
                                                }
                                                catch {
                                                    Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                                    continue
                                                }
                                            }
                                            $refreshTracks = $true
                                            Write-Host "Album saved and folder moved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                                            continue 
                                        }
                                    }
                                    else {
                                        Write-Warning "Move failed or was skipped. Move result: $moveResult"
                                    }
                                }
    
                                '^(\d+(?:\.\.\d+|\-\d+)) (\+?\w+) (.+)$' {
                                    # Parse range, tag, and value from input (e.g., "1..8 +composer J.S. Bach")
                                    if ($tracksForAlbum.Count -eq 0) {
                                        Write-Warning "No tracks available for tagging"
                                        continue
                                    }
                                    if ($audioFiles.Count -eq 0) {
                                        Write-Warning "No audio files available for tagging"
                                        continue
                                    }
                                    $maxIndex = [math]::Min($tracksForAlbum.Count, $audioFiles.Count)
                                    $rangeStr = $matches[1]
                                    $tagName = $matches[2]
                                    $tagValue = $matches[3]
    
                                    # Expand range to array of 1-based indices (e.g., "1..8" -> @(1,2,3,4,5,6,7,8))
                                    $indices = @()
                                    if ($rangeStr -match '^(\d+)\.\.(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        $end = [math]::Min($end, $maxIndex)
                                        if ($start -le $end -and $start -ge 1) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^(\d+)\-(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        $end = [math]::Min($end, $maxIndex)
                                        if ($start -le $end -and $start -ge 1) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^\d+$') {
                                        $idx = [int]$rangeStr
                                        if ($idx -ge 1 -and $idx -le $maxIndex) {
                                            $indices = @($idx)
                                        }
                                        else {
                                            Write-Warning "Invalid track number: $idx (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    else {
                                        Write-Warning "Unrecognized range format: $rangeStr"
                                        continue
                                    }
    
                                    # Determine if adding (+) or replacing
                                    $isAdd = $tagName.StartsWith('+')
                                    $actualTagName = if ($isAdd) { $tagName.Substring(1) } else { $tagName }
    
                                    # Validate tag name (add more as needed; map to TagLib properties)
                                    $validTags = @('composer', 'genre', 'artist', 'albumartist', 'title')  # Expand this list
                                    if ($actualTagName -notin $validTags) {
                                        Write-Warning "Unsupported tag: $actualTagName (supported: $($validTags -join ', '))"
                                        continue
                                    }
    
                                    # Apply to each track in range
                                    foreach ($idx in $indices) {
                                        $trackIdx = $idx - 1  # 0-based for arrays
                                        $spotifyTrack = $tracksForAlbum[$trackIdx]
                                        $audioFile = $audioFiles[$trackIdx]
                                        $filePath = $audioFile.FilePath
    
                                        # Build tag update (read existing value if adding)
                                        $existingValue = $null
                                        if ($isAdd) {
                                            # Try to read current tag value from the file (if available)
                                            try {
                                                $currentTagFile = [TagLib.File]::Create($filePath)
                                                $existingValue = switch ($actualTagName) {
                                                    'composer' { $currentTagFile.Tag.Composers -join '; ' }
                                                    'genre' { $currentTagFile.Tag.Genres -join '; ' }
                                                    'artist' { $currentTagFile.Tag.Performers -join '; ' }
                                                    'albumartist' { $currentTagFile.Tag.AlbumArtists -join '; ' }
                                                    'title' { $currentTagFile.Tag.Title }
                                                    default { $null }
                                                }
                                                $currentTagFile.Dispose()
                                            }
                                            catch {
                                                Write-Verbose "Could not read existing tag for $filePath`: $_"
                                            }
                                        }
    
                                        $newValue = if ($isAdd -and $existingValue) {
                                            "$existingValue; $tagValue"  # Append with separator
                                        }
                                        else {
                                            $tagValue  # Replace or set new
                                        }
    
                                        # Map to TagLib property names
                                        $tagKey = switch ($actualTagName) {
                                            'composer' { 'Composers' }
                                            'genre' { 'Genres' }
                                            'artist' { 'Performers' }
                                            'albumartist' { 'AlbumArtists' }
                                            'title' { 'Title' }
                                            default { $actualTagName }
                                        }
    
                                        $tags = @{
                                            $tagKey = $newValue
                                        }
    
                                        # Save the tag
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
                                        if ($res.Success) {
                                            Write-Host ("Updated tag '$actualTagName' for track $idx ($($spotifyTrack.Title)): '$newValue'") -ForegroundColor Green
                                        }
                                        else {
                                            Write-Warning ("Failed to update tag for track $($idx): $($res.Reason)")
                                        }
                                    }
    
                                    $stage = 'C'
                                    $exitDo = $true
                                    $albumDone = $true
                                    break 
                                }
    
                                default { Write-Warning "Unknown option"; continue }
                            }
                            if ($exitDo) { break }
                        } while ($true)
                    }
                }
                if ($albumDone) { break } else { continue }
            } # end foreach albums
        }
    }
    end {
        return [PSCustomObject]@{
            Path      = $Path
            Completed = $true
            WhatIf    = $useWhatIf
        }
    }
}


