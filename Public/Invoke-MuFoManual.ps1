function Invoke-MuFoManual {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
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
            # $restart = $false

            while ($true) {
                switch ($stage) {
                    "A" {
                        try { $r = Search-Item -query $artistQuery -Type artist } catch { Write-Warning "Search failed: $_"; $r = $null }
                        $candidates = @()
                        if ($r -and $r.artists -and $r.artists.items) { $candidates = $r.artists.items }

                        if (-not $candidates -or $candidates.Count -eq 0) {
                            Write-Host "No artist candidates found for '$artistQuery'."
                            $inputF = Read-Host "Enter new search, 'skip' to skip album, or 'id:<id>' to select by id"
                            if ($inputF -eq 'skip') { break }
                            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $SpotifyArtist = @{ id = $id; name = $id }; $stage = 'B'; continue }
                            if ($inputF) { $artistQuery = $inputF; continue } else { continue }
                        }

                        Write-Host "Artist candidates for '$artistQuery':"
                        for ($i = 0; $i -lt $candidates.Count; $i++) {
                            Write-Host "[$($i+1)] $($candidates[$i].name) - $($candidates[$i].genres -join ', ') (id: $($candidates[$i].id))"
                        }

                        $inputF = Read-Host "Select artist [1] (Enter=first), number, 'skip', 'id:<id>', or new search term:"
                        if ($inputF -eq '') { $SpotifyArtist = $candidates[0]; $stage = 'B'; continue }
                        if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $SpotifyArtist = @{ id = $id; name = $id }; $stage = 'B'; continue }
                        if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $candidates.Count) { $SpotifyArtist = $candidates[$idx - 1]; $stage = 'B'; continue } else { Write-Warning "Invalid"; continue } }
                        if ($inputF -eq 'skip') { break }
                        $artistQuery = $inputF; continue
                    }

                    "B" {
                        try { $albumsForArtist = Get-ArtistAlbums -Id $SpotifyArtist.id -Album } catch { Write-Warning "Get-ArtistAlbums failed: $_"; $albumsForArtist = @() }
                        if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                            Write-Host "No albums found for artist id $($SpotifyArtist.id)."
                            $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or album name to filter"
                            if ($inputF -ieq 'back') { $stage = 'A'; continue }
                            if ($inputF -eq 'skip') { break }
                            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id }; $stage = 'C'; continue }
                            if ($inputF) { $artistQuery = $inputF; $stage = 'A'; continue } else { continue }
                        }

                        # sort by Jaccard similarity descending
                        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $albumName -String2 $_.Name) }

                        $page = 1; $pageSize = 25
                        while ($true) {
                            Clear-Host
                            Write-Host "Albums for artist $($SpotifyArtist.name):"
                            Write-Host "for local album: $($albumName) (year: $year)"
                            $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
                            $startIdx = ($page - 1) * $pageSize
                            $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)

                            for ($i = $startIdx; $i -le $endIdx; $i++) {
                                Write-Host "[$($i+1)] $($albumsForArtist[$i].name)  (id: $($albumsForArtist[$i].id)) (year: $($albumsForArtist[$i].release_date))"
                            }

                            $inputF = Read-Host "Select album [1] (Enter=first), number, 'back', 'next', 'prev', 'skip', 'id:<id>', or text to filter:"
                            if ($inputF -ieq 'next') { if ($page -lt $totalPages) { $page++ } ; continue }
                            if ($inputF -ieq 'prev') { if ($page -gt 1) { $page-- } ; continue }
                            if ($inputF -ieq 'back') { $stage = 'A'; break }
                            if ($inputF -eq '') { $spotifyAlbum = $albumsForArtist[0]; $stage = 'C'; break }
                            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id }; $stage = 'C'; break }
                            if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $albumsForArtist.Count) { $spotifyAlbum = $albumsForArtist[$idx - 1]; $stage = 'C'; break } else { Write-Warning "Invalid"; continue } }
                            # treat as filter
                            $filtered = $albumsForArtist | Where-Object { $_.name -like "*$inputF*" }
                            if ($filtered.Count -gt 0) { $albumsForArtist = $filtered; $page = 1; continue } else { Write-Warning "No matches"; continue }
                        }
                    }

                    "C" {
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

                        try { $tracksForAlbum = Get-AlbumTracks -Id $spotifyAlbum.id } catch { Write-Warning "Get-SpotifyAlbumTracks failed: $_"; $tracksForAlbum = @() }
                        $tracksForAlbum = $tracksForAlbum | ForEach-Object {
                            [PSCustomObject]@{
                                Id          = $_.id
                                Title       = $_.name
                                DiscNumber  = if ($_.disc_number) { $_.disc_number } else { 0 }
                                TrackNumber = if ($_.track_number) { $_.track_number } else { 0 }
                                Duration    = if ($_.duration_ms) { $_.duration_ms } else { 0 }
                                Artist      = $_.artists.name
                                FilePath    = $null
                            }
                        }

                        $sortMethod = 'byName'
                        $exitdo = $false
                        do {
                            $sorted = Set-Tracks -SortMethod $sortMethod -AudioFiles $audioFiles -SpotifyTracks $tracksForAlbum
                            $audioFiles = $sorted.Audio
                            $tracksForAlbum = $sorted.Spotify

                            Show-Tracks -AudioFiles $audioFiles -SpotifyTracks $tracksForAlbum -AlbumName $spotifyAlbum.name -SpotifyArtist $SpotifyArtist

                            Write-Host "`nOptions: SortBy(d)uration,SortBy(t)rackNumber,SortBy(n)ame,(st)saveTags,(sf)older,(sa)ll,(b)ack, (s)kip"
                            $inputF = Read-Host "Select tracks or command"

                            switch -Regex ($inputF) {
                                '^d$' { $sortMethod = 'byDuration'; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; continue }
                                '^n$' { $sortMethod = 'byName'; continue }
                                '^b$' { $stage = 'B'; break }
                                '^skip$' { break 3 }
                                '^sf$' {
                                    $year = Get-ReleaseYear -ReleaseDate $spotifyAlbum.release_date
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment $spotifyAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment $SpotifyArtist.name -Replacement '_' -CollapseRepeating -Transliterate


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
                                        if ($isWhatIf) {
                                            Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                                            Write-Host -NoNewline -ForegroundColor Green "Old: "
                                            Write-Host $oldpath
                                            Write-Host -NoNewline -ForegroundColor Green "New: "
                                            Write-Host $moveResult.NewAlbumPath
                                            Read-Host -Prompt "Press Enter to continue (WhatIf)"
                                            $stage = 'C'
                                            $exitDo = $true
                                            break
                                        }
                                        else {
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
                                    for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                                        $spotifyTrack = $tracksForAlbum[$i]
                                        $audioFile = $audioFiles[$i]
                                        $filePath = $audioFile.FilePath
                                        $tags = @{
                                            Title       = $spotifyTrack.Title
                                            Track       = $spotifyTrack.TrackNumber
                                            Disc        = $spotifyTrack.DiscNumber
                                            Performers  = $spotifyTrack.Artist
                                            Genres      = $SpotifyArtist.genres
                                            AlbumArtist = $SpotifyArtist.name
                                            Date        = $year
                                            Album       = $spotifyAlbum.name

                                        }
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$isWhatIf
                                        if ($res.Success) { Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $spotifyTrack.DiscNumber, $spotifyTrack.TrackNumber, $spotifyTrack.Title) -ForegroundColor Green }
                                        else { Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) }
                                    }
                                    $stage = 'C'
                                    $exitDo = $true
                                    break
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
                                            Genres      = $SpotifyArtist.genres
                                            AlbumArtist = $SpotifyArtist.name
                                            Date        = $year
                                            Album       = $spotifyAlbum.name

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
                                    $year = Get-ReleaseYear -ReleaseDate $spotifyAlbum.release_date
                                    $oldpath = $album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment $spotifyAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                                    $safeArtistName = Approve-PathSegment -Segment $SpotifyArtist.name -Replacement '_' -CollapseRepeating -Transliterate

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
                                            Read-Host -Prompt "Press Enter to continue (WhatIf)"
                                            $stage = 'C'
                                            $exitDo = $true
                                            break
                                        }
                                        else {
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
                                    break
                                }

                                default { Write-Warning "Unknown option"; continue }
                            }
                            if ($exitDo) { break }
                        } while ($true)
                    }
                }
                continue
                # if ($restart) { break } else { break } # move to next album
            } # end while per-album
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