function Invoke-MuFoStageC {
    <#
    .SYNOPSIS
        Handles Stage C of the MuFo manual workflow: track pairing and tagging.

    .DESCRIPTION
        Displays track pairing UI, allows sorting and selection options,
        and handles tag saving operations for the selected album.

    .PARAMETER ProviderAlbum
        The selected album object from Stage B.

    .PARAMETER ProviderArtist
        The selected artist object from Stage A.

    .PARAMETER Provider
        The music provider to use (Spotify, Qobuz, Discogs).

    .PARAMETER Album
        The album folder object.

    .PARAMETER NonInteractive
        If specified, run in non-interactive mode (no user prompts).

    .PARAMETER GoC
        If specified, automatically apply save-all operation.

    .PARAMETER UseWhatIf
        If specified, run in WhatIf mode (preview changes).

    .PARAMETER ReverseSource
        Reference to reverse source flag for track pairing.

    .PARAMETER CachedAlbums
        Reference to cached albums (will be cleared on provider switch).

    .PARAMETER CachedArtistId
        Reference to cached artist ID (will be cleared on provider switch).

    .OUTPUTS
        PSCustomObject with properties:
        - Stage: Next stage to proceed to ('B' for back, 'C' for continue)
        - Provider: Updated provider (may change if user switches)
        - Album: Updated album object (may change if folder moved)
        - AlbumDone: $true if album processing is complete
        - ShouldBreak: $true if should break out of album loop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProviderAlbum,

        [Parameter(Mandatory)]
        [object]$ProviderArtist,

        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter(Mandatory)]
        [object]$Album,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$GoC,

        [Parameter()]
        [switch]$UseWhatIf,

        [Parameter()]
        [ref]$ReverseSource,

        [Parameter()]
        [ref]$CachedAlbums,

        [Parameter()]
        [ref]$CachedArtistId
    )

    Clear-Host
    if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }

    # Display appropriate header for single or combined albums
    if (Get-IfExists $ProviderAlbum '_isCombined') {
        Write-Host "Processing COMBINED album set:" -ForegroundColor Yellow
        $albumCount = Get-IfExists $ProviderAlbum '_albumCount'
        $tracks = Get-IfExists $ProviderAlbum '_tracks'
        $albumNames = Get-IfExists $ProviderAlbum '_albumNames'
        Write-Host "  Albums: $albumCount" -ForegroundColor Cyan
        Write-Host "  Tracks: $($tracks.Count)" -ForegroundColor Cyan
        foreach ($albumName in $albumNames) {
            Write-Host "    - $albumName" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        $albumName = Get-IfExists $ProviderAlbum 'name'
        $albumId = Get-IfExists $ProviderAlbum 'id'
        Write-Host "Searching tracks for album: $albumName (id: $albumId)"
    }

    # If the caller asked for non-interactive behavior, do not try to drive the
    # interactive track-selection UI. This prevents Read-Host from blocking the
    # process in unattended runs. The caller can run interactively to inspect and
    # approve mappings, or add a future explicit flag to auto-apply changes.
    if ($NonInteractive) {
        $albumNameNonInt = Get-IfExists $ProviderAlbum 'name'
        Write-Warning "NonInteractive: skipping interactive track selection for album '$albumNameNonInt'."
        # break out of the switch AND the enclosing stage while-loop to continue with next album
        return [PSCustomObject]@{
            Stage = 'C'
            Provider = $Provider
            Album = $Album
            AlbumDone = $true
            ShouldBreak = $true
        }
    }

    # collect audio files and tags
    $audioFiles = Get-ChildItem -LiteralPath $Album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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

    $pairedTracks = $null
    $refreshTracks = $true
    $goCDisplayShown = $false

    :doTracks do {
        if ($refreshTracks -or -not $pairedTracks) {
            if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
            $param = @{
                SortMethod    = $sortMethod
                AudioFiles    = $audioFiles
                SpotifyTracks = $tracksForAlbum
            }
            if ($ReverseSource.Value) { $param.Reverse = $true }
            $pairedTracks = Set-Tracks @param
            $refreshTracks = $false

            if ($GoC -and -not $goCDisplayShown) {
                $autoReader = { param($prompt) 'q' }
                $autoShowParams = @{
                    PairedTracks  = $pairedTracks
                    AlbumName     = $ProviderAlbum.name
                    SpotifyArtist = $ProviderArtist
                }
                if ($ReverseSource.Value) { $autoShowParams.Reverse = $true }
                Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                $goCDisplayShown = $true
            }
        }

        if ($GoC) {
            Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
            $inputF = 'sa'
        }
        else {
            if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
            $whatIfStatus = if ($UseWhatIf) { "ON" } else { "OFF" }
            $optionsLine = "`nOptions:SortByTit(l)e,(d)uration,(t)rackNumber,(n)ame,(h)ybrid,(m)anual,(r)everse,(s)ave Tags(st),(sf)older,(sa)ll,(b)ack,(cp) change provider,(w)hatif $whatIfStatus (s)kip"
            $commandList = @('d','t','n','l','h','m','r','st','sf','sa','b','cp','w','whatif','s')
            $paramshow = @{
                PairedTracks   = $pairedTracks
                AlbumName      = $ProviderAlbum.name
                SpotifyArtist  = $ProviderArtist
                OptionsText    = $optionsLine
                ValidCommands  = $commandList
                PromptColor    = $HostColor
                ProviderName   = $Provider
            }
            if ($ReverseSource.Value) { $paramshow.Reverse = $true }

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
            '^r$' { $ReverseSource.Value = -not $ReverseSource.Value; $refreshTracks = $true; continue }
            '^b$' {
                return [PSCustomObject]@{
                    Stage = 'B'
                    Provider = $Provider
                    Album = $Album
                    AlbumDone = $false
                    ShouldBreak = $false
                }
            }
            '^cp$' {
                Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
                $newProvider = Read-Host "Enter new provider name"
                if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                    $Provider = $newProvider
                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                    $CachedAlbums.Value = $null
                    $CachedArtistId.Value = $null
                    return [PSCustomObject]@{
                        Stage = 'A'
                        Provider = $Provider
                        Album = $Album
                        AlbumDone = $false
                        ShouldBreak = $false
                    }
                } else {
                    Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                    continue
                }
            }
            '^whatif$|^w$' {
                $UseWhatIf = -not $UseWhatIf
                $refreshTracks = $true
                continue
            }
            '^s$' {
                return [PSCustomObject]@{
                    Stage = 'C'
                    Provider = $Provider
                    Album = $Album
                    AlbumDone = $false
                    ShouldBreak = $true
                }
            }
            '^sf$' {
                $year = Get-ReleaseYear -ReleaseDate $ProviderAlbum.release_date
                $oldpath = $Album.FullName
                $safeAlbumName = Approve-PathSegment -Segment $ProviderAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                $safeArtistName = Approve-PathSegment -Segment $ProviderArtist.name -Replacement '_' -CollapseRepeating -Transliterate

                $mvArgs = @{
                    AlbumPath    = $oldpath
                    NewArtist    = $safeArtistName
                    NewYear      = $year
                    NewAlbumName = $safeAlbumName
                }
                # call Move-AlbumFolder and pass -WhatIf from the caller (if requested)
                $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$UseWhatIf

                if ($moveResult -and $moveResult.Success) {
                    # If the move would not change the path, don't prompt or attempt to re-open.
                    if ($UseWhatIf) {
                        Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                        Write-Host -NoNewline -ForegroundColor Green "Old: "
                        Write-Host $oldpath
                        Write-Host -NoNewline -ForegroundColor Green "New: "
                        Write-Host $moveResult.NewAlbumPath
                        if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $GoC) -and -not $UseWhatIf) {
                            # Only pause for an explicit interactive run. In preview/WhatIf or when
                            # NonInteractive/GoC is set, skip the blocking prompt so unattended
                            # runs don't hang.
                            Read-Host -Prompt "Press Enter to continue"
                        }
                        else {
                            Write-Verbose "NonInteractive/GoC/WhatIf or no-path-change: skipping pause after move."
                        }
                        return [PSCustomObject]@{
                            Stage = 'C'
                            Provider = $Provider
                            Album = $Album
                            AlbumDone = $true
                            ShouldBreak = $false
                        }
                    }
                    else {
                        # If the new path is identical to the current one, avoid reloading
                        if ($moveResult.NewAlbumPath -eq $oldpath) {
                            Write-Verbose "Move result indicates no change to album path; continuing."
                            return [PSCustomObject]@{
                                Stage = 'C'
                                Provider = $Provider
                                Album = $Album
                                AlbumDone = $true
                                ShouldBreak = $false
                            }
                        }
                        $Album = Get-Item -LiteralPath $moveResult.NewAlbumPath
                        return [PSCustomObject]@{
                            Stage = 'C'
                            Provider = $Provider
                            Album = $Album
                            AlbumDone = $true
                            ShouldBreak = $false
                        }
                    }
                }
                else {
                    Write-Warning "Move failed or was skipped. Move result: $moveResult"
                }
                continue
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
                    $saveResult = Save-MuFoTrackSelection -PairedTracks $pairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$UseWhatIf
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
                            $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $pair.SpotifyTrack
                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf
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

                    # Dispose old TagFile handles and reload to show updated tags
                    if (-not $UseWhatIf) {
                        foreach ($af in $audioFiles) {
                            if ($af.TagFile) {
                                try { $af.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile: $_" }
                                $af.TagFile = $null
                            }
                        }
                        # Reload audio files with fresh TagLib handles
                        $audioFiles = Get-ChildItem -LiteralPath $Album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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
                    return [PSCustomObject]@{
                        Stage = 'C'
                        Provider = $Provider
                        Album = $Album
                        AlbumDone = $true
                        ShouldBreak = $false
                    }
                }
                catch {
                    Write-Host '---- ERROR in save-tags (st) handler ----' -ForegroundColor Red
                    Write-Host "Message: $($_.Exception.Message)"
                    Write-Host "Exception: $($_ | Out-String)"
                    Write-Host "ScriptStackTrace: $($_.ScriptStackTrace)"
                    # keep UI alive; set stage to C so outer loop continues
                    return [PSCustomObject]@{
                        Stage = 'C'
                        Provider = $Provider
                        Album = $Album
                        AlbumDone = $true
                        ShouldBreak = $false
                    }
                }
            }
            '^sa$' {
                foreach ($pair in $pairedTracks) {
                    if ($null -ne $pair.AudioFile) {
                        $filePath = $pair.AudioFile.FilePath
                        $tags = get-Tags -Artist $ProviderArtist -Album $ProviderAlbum -SpotifyTrack $pair.SpotifyTrack
                        Write-Verbose ("Saving tags to: {0}" -f $filePath)
                        Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf
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

                # dispose any lingering TagFile handles only when actually applying changes (not in -WhatIf)
                if (-not $UseWhatIf) {
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
                $oldpath = $Album.FullName
                $safeAlbumName = Approve-PathSegment -Segment $ProviderAlbum.name -Replacement '_' -CollapseRepeating -Transliterate
                $safeArtistName = Approve-PathSegment -Segment $ProviderArtist.name -Replacement '_' -CollapseRepeating -Transliterate

                $mvArgs = @{
                    AlbumPath    = $oldpath
                    NewArtist    = $safeArtistName
                    NewYear      = $year
                    NewAlbumName = $safeAlbumName
                }

                $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$UseWhatIf

                if ($moveResult -and $moveResult.Success) {
                    if ($UseWhatIf) {
                        Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                        Write-Host -NoNewline -ForegroundColor Green "Old: "
                        Write-Host $oldpath
                        Write-Host -NoNewline -ForegroundColor Green "New: "
                        Write-Host $moveResult.NewAlbumPath
                        if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $GoC) -and -not $UseWhatIf) {
                            Read-Host -Prompt "Press Enter to continue"
                        }
                        else {
                            Write-Verbose "NonInteractive/GoC/WhatIf or no-path-change: skipping pause after move."
                        }
                        return [PSCustomObject]@{
                            Stage = 'C'
                            Provider = $Provider
                            Album = $Album
                            AlbumDone = $true
                            ShouldBreak = $true
                        }
                    }
                    else {
                        if ($moveResult.NewAlbumPath -eq $oldpath) {
                            Write-Verbose "Move result indicates no change to album path; continuing."
                            return [PSCustomObject]@{
                                Stage = 'C'
                                Provider = $Provider
                                Album = $Album
                                AlbumDone = $true
                                ShouldBreak = $true
                            }
                        }
                        # Folder was moved - update $album and reload audio files from new location
                        $Album = Get-Item -LiteralPath $moveResult.NewAlbumPath

                        # Reload audio files with fresh TagLib handles from the NEW album path
                        $audioFiles = Get-ChildItem -LiteralPath $Album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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

                        return [PSCustomObject]@{
                            Stage = 'C'
                            Provider = $Provider
                            Album = $Album
                            AlbumDone = $true
                            ShouldBreak = $true
                        }
                    }
                }
                else {
                    Write-Warning "Move failed or was skipped. Move result: $moveResult"
                }
                continue
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
                    $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf
                    if ($res.Success) {
                        Write-Host ("Updated tag '$actualTagName' for track $idx ($($spotifyTrack.Title)): '$newValue'") -ForegroundColor Green
                    }
                    else {
                        Write-Warning ("Failed to update tag for track $($idx): $($res.Reason)")
                    }
                }

                return [PSCustomObject]@{
                    Stage = 'C'
                    Provider = $Provider
                    Album = $Album
                    AlbumDone = $true
                    ShouldBreak = $false
                }
            }

            default { Write-Warning "Unknown option"; continue }
        }
    } while ($true)
}