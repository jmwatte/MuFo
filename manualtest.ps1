#Import-Module Spotishell
#Load taglib from C:\Users\resto\Documents\PowerShell\Modules\MuFo\lib\TagLib.dll
#if (-not (Get-Module -Name TagLibSharp)) {
#    Add-Type -Path "C:\Users\resto\Documents\PowerShell\Modules\MuFo\lib\TagLib.dll"
#}
#Import-Module TagLibSharp
#Import-Module $manifest -Force -ErrorAction Stop
#Write-Host "MuFo module imported."
#find the artist
$artist = split-path $LiteralPath -Leaf
#find the albums
$albums = Get-ChildItem -LiteralPath $LiteralPath -Directory

 

foreach ($album in $albums) {
    $restartAlbum = $true
    while ($restartAlbum) {
        $restartAlbum = $false
        $skipAlbum = $false
        $SpotifyArtist = $null
        $spotifyAlbum = $null
        $spotifyTracks = $null
        $goBack = $false

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
            cls
            Write-Host "Artist candidates for '$artistQuery':"
            for ($i = 0; $i -lt $candidates.Count; $i++) {
                $num = $i + 1
                $item = $candidates[$i]
                Write-Host "[$num] $($item.name) - $($item.genres) (id: $($item.id))"
            }

            $prompt = "Select artist [1] (Enter=first), number, 'skip', 'id:<id>', or new search term:"
            $inputF = Read-Host $prompt

            if ($inputF -eq 'skip') { $skipAlbum = $true; break }
            if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $SpotifyArtist = @{ id = $id; name = $id }; break }
            if ($inputF -eq '') { $SpotifyArtist = $candidates[0]; break }
            if ($inputF -match '^\d+$') {
                $idx = [int]$inputF
                if ($idx -ge 1 -and $idx -le $candidates.Count) {
                    $SpotifyArtist = $candidates[$idx - 1]; break
                }
                else { Write-Warning "Invalid number. Try again."; continue }
            }
            # treat as new search term
            $artistQuery = $inputF
        }

        if ($skipAlbum) { Write-Host "Skipping album $($album.Name)"; continue }

        # Stage 2: album selection for chosen artist
        while (-not $skipAlbum -and $SpotifyArtist -and -not $spotifyAlbum) {
            try {
                $albumsForArtist = Get-ArtistAlbums -Id $SpotifyArtist.id -Album
            }
            catch {
                Write-Warning "Get-ArtistAlbums failed: $_"
                $albumsForArtist = @()
            }
            if (-not $albumsForArtist -or $albumsForArtist.Count -eq 0) {
                cls
                Write-Host "No albums found for artist id $($SpotifyArtist.id)."
                $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or album name to filter"
                if ($inputF -eq 'back') { $SpotifyArtist = $null; break }
                if ($inputF -eq 'skip') { $skipAlbum = $true; break }
                if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id }; break }
                if ($inputF) {
                    $albumsForArtist = @() # no results; loop will re-prompt
                    continue
                }
                else { continue }
            }
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
                if ($inputF -eq 'back') { $SpotifyArtist = $null; $goBack = $true; $paging = $false; break } # go back to stage 1
                if ($inputF -like 'id:*') { $id = $inputF.Substring(3); $spotifyAlbum = @{ id = $id; name = $id }; $paging = $false; break }
                if ($inputF -eq '') { $spotifyAlbum = $albumsForArtist[0]; $paging = $false; break }
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
        #collect all the audiofiles in the directory $album.fullname
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
        try {
            $tracksForAlbum = Get-AlbumTracks -Id $spotifyAlbum.id
        }
        catch {
            Write-Warning "Get-SpotifyAlbumTracks failed: $_"
            $tracksForAlbum = @()
        }
        $tracksForAlbum = $tracksForAlbum | ForEach-Object {
            [PSCustomObject]@{
                Id           = $_.id
                Title        = $_.name
                DiscNumber  = if ($_.disc_number) { $_.disc_number } else { 0 }
                TrackNumber = if ($_.track_number) { $_.track_number } else { 0 }
                Duration    = if ($_.duration_ms) { $_.duration_ms } else { 0 }
                Artist      = $_.artists.name
                FilePath    = $null  # placeholder; no file path in Spotify data
            }
        }
        $sortMethod = 'byName' #default sort method
        # Stage 3: track selection for chosen album
        while (-not $skipAlbum -and $spotifyAlbum) {
            
            if (-not $tracksForAlbum -or $tracksForAlbum.Count -eq 0) {
                Write-Host "No tracks found for album id $($spotifyAlbum.id)."
                $inputF = Read-Host "Enter 'back', 'skip', 'id:<id>' or manual comma-separated ids"
                # Accept single-letter "b" (any case) as shorthand for "back" so it returns to the previous loop
                if ($null -ne $inputF) { $inputF = $inputF.Trim() }
                if ($null -ne $inputF -and $inputF -ieq 'b') { $inputF = 'back' }
                if ($inputF -eq 'back') { $spotifyAlbum = $null; $goBack = $true; break }
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
                    $audioFiles = $audioFiles | Sort-Object DiscNumber, TrackNumber
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
                Write-Host ("`t`tartist: {0}" -f ($tracksForAlbum[$i].Artist -join ', '))
                #color the next 2 lines green if they were the same as the above,otherwise yellow
                if ($tracksForAlbum[$i].DiscNumber -eq $audioFiles[$i].DiscNumber -and
                    $tracksForAlbum[$i].TrackNumber -eq $audioFiles[$i].TrackNumber -and
                    $tracksForAlbum[$i].Name -eq $audioFiles[$i].Name) {
                    Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $audioFiles[$i].DiscNumber, $audioFiles[$i].TrackNumber, $audioFiles[$i].Title) -ForegroundColor Green
                    Write-Host ("`t`tartist: {0}" -f $audioFiles[$i].Artist) -ForegroundColor Green
                    Write-Host "filename:  $($audioFiles[$i].Name)"

                }
                else {
                   
                    Write-Host ("`t{0:D2}.{1:D2}: {2}" -f $audioFiles[$i].DiscNumber, $audioFiles[$i].TrackNumber, $audioFiles[$i].Title) -ForegroundColor Yellow
                    Write-Host ("`t`tartist: {0}" -f $audioFiles[$i].Artist) -ForegroundColor Yellow
                    Write-Host "$($audioFiles[$i].Name)"
                }

                # $t = $tracksForAlbum[$i]
                # Write-Host "[$num] $($t.name)  (id: $($t.id))"
                # Write-Host "`t $($t.artists.name -join ', ')"
            }
            #prompt should have an option for sorting the tracks by name, track number, duration and order
            $prompt = "Sort by (d)uration, (t)rack number, (n)ame, (o)rder. Current: $sortMethod. Select tracks (e.g. '1,3-5', 'all'), '(b)ack', '(s)kip', or 'id:<id1,id2>':"
            $inputF = Read-Host $prompt
            #if sortmethod is changed, re-sort the lists and re-display
            if ($inputF -ieq 'd') {
            
                $sortMethod = 'byDuration'; continue
            }
            if ($inputF -ieq 'o') {
                $sortMethod = 'byOrder'; continue
            }
            if ($inputF -ieq 't') {
                $sortMethod = 'byTrackNumber'; continue
            }
            if ($inputF -ieq 'n') {
                $sortMethod = 'byName'; continue
            }
            if ($inputF -ieq 'b') { $inputF = 'back' }

            if ($inputF -eq 'skip') { $skipAlbum = $true; break }
            if ($inputF -eq 'back') { $spotifyAlbum = $null; $goBack = $true; break }
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
        if ($goBack) {
            $goBack = $false
            $restartAlbum = $true
            continue
        }

        if ($skipAlbum) {
            break
        }
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

    }  # end while $restartAlbum
}  # end foreach $album
