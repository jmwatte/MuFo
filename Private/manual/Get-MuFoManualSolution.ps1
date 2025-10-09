function Get-MuFoManualSolution {  
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path,
        [Parameter()]
        [switch]$IncludeTracks
    )

    begin {
        $extRegex = '\.(mp3|flac|wav|m4a|aac|ogg|ape)$'

        function Get-LocalAudioFiles {
            param([string]$AlbumPath)
            $files = Get-ChildItem -LiteralPath $AlbumPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match $extRegex }
            $out = @()
            foreach ($f in $files) {
                try {
                    $tl = [TagLib.File]::Create($f.FullName)
                    $out += [PSCustomObject]@{
                        Path        = $f.FullName
                        DiscNumber  = if ($tl.Tag.Disc) { $tl.Tag.Disc } else { 0 }
                        TrackNumber = if ($tl.Tag.Track) { $tl.Tag.Track } else { 0 }
                        Title       = $tl.Tag.Title
                        DurationMs  = [int]($tl.Properties.Duration.TotalMilliseconds)
                    }
                }
                catch {
                    $out += [PSCustomObject]@{
                        Path        = $f.FullName
                        DiscNumber  = 0
                        TrackNumber = 0
                        Title       = $f.BaseName
                        DurationMs  = 0
                    }
                }
            }
            return $out | Sort-Object @{Expression = { $_.DiscNumber }; Ascending = $true }, @{Expression = { $_.TrackNumber }; Ascending = $true }
        }

        function Find-LocalMatchForSpotifyTrack {
            param($spotifyTrack, $localTracks)
            $best = [PSCustomObject]@{ Local = $null; Score = 0.0; Kind = $null }
            if (-not $localTracks -or $localTracks.Count -eq 0) { return $best }

            if ($spotifyTrack.track_number) {
                $m = $localTracks | Where-Object { $_.TrackNumber -eq $spotifyTrack.track_number -and $_.DiscNumber -eq ($spotifyTrack.disc_number -as [int]) }
                if ($m) { $best.Local = $m[0]; $best.Score = 1.0; $best.Kind = 'trackNumber'; return $best }
            }

            $sname = ($spotifyTrack.name -as [string])
            if ($sname) {
                $m = $localTracks | Where-Object { $_.Title -and ($_.Title.Trim().ToLower() -eq $sname.Trim().ToLower()) }
                if ($m) { $best.Local = $m[0]; $best.Score = 0.95; $best.Kind = 'titleExact'; return $best }
            }

            if ($spotifyTrack.duration_ms) {
                $tol = 2000
                $closest = $localTracks | Sort-Object @{Expression = { [math]::Abs($_.DurationMs - $spotifyTrack.duration_ms) } } | Select-Object -First 1
                if ($closest -and ([math]::Abs($closest.DurationMs - $spotifyTrack.duration_ms) -le $tol)) { $best.Local = $closest; $best.Score = 0.85; $best.Kind = 'duration'; return $best }
            }

            return $best
        }
    }

    process {
        $artistPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
        if (-not $artistPath) { Write-Warning "Path not found: $Path"; return }
        $artistPath = $artistPath.ProviderPath
        $artist = Split-Path -Path $artistPath -Leaf
        $albums = Get-ChildItem -LiteralPath $artistPath -Directory
        foreach ($album in $albums) {
            Write-Host "--- Processing local album: $($album.Name) ---" -ForegroundColor Cyan

            $SpotifyArtist = $null
            $spotifyAlbum = $null
            $spotifyTracks = $null

            while ($true) {
            

                if (-not $SpotifyArtist) {
                
                    # Stage 1: artist selection/search
                    $artistQuery = $artist
                    while (-not $skipAlbum -and -not $SpotifyArtist) {
                        try {
                            $r = Search-Item -query $artistQuery -Type artist
                        }
                        catch {
                            Write-Warning "Find-SpotifyItem failed: $_"
                            $r = $null
                        }
                        $candidates = @()
                        if ($r -and $r.artists -and $r.artists.items) {
                            $candidates = $r.artists.items
                        }

                        if (-not $candidates -or $candidates.Count -eq 0) {
                            Write-Host "No artist candidates found for '$artistQuery'."
                            $inputF = Read-Host "Enter new search, 'skip' to skip album, or 'id:<id>' to select by id"
                            if ($inputF -eq 'skip') { $skipAlbum = $true; break }
                            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $SpotifyArtist = @{ id = $id; name = $id }; break }
                            if ($inputF) { $artistQuery = $inputF; continue } else { Write-Host "Empty inputF, re-running previous query."; continue }
                        }
                        Clear-Host
                        Write-Host "Artist candidates for '$artistQuery':"
                        for ($i = 0; $i -lt $candidates.Count; $i++) {
                            $num = $i + 1
                            $item = $candidates[$i]
                            Write-Host "[$num] $($item.name) - $($item.genres) (id: $($item.id))"
                        }

                        $prompt = "Select artist [1] (Enter=first), number, 'skip', 'id:<id>', or new search term:"
                        $inputF = Read-Host $prompt

                        if ($inputF -eq 'skip') { break }
                        if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $SpotifyArtist = @{ id = $id; name = $id } }
                        if ($inputF -eq '') { $SpotifyArtist = $candidates[0]; }
                        if ($inputF -match '^\d+$') {
                            $idx = [int]$inputF
                            if ($idx -ge 1 -and $idx -le $candidates.Count) {
                                $SpotifyArtist = $candidates[$idx - 1];
                            }
                            else { Write-Warning "Invalid number. Try again."; continue }
                        }
                        # treat as new search term
                        $artistQuery = $inputF
                    }

                    # if ($skipAlbum) { Write-Host "Skipping album $($album.Name)"; continue }
                }
                # Stage 2: album selection for chosen artist
                if (-not $spotifyAlbum) {
                    try {
                        $albumsForArtist = Get-ArtistAlbums -Id $SpotifyArtist.id -Album
                    }
                    catch {
                        Write-Warning "Get-ArtistAlbums failed: $_"
                        $albumsForArtist = @()
                    }
                   <#  if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                        Clear-Host
                        Write-Host "No albums found for artist id $($SpotifyArtist.id)."
                        $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or album name to filter"
                        if ($inputF -eq 'back') { $SpotifyArtist = $null; continue }
                        if ($inputF -eq 'skip') { $skipAlbum = $true; break }
                        if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id } }
                        if ($inputF) {
                            $albumsForArtist = @() # no results; loop will re-prompt
                            continue
                        }
                        else { continue }
                    } #>
                    #sort the albums first where the possible fit for $album.Name is on top
                    $albumsForArtist = $albumsForArtist | Sort-Object { if ($_.name -eq $album.Name) { 0 } elseif ($_.name -like "*$($album.Name)*") { 1 } else { 2 } }, name
                    $page = 1
                    $pageSize = 25
                    $paging = $true
                    while ($paging) {
                        Clear-Host
                        Write-Host "Albums for artist $($SpotifyArtist.name):"
                        Write-Host "for local album: $($album.Name)"
                        $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
                        $startIdx = ($page - 1) * $pageSize
                        $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)
                        Write-Host "Page $page of $totalPages"
                        for ($i = $startIdx; $i -le $endIdx; $i++) {
                            $num = $i + 1
                            $it = $albumsForArtist[$i]
                            Write-Host "[$num] $($it.name)  (id: $($it.id))"
                        }

                        $prompt = "Select album [1] (Enter=first), number, 'back'/'b', 'next'/'n', 'prev'/'p', 'skip', 'id:<id>', or text to filter:"
                        $inputF = Read-Host $prompt

                        if ($inputF -ieq 'b') { $inputF = 'back' }

                        if ($inputF -ieq 'n' -or $inputF -eq 'next') {
                            if ($page -lt $totalPages) { $page++ }
                            continue
                        }
                        if ($inputF -ieq 'p' -or $inputF -eq 'prev') {
                            if ($page -gt 1) { $page-- }
                            continue
                        }

                        if ($inputF -eq 'skip') { $skipAlbum = $true; $paging = $false; break }
                        if ($inputF -eq 'back') { $SpotifyArtist = $null; $paging = $false; continue } # go back to stage 1
                        if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id }; $paging = $false }
                        if ($inputF -eq '') { $spotifyAlbum = $albumsForArtist[0]; $paging = $false }
                        if ($inputF -match '^\d+$') {
                            $idx = [int]$inputF
                            if ($idx -ge 1 -and $idx -le $albumsForArtist.Count) {
                                $spotifyAlbum = $albumsForArtist[$idx - 1]; $paging = $false; break
                            }
                            else { Write-Warning "Invalid number. Try again."; continue }
                        }
                        # treat inputF as filter on album name (case-insensitive)
                        $filter = $inputF
                        $filtered = $albumsForArtist | Where-Object { $_.name -like "*$filter*" }
                        if ($filtered.Count -gt 0) {
                            $albumsForArtist = $filtered
                            $page = 1
                            continue
                        }
                        else {
                            Write-Warning "No albums matched filter '$filter'. Try again."
                            continue
                        }
                    }
                }
                # If album selection was skipped or we went back, restart the process for this album.
                if (-not $spotifyAlbum) {
                    if ($SpotifyArtist) { continue } # This handles 'back' from album to artist
                    else { break } # This handles 'skip'
                }
                <# if ($goBack) {
                    $isRestart = $true
                    $goBack = $false
                    $restartAlbum = $true
                    continue
                } #>
                #collect all the audiofiles in the directory $album.fullname
                $audioFiles = Get-AudioFileTags $album.FullName
                #$audioFiles = Get-ChildItem -Path $album.FullName -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                <# $audioFiles = foreach ($f in $audioFiles) {
                    
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
                    } #>
            } 
            if($spotifyAlbum){
            try {
                $tracksForAlbum = Get-AlbumTracks -Id $spotifyAlbum.id
            }
            catch {
                Write-Warning "Get-SpotifyAlbumTracks failed: $_"
                $tracksForAlbum = @()
            }
            $tracksForAlbum = $tracksForAlbum | ForEach-Object {
                [PSCustomObject]@{
                    Id          = $_.id
                    Title       = $_.name
                    DiscNumber  = if ($_.disc_number) { $_.disc_number } else { 0 }
                    TrackNumber = if ($_.track_number) { $_.track_number } else { 0 }
                    Duration    = if ($_.duration_ms) { $_.duration_ms } else { 0 }
                    Artist      = $_.artists.name
                    FilePath    = $null  # placeholder; no file path in Spotify data
                }
            }
        }
            $sortMethod = 'byName' #default sort method
            # Stage 3: track selection for chosen album
            if (-not $spotifyTracks) {
            
                if (-not $tracksForAlbum -or $tracksForAlbum.Count -eq 0) {
                    Write-Host "No tracks found for album id $($spotifyAlbum.id)."
                    $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or manual comma-separated ids"
                    # Accept single-letter "b" (any case) as shorthand for "back" so it returns to the previous loop
                    if ($null -ne $inputF) { $inputF = $inputF.Trim() }
                    if ($null -ne $inputF -and $inputF -ieq 'b') { $inputF = 'back' }
                    if ($inputF -eq 'back') { $spotifyAlbum = $null; continue }
                    if ($inputF -eq 'skip') { $skipAlbum = $true; break }
                    if ($inputF -like 'id:*') {
                        $ids = $inputF.Substring(3).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                        $spotifyTracks = $ids | ForEach-Object { @{ id = $_; name = $_ } }
                        break
                    }
                    if ($inputF) {
                        # treat as comma-separated ids
                        $ids = $inputF.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                        if ($ids) { $spotifyTracks = $ids | ForEach-Object { @{ id = $_; name = $_ } }; break }
                    }
                    continue
                }
            
          
                #make a switch to sort  $audiofiles and $tracksForAlbum. switch values are byname, byTracNumber, byDuration
                switch ($sortMethod) {
                    "byName" {
                        $audioFiles = $audioFiles | Sort-Object Title
                        $tracksForAlbum = $tracksForAlbum | Sort-Object Title
                    }
                    'byTrackNumber' {
                        $audioFiles = $audioFiles | Sort-Object Disc, Track
                        $tracksForAlbum = $tracksForAlbum | Sort-Object DiscNumber, TrackNumber
                    }
                    'byDuration' {
                        $audioFiles = $audioFiles | Sort-Object Duration
                        $tracksForAlbum = $tracksForAlbum | Sort-Object Duration
                    }
                    default {
                        # no sorting
                    }
                }

        
                Clear-Host
                Write-Host "Tracks for album $($spotifyAlbum.name):"
                for ($i = 0; $i -lt $tracksForAlbum.Count; $i++) {
                    $num = $i + 1
                    #color the next 2 lines green,
                    Write-Host "[$num]"
                    Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $tracksForAlbum[$i].DiscNumber, $tracksForAlbum[$i].TrackNumber, $tracksForAlbum[$i].Title)
                    Write-Host ("`t`tartist: {0} duration: {1}ms" -f ($tracksForAlbum[$i].Artist -join ', '), $tracksForAlbum[$i].Duration)
                    #color the next 2 lines green if they were the same as the above,otherwise yellow
                    if ($tracksForAlbum[$i].DiscNumber -eq $audioFiles[$i].DiscNumber -and
                        $tracksForAlbum[$i].TrackNumber -eq $audioFiles[$i].TrackNumber -and
                        $tracksForAlbum[$i].Name -eq $audioFiles[$i].Name) {
                        Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $audioFiles[$i].DiscNumber, $audioFiles[$i].TrackNumber, $audioFiles[$i].Title) -ForegroundColor Green
                        Write-Host ("`t`tartist: {0} duration: {1}ms" -f $audioFiles[$i].Artist, [int] $audioFiles[$i].Duration.TotalMilliseconds) -ForegroundColor Green
                        Write-Host "filename:  $($audioFiles[$i].Name)"

                    }
                    else {
                   
                        Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $audioFiles[$i].DiscNumber, $audioFiles[$i].TrackNumber, $audioFiles[$i].Title) -ForegroundColor Yellow
                        Write-Host ("`t`tartist: {0} duration: {1}ms" -f $audioFiles[$i].Artist, [int]$audioFiles[$i].Duration.TotalMilliseconds) -ForegroundColor Yellow
                        Write-Host "$($audioFiles[$i].Name)"
                    }

                    # $t = $tracksForAlbum[$i]
                    # Write-Host "[$num] $($t.name)  (id: $($t.id))"
                    # Write-Host "`t $($t.artists.name -join ', ')"
                }
                #prompt should have an option for sorting the tracks by name, track number, or duration
                $prompt = "Select tracks (e.g. '1,3-5', 'all'), durationS,trackS, nameS,(S), 'back', 'skip', or 'id:<id1,id2>':"
                $inputF = Read-Host $prompt
                #if sortmethod is changed, re-sort the lists and re-display
                if ($inputF -ieq 'd') {
            
                    $sortMethod = 'byDuration'; continue
                }
                if ($inputF -ieq 't') {
                    $sortMethod = 'byTrackNumber'; continue
                }
                if ($inputF -ieq 'n') {
                    $sortMethod = 'byName'; continue
                }
                if ($inputF -ieq 'b') { $inputF = 'back' }

                if ($inputF -eq 'skip') { $skipAlbum = $true; break }
                if ($inputF -eq 'back') { $spotifyAlbum = $null; continue }
                if ($inputF -like 'id:*') {
                    $ids = $inputF.Substring(3).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    $spotifyTracks = $ids | ForEach-Object {
                        $match = $tracksForAlbum | Where-Object { $_.id -eq $_ } 
                        if ($match) { $match } else { @{ id = $_; name = $_ } }
                    }
                    break
                }
                if ($inputF -eq '') { $indexes = 1..1 } # default to first track
                else {
                    $indexes = Get-TrackSelection -input $inputF -max $tracksForAlbum.Count
                }
                if ($indexes -and $indexes.Count -gt 0) {
                    $spotifyTracks = $indexes | ForEach-Object { $tracksForAlbum[$_ - 1] }
                    break
                }
                else {
                    Write-Warning "No valid track selection parsed. Try again."
                    continue
                }
    
            }
            # FIX: Only reset album, not artist, when going back from track selection
            <# if ($goBack -and $spotifyAlbum -eq $null) {
                # Do NOT reset $SpotifyArtist
                $spotifyTracks = $null
                $goBack = $false
                $restartAlbum = $true
                $isRestart = $true
                continue
            } #>
            <# if ($goBack) {
                $isRestart = $true
                $goBack = $false
                $restartAlbum = $true
                continue
            } #>

           <#  if ($skipAlbum) {
                break
            } #>
            
            # At this point we have $SpotifyArtist, $spotifyAlbum, $spotifyTracks (or we returned to earlier stage)
            if ($SpotifyArtist) { Write-Host "Selected artist: $($SpotifyArtist.name) (id: $($SpotifyArtist.id))" }
            if ($spotifyAlbum) { Write-Host "Selected album: $($spotifyAlbum.name) (id: $($spotifyAlbum.id))" }
            if ($spotifyTracks) {
                Write-Host "Selected tracks:"
                foreach ($t in $spotifyTracks) {
                    Write-Host " - $($t.name) (id: $($t.id))"
                }
            }

            Write-Host "Album found: $($album.Name)"

        }
    }  # end while $restartAlbum
} 













<#  $albums = Get-ChildItem -LiteralPath $artistPath -Directory -ErrorAction SilentlyContinue
        foreach ($album in $albums) {
            $spotifyArtist = $null
            $spotifyAlbum = $null
            $spotifyTracks = @()

            if (Get-Command Search-Item -ErrorAction SilentlyContinue) {
                try { $res = Search-Item -Query $localArtist -Type artist } catch { $res = $null }
                if ($res -and $res.artists -and $res.artists.items) { $cand = $res.artists.items } else { $cand = @() }
            }
            else { $cand = @() }

            if ($cand.Count -gt 0) { $spotifyArtist = $cand[0] } else { $spotifyArtist = @{ id = $localArtist; name = $localArtist } }

            if (Get-Command Get-ArtistAlbums -ErrorAction SilentlyContinue) {
                try { $alist = Get-ArtistAlbums -Id $spotifyArtist.id -Album } catch { $alist = @() }
                if ($alist -and $alist.Count -gt 0) {
                    $spotifyAlbum = $alist | Where-Object { $_.name -like "*$($album.Name)*" } | Select-Object -First 1
                    if (-not $spotifyAlbum) { $spotifyAlbum = $alist[0] }
                }
            }

            $localFiles = Get-LocalAudioFiles -AlbumPath $album.FullName
            if ($spotifyAlbum -and (Get-Command Get-AlbumTracks -ErrorAction SilentlyContinue)) {
                try { $sTracks = Get-AlbumTracks -Id $spotifyAlbum.id } catch { $sTracks = @() }
                $spotifyTracks = $sTracks | ForEach-Object { [PSCustomObject]@{ id = $_.id; name = $_.name; disc_number = if ($_.disc_number) { $_.disc_number }else { 0 }; track_number = if ($_.track_number) { $_.track_number }else { 0 }; duration_ms = if ($_.duration_ms) { $_.duration_ms }else { 0 } } }
            }

            $selectedSpotify = $spotifyTracks
            if ($IncludeTracks -or $true) {
                if ($spotifyTracks.Count -gt 0) {
                    Write-Host "Album: $($spotifyAlbum.name) — choose tracks or press Enter for all"
                    for ($i = 0; $i -lt $spotifyTracks.Count; $i++) { Write-Host "[$($i+1)] $($spotifyTracks[$i].name)" }
                    $sel = Read-Host "Select tracks (e.g. '1,3-5' or 'all')"
                    if ($sel -and $sel.Trim() -ne '') {
                        if ($sel -ieq 'all') { $selectedSpotify = $spotifyTracks }
                        else {
                            $indexes = @()
                            foreach ($part in ($sel.Split(',') | ForEach-Object { $_.Trim() })) {
                                if ($part -match '^(\d+)-(\d+)$') {
                                    $a = [int]$matches[1]; $b = [int]$matches[2]
                                    for ($n = $a; $n -le $b; $n++) { $indexes += $n }
                                }
                                elseif ($part -match '^\d+$') { $indexes += [int]$part }
                            }
                            $selectedSpotify = $indexes | Get-Unique | Sort-Object | ForEach-Object { if ($_ -ge 1 -and $_ -le $spotifyTracks.Count) { $spotifyTracks[$_ - 1] } } | Where-Object { $_ }
                        }
                    }
                }
            }

            $map = @()
            foreach ($st in $selectedSpotify) {
                $m = Find-LocalMatchForSpotifyTrack -spotifyTrack $st -localTracks $localFiles
                $map += [PSCustomObject]@{ SpotifyTrack = $st; LocalFile = $m.Local; Kind = $m.Kind; Score = $m.Score }
            }

            $out = [PSCustomObject]@{
                LocalArtist       = $localArtist
                LocalAlbum        = $album.Name
                LocalAlbumPath    = $album.FullName
                SelectedArtist    = $spotifyArtist
                SelectedAlbum     = $spotifyAlbum
                SelectedTracks    = $selectedSpotify
                LocalFiles        = $localFiles
                SpotifyToLocalMap = $map
            }

            Write-Output $out #>
    


