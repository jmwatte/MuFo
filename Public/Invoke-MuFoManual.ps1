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
            while ($true) {
                switch ($stage) {
                    
                    "A" {
                        Clear-Host
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
                            $inputF = Read-Host "Enter new search, 'skip' to skip album, or 'id:<id>' to select by id"
                            if ($inputF -eq 'skip') { break }
                            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderArtist = @{ id = $id; name = $id }; $stage = 'B'; continue }
                            if ($inputF) { $artistQuery = $inputF; continue } else { continue }
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

                        $inputF = Read-Host "Select artist [1] (Enter=first), number, 'skip', 'id:<id>', or new search term:"
                        if ($inputF -eq '') { $ProviderArtist = $candidates[0]; $stage = 'B'; continue }
                        if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderArtist = @{ id = $id; name = $id }; $stage = 'B'; continue }
                        if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $candidates.Count) { $ProviderArtist = $candidates[$idx - 1]; $stage = 'B'; continue } else { Write-Warning "Invalid"; continue } }
                        if ($inputF -eq 'skip') { break }
                        $artistQuery = $inputF; continue
                    }
    
                    "B" {
                        Clear-Host
                        Write-Host "Searching for albums for artist: $($ProviderArtist.name) (id: $($ProviderArtist.id))"
                        
                        # Clear cache if artist changed
                        if ($cachedArtistId -ne $ProviderArtist.id) {
                            $cachedAlbums = $null
                            $cachedArtistId = $ProviderArtist.id
                        }
                        
                        # Try smart API search FIRST (fast, targeted results)
                        Write-Host "Searching for albums matching: $albumName..." -ForegroundColor Cyan
                        Write-Verbose "Trying smart search for: $albumName"
                        Write-Verbose "Parameters: Provider=$Provider, ArtistId=$($ProviderArtist.id), ArtistName=$($ProviderArtist.name), AlbumName=$albumName, MastersOnly=$($Provider -eq 'Discogs'), CacheProvided=$($null -ne $cachedAlbums)"
                        try { 
                            $albumsForArtist = Invoke-ProviderSearchAlbums `
                                -Provider $Provider `
                                -ArtistId $ProviderArtist.id `
                                -ArtistName $ProviderArtist.name `
                                -AlbumName $albumName `
                                -MastersOnly:($Provider -eq 'Discogs') `
                                -AllAlbumsCache $cachedAlbums
                            
                            $albumsForArtist = @($albumsForArtist)  # Ensure array
                            
                            Write-Verbose "Smart search returned: $($albumsForArtist.Count) albums"
                            if ($albumsForArtist.Count -gt 0) {
                                Write-Host "✓ Found $($albumsForArtist.Count) albums via smart search" -ForegroundColor Green
                            } else {
                                Write-Verbose "Smart search returned 0 albums - will fall back to fetching all"
                            }
                        } catch { 
                            Write-Warning "Smart search exception: $_"
                            Write-Verbose "Exception details: $($_.Exception.Message)"
                            $albumsForArtist = @() 
                        }
                        
                        # If smart search returned nothing, fetch all albums as fallback
                        if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                            if (-not $cachedAlbums) {
                                Write-Host "Smart search returned no results, fetching all albums (this may take a while)..." -ForegroundColor Yellow
                                Write-Verbose "Fetching all albums for artist..."
                                try { 
                                    $cachedAlbums = Invoke-ProviderGetAlbums -Provider $Provider -ArtistId $ProviderArtist.id -AlbumType 'Album'
                                    $cachedAlbums = @($cachedAlbums)  # Ensure array
                                    Write-Host "✓ Fetched $($cachedAlbums.Count) albums" -ForegroundColor Green
                                } catch { 
                                    Write-Warning "Failed to fetch artist albums: $_"
                                    $cachedAlbums = @() 
                                }
                            }
                            
                            Write-Verbose "Using all cached albums ($($cachedAlbums.Count) albums)"
                            $albumsForArtist = $cachedAlbums
                        }
                        # Normalize to array so .Count works reliably
                        $albumsForArtist = @($albumsForArtist)
                        if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                            Write-Host "No albums found for artist id $($ProviderArtist.id)."
                            if ($NonInteractive) {
                                Write-Warning "NonInteractive: skipping album because no albums found for artist id $($ProviderArtist.id)."
                                break
                            }
                        
                            $inputF = Read-Host "Enter '(b)ack', '(s)kip', 'id:<id>' or album name to filter"
                            switch -Regex ($inputF) {
                                '^b$' {
                                    $stage = 'A'; continue
                                }
                                '^s$' {
                                    break
                                }
                                '^id:.*' {
                                    $id = $inputF.Substring(3); $ProviderAlbum = @{ id = $id; name = $id }; $stage = 'C'; continue
                                }
                                default {
                                    if ($inputF) { $artistQuery = $inputF; $stage = 'A'; continue } else { continue }
                                }
                                # if ($inputF -ieq 'back') { $stage = 'A'; continue }
                                # if ($inputF -eq 'skip') { break }
                                #  if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderAlbum = @{ id = $id; name = $id }; $stage = 'C'; continue }
                                # if ($inputF) { $artistQuery = $inputF; $stage = 'A'; continue } else { continue }
                            }
                        }
                        Clear-Host
                        # sort by Jaccard similarity descending
                        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $albumName -String2 $_.Name) }

                        $exitdo = $false
                        while ($true) {
                            # Clear-Host
                            
                            # Show filter mode indicator for Discogs
                            if ($Provider -eq 'Discogs') {
                                $modeIndicator = if ($mastersOnlyMode) { 
                                    "[Filter: MASTERS ONLY - type '*' to include all releases]" 
                                } else { 
                                    "[Filter: ALL RELEASES - type '*' for masters only]" 
                                }
                                Write-Host $modeIndicator -ForegroundColor Yellow
                            }
                            
                            Write-Host "Albums for artist $($ProviderArtist.name):"
                            Write-Host "for local album: $($albumName) (year: $year)"
                            $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
                            $startIdx = ($page - 1) * $pageSize
                            $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)
    
                            for ($i = $startIdx; $i -le $endIdx; $i++) {
                                Write-Host "[$($i+1)] $($albumsForArtist[$i].name)  (id: $($albumsForArtist[$i].id)) (year: $($albumsForArtist[$i].release_date))"
                            }
    
                            # Non-interactive album selection: prefer explicit AlbumId, then goB, then AutoSelect or NonInteractive
                            if ($AlbumId) { $ProviderAlbum = @{ id = $AlbumId; name = $AlbumId }; $stage = 'C'; break }
                            if ($goB) { $ProviderAlbum = $albumsForArtist[0]; $stage = 'C'; break }
                            if ($AutoSelect -or $NonInteractive) { $ProviderAlbum = $albumsForArtist[0]; $stage = 'C'; break }

                            $inputF = Read-Host "Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), '(b)ack', '(n)ext', '(p)rev', '(s)kip', 'id:<id>', '*' (all albums), or text to search:"
                            
                            switch -Regex ($inputF) {
                                '^n$' {
                                    if ($page -lt $totalPages) { $page++ }
                                    continue
                                }
                                '^p$' {
                                    if ($page -gt 1) { $page-- }
                                    continue
                                }
                                '^b$' {
                                    $cachedAlbums = $null
                                    $cachedArtistId = $null
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^$' {
                                    $ProviderAlbum = $albumsForArtist[0]
                                    $exitdo = $true                                        
                                    $stage = 'C'
                                    break
                                }
                                '^id:(.+)$' {
                                    $id = $matches[1]
                                    $ProviderAlbum = @{ id = $id; name = $id }
                                    $exitdo = $true
                                    $stage = 'C'
                                    break
                                }
                                '^\*$' {
                                    # Toggle between Masters-only and All-releases for Discogs
                                    if ($Provider -eq 'Discogs') {
                                        $mastersOnlyMode = -not $mastersOnlyMode
                                        $modeText = if ($mastersOnlyMode) { "MASTER releases only" } else { "ALL release types" }
                                        Write-Host "`nToggling to: $modeText" -ForegroundColor Yellow
                                        Write-Host "Fetching albums..." -ForegroundColor Cyan
                                    } else {
                                        Write-Host "Fetching all albums for artist..." -ForegroundColor Cyan
                                    }
                                    
                                    try {
                                        $fetchParams = @{
                                            Provider = $Provider
                                            ArtistId = $ProviderArtist.id
                                            AlbumType = 'Album'
                                        }
                                        
                                        # Add MastersOnly parameter for Discogs
                                        if ($Provider -eq 'Discogs') {
                                            $fetchParams['MastersOnly'] = $mastersOnlyMode
                                        }
                                        
                                        $albumsForArtist = Invoke-ProviderGetAlbums @fetchParams
                                        $albumsForArtist = @($albumsForArtist)
                                        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $albumName -String2 $_.Name) }
                                        $cachedAlbums = $albumsForArtist
                                        $page = 1
                                        
                                        $statusMsg = if ($Provider -eq 'Discogs') {
                                            "✓ Loaded $($albumsForArtist.Count) albums [$modeText]"
                                        } else {
                                            "✓ Loaded $($albumsForArtist.Count) albums"
                                        }
                                        Write-Host $statusMsg -ForegroundColor Green
                                    } catch {
                                        Write-Warning "Failed to fetch all albums: $_"
                                    }
                                    continue
                                }
                                '^[\d,\-\s]+$' {
                                    # Parse multi-selection: "1,3,5-8,12"
                                    $selectedIndices = @()
                                    $parts = $inputF -split ','
                                    foreach ($part in $parts) {
                                        $part = $part.Trim()
                                        if ($part -match '^(\d+)-(\d+)$') {
                                            # Range: 5-8
                                            $start = [int]$matches[1]
                                            $end = [int]$matches[2]
                                            $selectedIndices += $start..$end
                                        } elseif ($part -match '^\d+$') {
                                            # Single number: 3
                                            $selectedIndices += [int]$part
                                        }
                                    }
                                    
                                    # Validate all indices
                                    $validIndices = $selectedIndices | Where-Object { $_ -ge 1 -and $_ -le $albumsForArtist.Count } | Select-Object -Unique | Sort-Object
                                    
                                    if ($validIndices.Count -eq 0) {
                                        Write-Warning "No valid album numbers selected"
                                        continue
                                    }
                                    
                                    # If single selection, go directly to Stage C
                                    if ($validIndices.Count -eq 1) {
                                        $ProviderAlbum = $albumsForArtist[$validIndices[0] - 1]
                                        $stage = 'C'
                                        $exitdo = $true
                                        break
                                    }
                                    
                                    # Multiple selections: combine all albums into one bucket
                                    Write-Host "`nFetching tracks from $($validIndices.Count) selected albums..." -ForegroundColor Cyan
                                    
                                    $combinedTracks = @()
                                    $albumNames = @()
                                    $failedAlbums = 0
                                    
                                    foreach ($idx in $validIndices) {
                                        $currentAlbum = $albumsForArtist[$idx - 1]
                                        $albumNames += $currentAlbum.name
                                        
                                        Write-Host "  [$idx] Fetching: $($currentAlbum.name)..." -ForegroundColor Gray
                                        
                                        try {
                                            $tracks = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $currentAlbum.id
                                            if ($tracks) {
                                                $combinedTracks += $tracks
                                                Write-Host "    ✓ Added $($tracks.Count) tracks" -ForegroundColor Green
                                            } else {
                                                Write-Warning "    ✗ No tracks returned for album: $($currentAlbum.name)"
                                                $failedAlbums++
                                            }
                                        }
                                        catch {
                                            Write-Warning "    ✗ Failed to fetch tracks for album: $($currentAlbum.name) - $_"
                                            $failedAlbums++
                                        }
                                    }
                                    
                                    if ($combinedTracks.Count -eq 0) {
                                        Write-Warning "No tracks retrieved from any selected albums. Please try again."
                                        continue
                                    }
                                    
                                    # Create a synthetic combined album object
                                    $firstAlbum = $albumsForArtist[$validIndices[0] - 1]
                                    $ProviderAlbum = [PSCustomObject]@{
                                        id = "combined_$($validIndices -join '_')"
                                        name = if ($validIndices.Count -eq 2) { 
                                            "$($albumNames[0]) + $($albumNames[1])" 
                                        } else { 
                                            "$($albumNames[0]) + $($validIndices.Count - 1) more albums" 
                                        }
                                        release_date = $firstAlbum.release_date
                                        _isCombined = $true
                                        _albumCount = $validIndices.Count
                                        _albumNames = $albumNames
                                        _selectedIndices = $validIndices
                                        _tracks = $combinedTracks
                                    }
                                    
                                    Write-Host "`n✓ Combined $($combinedTracks.Count) tracks from $($validIndices.Count) albums" -ForegroundColor Green
                                    if ($failedAlbums -gt 0) {
                                        Write-Warning "  Note: $failedAlbums album(s) failed to load"
                                    }
                                    
                                    $stage = 'C'
                                    $exitdo = $true
                                    break
                                }
                                default {
                                    # User entered text - try as a new search term first
                                    Write-Host "Searching for albums matching: '$inputF'..." -ForegroundColor Cyan
                                    try {
                                        $searchResults = Invoke-ProviderSearchAlbums `
                                            -Provider $Provider `
                                            -ArtistId $ProviderArtist.id `
                                            -ArtistName $ProviderArtist.name `
                                            -AlbumName $inputF `
                                            -MastersOnly:($Provider -eq 'Discogs')
                                        
                                        if ($searchResults -and $searchResults.Count -gt 0) {
                                            $albumsForArtist = @($searchResults)
                                            $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $inputF -String2 $_.Name) }
                                            $cachedAlbums = $albumsForArtist
                                            $page = 1
                                            Write-Host "Found $($albumsForArtist.Count) albums matching '$inputF'" -ForegroundColor Green
                                            continue
                                        }
                                    } catch {
                                        Write-Verbose "Search failed: $_"
                                    }
                                    
                                    # Fallback to local filtering if search failed or returned no results
                                    $filtered = $albumsForArtist | Where-Object { $_.name -like "*$inputF*" }
                                    if ($filtered.Count -gt 0) {
                                        $albumsForArtist = $filtered
                                        $page = 1
                                        Write-Host "Filtered to $($filtered.Count) albums" -ForegroundColor Green
                                        continue
                                    }
                                    else {
                                        Write-Warning "No matches found for '$inputF'"
                                        continue
                                    }
                                }
                            }   
                            if ($exitdo) { break }
                        }
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
                            try { 
                                $tracksForAlbum = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $ProviderAlbum.id 
                            } catch { 
                                Write-Warning "Get-AlbumTracks failed: $_"
                                $tracksForAlbum = @() 
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
                        do {
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
                                $optionsLine = "`nOptions:SortByTit(l)e,(d)uration,(t)rackNumber,(n)ame,(h)ybrid,(m)anual,(r)everse,(s)ave Tags(st),(sf)older,(sa)ll,(b)ack,(w)hatif $whatIfStatus (s)kip"
                                $commandList = @('d','t','n','l','h','m','r','st','sf','sa','b','w','whatif','skip')
                                $paramshow = @{
                                    PairedTracks   = $pairedTracks
                                    AlbumName      = $ProviderAlbum.name
                                    SpotifyArtist  = $ProviderArtist
                                    OptionsText    = $optionsLine
                                    ValidCommands  = $commandList
                                    PromptColor    = $HostColor
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
                                '^b$' { $stage = 'B'; $exitdo = $true; break }
                                '^whatif$|^w$' {
                                    $useWhatIf = -not $useWhatIf
                                    $refreshTracks = $true
                                    continue
                                }
                                '^skip$' { break 3 }
                                '^sf$' {
                                    $year = Get-ReleaseYear -ReleaseDate $ProviderAlbum.release_date
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment $ProviderAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment $ProviderArtist.name -Replacement '_' -CollapseRepeating -Transliterate
    
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
                                '^st$' {
                                    try {


                                        foreach ($pair in $pairedTracks) {
                                            if ($null -ne $pair.AudioFile) {
                                                $filePath = $pair.AudioFile.FilePath
                                                $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $pair.SpotifyTrack                        
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
                                            $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $pair.SpotifyTrack                        
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

                                        $genreTag = if ($null -ne $ProviderAlbum.genre) { $ProviderAlbum.genre -join '; ' } else { $ProviderArtist.genre -join '; ' }
                                        $tags = @{
                                            Title       = $spotifyTrack.Title
                                            Track       = $spotifyTrack.TrackNumber
                                            Disc        = $spotifyTrack.DiscNumber
                                            Performers  = $spotifyTrack.artists.name -join '; '
                                            Genres      = $genreTag
                                            AlbumArtist = $ProviderArtist.name
                                            Date        = $year
                                            Album       = $ProviderAlbum.name
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
                                    $year = Get-ReleaseYear -ReleaseDate $ProviderAlbum.release_date
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment $ProviderAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment $ProviderArtist.name -Replacement '_' -CollapseRepeating -Transliterate
    
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
                                            $stage = 'C'
                                            $exitDo = $true
                                            $albumDone = $true
                                            break
                                        }
                                        else {
                                            if ($moveResult.NewAlbumPath -eq $oldpath) {
                                                Write-Verbose "Move result indicates no change to album path; continuing."
                                                $stage = 'C'
                                                $exitDo = $true
                                                $albumDone = $true
                                                break
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
                                            
                                            $stage = "C"
                                            $exitDo = $true
                                            break 
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


