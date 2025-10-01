function Invoke-MuFoManual {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz')]  # Add more providers as needed
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
        [switch]$goC
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
            # derive album name and year
            $album.Name -match '^(?<year>\d{4})' | Out-Null
            $year = $matches.year
            $albumName = if ($year) { $album.Name.Substring(5).Trim().Trim("-").Trim() } else { $album.Name.Trim("-").Trim() }
    
            $artistQuery = $artist
            $stage = "A"
    
            $albumDone = $false
            while ($true) {
                switch ($stage) {
                    "A" {
                        try { $r = Invoke-ProviderSearch -Provider $Provider -query $artistQuery -Type artist } catch { Write-Warning "Search failed: $_"; $r = $null }
                        $candidates = @()
                        if ($r -and $r.artists -and $r.artists.items) { $candidates = $r.artists.items }
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
                        try { $albumsForArtist = Invoke-ProviderGetAlbums -Provider $Provider -ArtistId $ProviderArtist.id -AlbumType 'Album' } catch { Write-Warning "Get-ArtistAlbums failed: $_"; $albumsForArtist = @() }
                        # Normalize to array so .Count works reliably
                        $albumsForArtist = @($albumsForArtist)
                            if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                                Write-Host "No albums found for artist id $($ProviderArtist.id)."
                                if ($NonInteractive) {
                                    Write-Warning "NonInteractive: skipping album because no albums found for artist id $($ProviderArtist.id)."
                                    break
                                }
                                $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or album name to filter"
                                if ($inputF -ieq 'back') { $stage = 'A'; continue }
                                if ($inputF -eq 'skip') { break }
                                if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderAlbum = @{ id = $id; name = $id }; $stage = 'C'; continue }
                                if ($inputF) { $artistQuery = $inputF; $stage = 'A'; continue } else { continue }
                            }
    
                        # sort by Jaccard similarity descending
                        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $albumName -String2 $_.Name) }
    
                        $page = 1; $pageSize = 25
                        while ($true) {
                           # Clear-Host
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

                                $inputF = Read-Host "Select album [1] (Enter=first), number, 'back', 'next', 'prev', 'skip', 'id:<id>', or text to filter:"
                                if ($inputF -ieq 'next') { if ($page -lt $totalPages) { $page++ } ; continue }
                                if ($inputF -ieq 'prev') { if ($page -gt 1) { $page-- } ; continue }
                                if ($inputF -ieq 'back') { $stage = 'A'; break }
                                if ($inputF -eq '') { $ProviderAlbum = $albumsForArtist[0]; $stage = 'C'; break }
                                if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderAlbum = @{ id = $id; name = $id }; $stage = 'C'; break }
                                if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $albumsForArtist.Count) { $ProviderAlbum = $albumsForArtist[$idx - 1]; $stage = 'C'; break } else { Write-Warning "Invalid"; continue } }
                                    if ($inputF -ieq 'next') { if ($page -lt $totalPages) { $page++ } ; continue }
                                    if ($inputF -ieq 'prev') { if ($page -gt 1) { $page-- } ; continue }
                                    if ($inputF -ieq 'back') { $stage = 'A'; break }
                                    if ($inputF -eq '') { $ProviderAlbum = $albumsForArtist[0]; $stage = 'C'; break }
                                    if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $ProviderAlbum = @{ id = $id; name = $id }; $stage = 'C'; break }
                                    if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $albumsForArtist.Count) { $ProviderAlbum = $albumsForArtist[$idx - 1]; $stage = 'C'; break } else { Write-Warning "Invalid"; continue } }
                            # treat as filter
                            $filtered = $albumsForArtist | Where-Object { $_.name -like "*$inputF*" }
                            if ($filtered.Count -gt 0) { $albumsForArtist = $filtered; $page = 1; continue } else { Write-Warning "No matches"; continue }
                        }
                    }
    
                    "C" {
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
                        $audioFiles = Get-ChildItem -Path $album.FullName -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                        $audioFiles = foreach ($f in $audioFiles) {
                            $tagFile = [TagLib.File]::Create($f.FullName)
                            [PSCustomObject]@{
                                FilePath    = $f.FullName
                                DiscNumber  = $tagFile.Tag.Disc
                                TrackNumber = $tagFile.Tag.Track
                                Title       = $tagFile.Tag.Title
                                TagFile     = $tagFile
                                Artist      = if ($tagFile.Tag.FirstPerformer) { $tagFile.Tag.FirstPerformer } else { 'Unknown Artist' }
                                Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                            }
                        }
    
                        try { $tracksForAlbum = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $ProviderAlbum.id } catch { Write-Warning "Get-SpotifyAlbumTracks failed: $_"; $tracksForAlbum = @() }
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
                                $hasDiscNumbers = ($tracksForAlbum | Where-Object { ($_.PSObject.Properties.Match('DiscNumber') -and $_.DiscNumber -gt 0) -or ($_.PSObject.Properties.Match('disc_number') -and $_.disc_number -gt 0) }).Count -gt 0
                            }
                        } catch { $hasDiscNumbers = $false }
                        $sortMethod = if ($hasDiscNumbers) { 'byTrackNumber' } else { 'byName' }

                        # Debug: when verbose, print the raw provider track list so users can verify
                        # that disc numbers were parsed and normalized (helps compare with test output)
                        try {
                            if ($PSBoundParameters.ContainsKey('Verbose')) {
                                Write-Host "\n[DEBUG] Provider tracks for album: $($ProviderAlbum.name) (count: $($tracksForAlbum.Count))" -ForegroundColor Cyan
                                $tracksForAlbum | Select-Object id, Title, DiscNumber, TrackNumber | Format-Table -AutoSize
                            }
                        } catch {
                            Write-Verbose "Failed to print debug provider tracks: $($_.Exception.Message)"
                        }
                        $exitdo = $false
                        do {
                            $sorted = Set-Tracks -SortMethod $sortMethod -AudioFiles $audioFiles -SpotifyTracks $tracksForAlbum
                            $audioFiles = $sorted.Audio
                            $tracksForAlbum = $sorted.Spotify
    
                            Show-Tracks -AudioFiles $audioFiles -SpotifyTracks $tracksForAlbum -AlbumName $ProviderAlbum.name -SpotifyArtist $ProviderArtist

                            # Pause briefly so the user can read the displayed track alignment
                            # Avoid blocking in non-interactive or auto-apply modes
                            if (-not $NonInteractive -and -not $goC) {
                                Write-Host "`nPress Enter to continue (or Ctrl+C to abort)..." -ForegroundColor Cyan
                                Read-Host | Out-Null
                            }

                            # If goC is set, auto-run save-all and skip interactive prompts (honor -WhatIf)
                            if ($goC) {
                                Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
                                $inputF = 'sa'
                            }
                            else {
                                Write-Host "`nOptions: SortBy(d)uration,SortBy(t)rackNumber,SortBy(n)ame,(st)saveTags,(sf)older,(sa)ll,(b)ack, (s)kip"
                                $inputF = Read-Host "Select tracks or command"
                            }
    
                            switch -Regex ($inputF) {
                                '^d$' { $sortMethod = 'byDuration'; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; continue }
                                '^n$' { $sortMethod = 'byName'; continue }
                                '^b$' { $stage = 'B'; break }
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
                                    if ($isWhatIf) {
                                        $moveResult = Move-AlbumFolder @mvArgs -WhatIf
                                    }
                                    else {
                                        $moveResult = Move-AlbumFolder @mvArgs
                                    }
    
                                    if ($moveResult -and $moveResult.Success) {
                                            # If the move would not change the path, don't prompt or attempt to re-open.
                                            if ($isWhatIf) {
                                                Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                                                Write-Host -NoNewline -ForegroundColor Green "Old: "
                                                Write-Host $oldpath
                                                Write-Host -NoNewline -ForegroundColor Green "New: "
                                                Write-Host $moveResult.NewAlbumPath
                                                if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $goC) -and -not $isWhatIf) {
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
                                        # Safe retrieval of artist genres (ProviderArtist may be a hashtable or minimal object)
                                        $artistGenres = @()
                                        if ($ProviderArtist) {
                                            try {
                                                if ($ProviderArtist -is [System.Collections.IDictionary]) { $artistGenres = $ProviderArtist['genres'] }
                                                elseif ($ProviderArtist.PSObject.Properties.Match('genres')) { $artistGenres = $ProviderArtist.genres }
                                            } catch { $artistGenres = @() }
                                        }
                                        for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                            $spotifyTrack = $tracksForAlbum[$i]
                                            $audioFile = $audioFiles[$i]
                                            $filePath = $audioFile.FilePath
                                            # compute album artist value defensively to avoid expression parsing issues
                                            $albumArtistValue = if ($ProviderArtist -and $ProviderArtist.PSObject.Properties.Match('name')) { $ProviderArtist.name } else { $ProviderArtist }

                                            $tags = @{
                                                Title       = $spotifyTrack.Title
                                                Track       = $spotifyTrack.TrackNumber
                                                Disc        = $spotifyTrack.DiscNumber
                                                Performers  = $spotifyTrack.Artist
                                                Genres      = $artistGenres
                                                AlbumArtist = $albumArtistValue
                                                Date        = $year
                                                Album       = $ProviderAlbum.name
                                            }
                                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                            if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $spotifyTrack.DiscNumber, $spotifyTrack.TrackNumber, $spotifyTrack.Title) -ForegroundColor Green }
                                            else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
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
                                    for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                        $spotifyTrack = $tracksForAlbum[$i]
                                        $audioFile = $audioFiles[$i]
                                        $filePath = $audioFile.FilePath
                                        $tags = @{
                                            Title       = $spotifyTrack.Title
                                            Track       = $spotifyTrack.TrackNumber
                                            Disc        = $spotifyTrack.DiscNumber
                                            Performers  = $spotifyTrack.Artist
                                            Genres      = $ProviderArtist.genres
                                            AlbumArtist = $ProviderArtist.name
                                            Date        = $year
                                            Album       = $ProviderAlbum.name
                                        }
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                        if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $spotifyTrack.DiscNumber, $spotifyTrack.TrackNumber, $spotifyTrack.Title) -ForegroundColor Green }
                                        else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
                                    }
    
                                    # dispose any lingering TagFile handles only when actually applying changes (not in -WhatIf)
                                    if (-not $isWhatIf) {
                                        foreach ($a in $audioFiles) {
                                            if ($a.TagFile) {
                                                try { $a.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($a.FilePath): $_" }
                                                $a.TagFile = $null
                                            }
                                        }
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
    
                                    if ($isWhatIf) {
                                        $moveResult = Move-AlbumFolder @mvArgs -WhatIf
                                    }
                                    else {
                                        $moveResult = Move-AlbumFolder @mvArgs
                                    }

                                    if ($moveResult -and $moveResult.Success) {
                                        if ($isWhatIf) {
                                            Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                                            Write-Host -NoNewline -ForegroundColor Green "Old: "
                                            Write-Host $oldpath
                                            Write-Host -NoNewline -ForegroundColor Green "New: "
                                            Write-Host $moveResult.NewAlbumPath
                                                if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $goC) -and -not $isWhatIf) {
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
    
                                '^(\d+(?:\.\.\d+|\-\d+)) (\+?\w+) (.+)$' {
                                    # Parse range, tag, and value from input (e.g., "1..8 +composer J.S. Bach")
                                    $rangeStr = $matches[1]
                                    $tagName = $matches[2]
                                    $tagValue = $matches[3]
    
                                    # Expand range to array of 1-based indices (e.g., "1..8" -> @(1,2,3,4,5,6,7,8))
                                    $indices = @()
                                    if ($rangeStr -match '^(\d+)\.\.(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        if ($start -le $end -and $start -ge 1 -and $end -le $tracksForAlbum.Count) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $($tracksForAlbum.Count))"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^(\d+)\-(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        if ($start -le $end -and $start -ge 1 -and $end -le $tracksForAlbum.Count) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $($tracksForAlbum.Count))"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^\d+$') {
                                        $idx = [int]$rangeStr
                                        if ($idx -ge 1 -and $idx -le $tracksForAlbum.Count) {
                                            $indices = @($idx)
                                        }
                                        else {
                                            Write-Warning "Invalid track number: $idx (must be 1 to $($tracksForAlbum.Count))"
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
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
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
    
        end {
            return [PSCustomObject]@{
                Path      = $Path
                Completed = $true
                WhatIf    = $isWhatIf
            }
        }
    }
}

