function Invoke-MuFoStageB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ProviderArtist,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [string]$Provider,
        [string]$AlbumId,
        [int]$Year,
        [switch]$AutoSelect,
        [switch]$NonInteractive,
        [switch]$goB,

        # State management
        [array]$CachedAlbums,
        [bool]$MastersOnlyMode = $true,
        [int]$Page = 1,
        [int]$PageSize = 25
    )

    # Initialize state
    $albumsForArtist = $CachedAlbums
    $cachedArtistId = $ProviderArtist.id
    $page = $Page
    $mastersOnlyMode = $MastersOnlyMode
    $pageSize = $PageSize

    # Clear cache if artist changed
    if ($cachedArtistId -ne $ProviderArtist.id) {
        $albumsForArtist = $null
        $cachedArtistId = $ProviderArtist.id
    }

    # Try smart API search FIRST (fast, targeted results)
    if (-not $albumsForArtist) {
        Write-Host "Searching for albums matching: $AlbumName..." -ForegroundColor Cyan
        Write-Verbose "Trying smart search for: $AlbumName"
        Write-Verbose "Parameters: Provider=$Provider, ArtistId=$($ProviderArtist.id), ArtistName=$($ProviderArtist.name), AlbumName=$AlbumName, MastersOnly=$($Provider -eq 'Discogs'), CacheProvided=$($null -ne $CachedAlbums)"
        $searchAlbumsParams = @{
            Provider            = $Provider
            ArtistId            = $ProviderArtist.id
            ArtistName          = $ProviderArtist.name
            AlbumName           = $AlbumName
            MastersOnly         = ($Provider -eq 'Discogs')
            AllAlbumsCache      = $CachedAlbums
            FallbackToAllAlbums = $true
        }

        $albumsForArtist = Invoke-ProviderSearchAlbums @searchAlbumsParams
        $albumsForArtist = @($albumsForArtist)  # Ensure array

        Write-Verbose "Search returned: $($albumsForArtist.Count) albums"
        if ($albumsForArtist.Count -gt 0) {
            Write-Host "✓ Found $($albumsForArtist.Count) albums" -ForegroundColor Green
        } else {
            Write-Host "No albums found for artist id $($ProviderArtist.id)."
        }
    }

    Clear-Host
    # sort by Jaccard similarity descending
    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }

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

        $providerArtistName = Get-IfExists $ProviderArtist 'name'
        Write-Host "Albums for artist $providerArtistName :"
        Write-Host "for local album: $($AlbumName) (year: $Year)"
        $totalPages = [math]::Ceiling($albumsForArtist.Count / $pageSize)
        $startIdx = ($page - 1) * $pageSize
        $endIdx = [math]::Min($startIdx + $pageSize - 1, $albumsForArtist.Count - 1)

        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $albumName = Get-IfExists $albumsForArtist[$i] 'name'
            $albumId = Get-IfExists $albumsForArtist[$i] 'id'
            $albumYear = Get-IfExists $albumsForArtist[$i] 'release_date'
            Write-Host "[$($i+1)] $albumName  (id: $albumId) (year: $albumYear)"
        }

        # Non-interactive album selection: prefer explicit AlbumId, then goB, then AutoSelect or NonInteractive
        if ($AlbumId) {
            $ProviderAlbum = @{ id = $AlbumId; name = $AlbumId }
            return @{
                Action = 'Selected'
                ProviderAlbum = $ProviderAlbum
                CachedAlbums = $albumsForArtist
                MastersOnlyMode = $mastersOnlyMode
                Page = $page
                NextStage = 'C'
            }
        }
        if ($goB) {
            $ProviderAlbum = $albumsForArtist[0]
            return @{
                Action = 'Selected'
                ProviderAlbum = $ProviderAlbum
                CachedAlbums = $albumsForArtist
                MastersOnlyMode = $mastersOnlyMode
                Page = $page
                NextStage = 'C'
            }
        }
        if ($AutoSelect -or $NonInteractive) {
            $ProviderAlbum = $albumsForArtist[0]
            return @{
                Action = 'Selected'
                ProviderAlbum = $ProviderAlbum
                CachedAlbums = $albumsForArtist
                MastersOnlyMode = $mastersOnlyMode
                Page = $page
                NextStage = 'C'
            }
        }

        $inputF = Read-Host "Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), '(b)ack', '(n)ext', '(p)rev', '(s)kip', '(cp)' change provider, 'id:<id>', '*' (all albums), or text to search:"

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
                return @{
                    Action = 'Back'
                    CachedAlbums = $null
                    MastersOnlyMode = $mastersOnlyMode
                    Page = $page
                    NextStage = 'A'
                }
            }
            '^cp$' {
                Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
                Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
                $newProvider = Read-Host "Enter new provider name"
                if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                    return @{
                        Action = 'ProviderChanged'
                        Provider = $newProvider
                        CachedAlbums = $null
                        MastersOnlyMode = $mastersOnlyMode
                        Page = $page
                        NextStage = 'A'
                    }
                } else {
                    Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                    continue
                }
            }
            '^$' {
                $ProviderAlbum = $albumsForArtist[0]
                return @{
                    Action = 'Selected'
                    ProviderAlbum = $ProviderAlbum
                    CachedAlbums = $albumsForArtist
                    MastersOnlyMode = $mastersOnlyMode
                    Page = $page
                    NextStage = 'C'
                }
            }
            '^id:(.+)$' {
                $id = $matches[1]
                $ProviderAlbum = @{ id = $id; name = $id }
                return @{
                    Action = 'Selected'
                    ProviderAlbum = $ProviderAlbum
                    CachedAlbums = $albumsForArtist
                    MastersOnlyMode = $mastersOnlyMode
                    Page = $page
                    NextStage = 'C'
                }
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
                    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }
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
                $validIndices = @(
                    $selectedIndices |
                        Where-Object { $_ -ge 1 -and $_ -le $albumsForArtist.Count } |
                        Select-Object -Unique |
                        Sort-Object
                )

                if ($validIndices.Count -eq 0) {
                    Write-Warning "No valid album numbers selected"
                    continue
                }

                # If single selection, go directly to Stage C
                if ($validIndices.Count -eq 1) {
                    $ProviderAlbum = $albumsForArtist[$validIndices[0] - 1]
                    return @{
                        Action = 'Selected'
                        ProviderAlbum = $ProviderAlbum
                        CachedAlbums = $albumsForArtist
                        MastersOnlyMode = $mastersOnlyMode
                        Page = $page
                        NextStage = 'C'
                    }
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

                return @{
                    Action = 'Selected'
                    ProviderAlbum = $ProviderAlbum
                    CachedAlbums = $albumsForArtist
                    MastersOnlyMode = $mastersOnlyMode
                    Page = $page
                    NextStage = 'C'
                }
            }
            default {
                # User entered text - try as a new search term first
                Write-Host "Searching for albums matching: '$inputF'..." -ForegroundColor Cyan
                try {
                    $searchParams = @{
                        Provider    = $Provider
                        ArtistId    = $ProviderArtist.id
                        ArtistName  = $ProviderArtist.name
                        AlbumName   = $inputF
                        MastersOnly = ($Provider -eq 'Discogs')
                    }

                    $searchResults = Invoke-ProviderSearchAlbums @searchParams

                    if ($searchResults -and $searchResults.Count -gt 0) {
                        $albumsForArtist = @($searchResults)
                        $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $inputF -String2 $_.Name) }
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