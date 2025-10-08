function Invoke-MuFoStageB {
    <#
    .SYNOPSIS
        Handles Stage B of the MuFo manual workflow: album search and selection.

    .DESCRIPTION
        Searches for albums by the selected artist, displays candidates with pagination,
        and allows user selection or automatic selection based on parameters.

    .PARAMETER ProviderArtist
        The selected artist object from Stage A.

    .PARAMETER AlbumName
        The local album name to match against.

    .PARAMETER Year
        The release year of the local album.

    .PARAMETER Provider
        The music provider to use (Spotify, Qobuz, Discogs).

    .PARAMETER AlbumId
        Optional explicit album ID to select directly.

    .PARAMETER GoB
        If specified, automatically select the first album candidate.

    .PARAMETER AutoSelect
        If specified, automatically select the first album candidate.

    .PARAMETER NonInteractive
        If specified, run in non-interactive mode (no user prompts).

    .PARAMETER CachedAlbums
        Reference to cached albums (will be updated).

    .PARAMETER CachedArtistId
        Reference to cached artist ID (will be updated).

    .PARAMETER Page
        Reference to current page number for pagination.

    .PARAMETER PageSize
        Number of albums to display per page.

    .PARAMETER MastersOnlyMode
        Reference to masters-only mode for Discogs (will be toggled).

    .OUTPUTS
        PSCustomObject with properties:
        - ProviderAlbum: Selected album object, or $null if going back
        - Stage: Next stage to proceed to ('C' or 'A' for back)
        - Provider: Updated provider (may change if user switches)
        - ShouldBreak: $true if album should be skipped
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProviderArtist,

        [Parameter(Mandatory)]
        [string]$AlbumName,

        [Parameter(Mandatory)]
        [string]$Year,

        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter()]
        [string]$AlbumId,

        [Parameter()]
        [switch]$GoB,

        [Parameter()]
        [switch]$AutoSelect,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [ref]$CachedAlbums,

        [Parameter()]
        [ref]$CachedArtistId,

        [Parameter()]
        [ref]$Page,

        [Parameter()]
        [int]$PageSize = 10,

        [Parameter()]
        [ref]$MastersOnlyMode
    )

    Clear-Host
    $artistName = Get-IfExists $ProviderArtist 'name'
    $artistId = Get-IfExists $ProviderArtist 'id'
    Write-Host "Searching for albums for artist: $artistName (id: $artistId)"

    # Clear cache if artist changed
    if ($CachedArtistId.Value -ne $ProviderArtist.id) {
        $CachedAlbums.Value = $null
        $CachedArtistId.Value = $ProviderArtist.id
    }

    # Try smart API search FIRST (fast, targeted results)
    Write-Host "Searching for albums matching: $AlbumName..." -ForegroundColor Cyan
    Write-Verbose "Trying smart search for: $AlbumName"
    Write-Verbose "Parameters: Provider=$Provider, ArtistId=$($ProviderArtist.id), ArtistName=$($ProviderArtist.name), AlbumName=$AlbumName, MastersOnly=$($Provider -eq 'Discogs'), CacheProvided=$($null -ne $CachedAlbums.Value)"
    $searchAlbumsParams = @{
        Provider            = $Provider
        ArtistId            = $ProviderArtist.id
        ArtistName          = $ProviderArtist.name
        AlbumName           = $AlbumName
        MastersOnly         = ($Provider -eq 'Discogs')
        AllAlbumsCache      = $CachedAlbums.Value
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
    Clear-Host
    # sort by Jaccard similarity descending
    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }

    while ($true) {
        # Show filter mode indicator for Discogs
        if ($Provider -eq 'Discogs') {
            $modeIndicator = if ($MastersOnlyMode.Value) {
                "[Filter: MASTERS ONLY - type '*' to include all releases]"
            } else {
                "[Filter: ALL RELEASES - type '*' for masters only]"
            }
            Write-Host $modeIndicator -ForegroundColor Yellow
        }

        $providerArtistName = Get-IfExists $ProviderArtist 'name'
        Write-Host "Albums for artist $providerArtistName :"
        Write-Host "for local album: $($AlbumName) (year: $Year)"
        $totalPages = [math]::Ceiling($albumsForArtist.Count / $PageSize)
        $startIdx = ($Page.Value - 1) * $PageSize
        $endIdx = [math]::Min($startIdx + $PageSize - 1, $albumsForArtist.Count - 1)

        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $albumNameDisplay = Get-IfExists $albumsForArtist[$i] 'name'
            $albumId = Get-IfExists $albumsForArtist[$i] 'id'
            $albumYear = Get-IfExists $albumsForArtist[$i] 'release_date'
            Write-Host "[$($i+1)] $albumNameDisplay  (id: $albumId) (year: $albumYear)"
        }

        # Non-interactive album selection: prefer explicit AlbumId, then goB, then AutoSelect or NonInteractive
        if ($AlbumId) {
            $ProviderAlbum = @{ id = $AlbumId; name = $AlbumId }
            return [PSCustomObject]@{
                ProviderAlbum = $ProviderAlbum
                Stage = 'C'
                Provider = $Provider
                ShouldBreak = $false
            }
        }
        if ($GoB) {
            $ProviderAlbum = $albumsForArtist[0]
            return [PSCustomObject]@{
                ProviderAlbum = $ProviderAlbum
                Stage = 'C'
                Provider = $Provider
                ShouldBreak = $false
            }
        }
        if ($AutoSelect -or $NonInteractive) {
            $ProviderAlbum = $albumsForArtist[0]
            return [PSCustomObject]@{
                ProviderAlbum = $ProviderAlbum
                Stage = 'C'
                Provider = $Provider
                ShouldBreak = $false
            }
        }

        $inputF = Read-Host "Select album(s) [1] (Enter=first), number(s) (e.g., 1,3,5-8), '(b)ack', '(n)ext', '(p)rev', '(s)kip', '(cp)' change provider, 'id:<id>', '*' (all albums), or text to search:"

        switch -Regex ($inputF) {
            '^n$' {
                if ($Page.Value -lt $totalPages) { $Page.Value++ }
                continue
            }
            '^p$' {
                if ($Page.Value -gt 1) { $Page.Value-- }
                continue
            }
            '^b$' {
                $CachedAlbums.Value = $null
                $CachedArtistId.Value = $null
                return [PSCustomObject]@{
                    ProviderAlbum = $null
                    Stage = 'A'
                    Provider = $Provider
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
                        ProviderAlbum = $null
                        Stage = 'A'
                        Provider = $Provider
                        ShouldBreak = $false
                    }
                } else {
                    Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                    continue
                }
            }
            '^$' {
                $ProviderAlbum = $albumsForArtist[0]
                return [PSCustomObject]@{
                    ProviderAlbum = $ProviderAlbum
                    Stage = 'C'
                    Provider = $Provider
                    ShouldBreak = $false
                }
            }
            '^id:(.+)$' {
                $id = $matches[1]
                $ProviderAlbum = @{ id = $id; name = $id }
                return [PSCustomObject]@{
                    ProviderAlbum = $ProviderAlbum
                    Stage = 'C'
                    Provider = $Provider
                    ShouldBreak = $false
                }
            }
            '^\*$' {
                # Toggle between Masters-only and All-releases for Discogs
                if ($Provider -eq 'Discogs') {
                    $MastersOnlyMode.Value = -not $MastersOnlyMode.Value
                    $modeText = if ($MastersOnlyMode.Value) { "MASTER releases only" } else { "ALL release types" }
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
                        $fetchParams['MastersOnly'] = $MastersOnlyMode.Value
                    }

                    $albumsForArtist = Invoke-ProviderGetAlbums @fetchParams
                    $albumsForArtist = @($albumsForArtist)
                    $albumsForArtist = $albumsForArtist | Sort-Object { - (Get-StringSimilarity-Jaccard -String1 $AlbumName -String2 $_.Name) }
                    $CachedAlbums.Value = $albumsForArtist
                    $Page.Value = 1

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
                    return [PSCustomObject]@{
                        ProviderAlbum = $ProviderAlbum
                        Stage = 'C'
                        Provider = $Provider
                        ShouldBreak = $false
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

                return [PSCustomObject]@{
                    ProviderAlbum = $ProviderAlbum
                    Stage = 'C'
                    Provider = $Provider
                    ShouldBreak = $false
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
                        $CachedAlbums.Value = $albumsForArtist
                        $Page.Value = 1
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
                    $Page.Value = 1
                    Write-Host "Filtered to $($filtered.Count) albums" -ForegroundColor Green
                    continue
                }
                else {
                    Write-Warning "No matches found for '$inputF'"
                    continue
                }
            }
        }
    }
}