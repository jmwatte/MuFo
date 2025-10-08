function Invoke-MuFoStageA {
    <#
    .SYNOPSIS
        Handles Stage A of the MuFo manual workflow: artist search and selection.

    .DESCRIPTION
        Searches for artists using the specified provider, displays candidates,
        and allows user selection or automatic selection based on parameters.

    .PARAMETER Artist
        The original artist name from the album folder.

    .PARAMETER ArtistQuery
        The search query to use (may differ from Artist for retries).

    .PARAMETER Provider
        The music provider to use (Spotify, Qobuz, Discogs).

    .PARAMETER ArtistId
        Optional explicit artist ID to select directly.

    .PARAMETER GoA
        If specified, automatically select the first artist candidate.

    .PARAMETER AutoSelect
        If specified, automatically select the first artist candidate.

    .PARAMETER NonInteractive
        If specified, run in non-interactive mode (no user prompts).

    .PARAMETER CachedAlbums
        Reference to cached albums (will be cleared if provider changes).

    .PARAMETER CachedArtistId
        Reference to cached artist ID (will be updated).

    .OUTPUTS
        PSCustomObject with properties:
        - ProviderArtist: Selected artist object, or $null if skipped
        - Stage: Next stage to proceed to ('B' or 'A' for retry)
        - Provider: Updated provider (may change if user switches)
        - ShouldBreak: $true if album should be skipped
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Artist,

        [Parameter(Mandatory)]
        [string]$ArtistQuery,

        [Parameter(Mandatory)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs')]
        [string]$Provider,

        [Parameter()]
        [string]$ArtistId,

        [Parameter()]
        [switch]$GoA,

        [Parameter()]
        [switch]$AutoSelect,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [ref]$CachedAlbums,

        [Parameter()]
        [ref]$CachedArtistId
    )

    Clear-Host
    Write-Host "Original artist: $Artist" -ForegroundColor Cyan

    try {
        $r = Invoke-ProviderSearch -Provider $Provider -query $ArtistQuery -Type artist
    }
    catch {
        Write-Warning "Search failed: $_"
        $r = $null
    }

    $candidates = @()
    if ($value = Get-IfExists $r.artists "items") {
        $candidates = $value
    }
    # Normalize to array so .Count is available even for single-item responses
    $candidates = @($candidates)

    if (-not $candidates -or $candidates.Count -eq 0) {
        Write-Host "No artist candidates found for '$ArtistQuery'."
        if ($NonInteractive) {
            Write-Warning "NonInteractive: skipping album because no artist candidates were found for '$ArtistQuery'."
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $true
            }
        }

        $inputF = Read-Host "Enter new search, 'skip' to skip album, 'cp' to change provider, or 'id:<id>' to select by id"
        if ($inputF -eq 'skip') {
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $true
            }
        }

        if ($inputF -eq 'cp') {
            Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
            Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
            $newProvider = Read-Host "Enter new provider name"
            if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
                $Provider = $newProvider
                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                $CachedAlbums.Value = $null
                $CachedArtistId.Value = $null
                return [PSCustomObject]@{
                    ProviderArtist = $null
                    Stage = 'A'
                    Provider = $Provider
                    ShouldBreak = $false
                }
            } else {
                Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                return [PSCustomObject]@{
                    ProviderArtist = $null
                    Stage = 'A'
                    Provider = $Provider
                    ShouldBreak = $false
                }
            }
        }

        if ($inputF -like 'id:*') {
            $id = $inputF.Substring(3)
            $ProviderArtist = @{ id = $id; name = $id }
            return [PSCustomObject]@{
                ProviderArtist = $ProviderArtist
                Stage = 'B'
                Provider = $Provider
                ShouldBreak = $false
            }
        }

        if ($inputF) {
            # Return with updated query for retry
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $false
                NewArtistQuery = $inputF
            }
        } else {
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $false
            }
        }
    }

    Write-Host "Artist candidates for '$ArtistQuery':"
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $candidateName = Get-IfExists $candidates[$i] 'name'
        $candidateGenres = Get-IfExists $candidates[$i] 'genres'
        $candidateId = Get-IfExists $candidates[$i] 'id'
        Write-Host "[$($i+1)] $candidateName - $($candidateGenres -join ', ') (id: $candidateId)"
    }

    # Non-interactive selection: prefer explicit ArtistId, then goA, then AutoSelect/NonInteractive
    if ($ArtistId) {
        $ProviderArtist = @{ id = $ArtistId; name = $ArtistId }
        return [PSCustomObject]@{
            ProviderArtist = $ProviderArtist
            Stage = 'B'
            Provider = $Provider
            ShouldBreak = $false
        }
    }

    if ($GoA) {
        $ProviderArtist = $candidates[0]
        return [PSCustomObject]@{
            ProviderArtist = $ProviderArtist
            Stage = 'B'
            Provider = $Provider
            ShouldBreak = $false
        }
    }

    if ($AutoSelect -or $NonInteractive) {
        $ProviderArtist = $candidates[0]
        return [PSCustomObject]@{
            ProviderArtist = $ProviderArtist
            Stage = 'B'
            Provider = $Provider
            ShouldBreak = $false
        }
    }

    $inputF = Read-Host "Select artist [1] (Enter=first), number, 'skip', 'cp' to change provider, 'id:<id>', or new search term:"
    if ($inputF -eq '') {
        $ProviderArtist = $candidates[0]
        return [PSCustomObject]@{
            ProviderArtist = $ProviderArtist
            Stage = 'B'
            Provider = $Provider
            ShouldBreak = $false
        }
    }

    if ($inputF -eq 'cp') {
        Write-Host "`nCurrent provider: $Provider" -ForegroundColor Cyan
        Write-Host "Available providers: Spotify, Qobuz, Discogs" -ForegroundColor Gray
        $newProvider = Read-Host "Enter new provider name"
        if ($newProvider -in @('Spotify', 'Qobuz', 'Discogs')) {
            $Provider = $newProvider
            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
            $CachedAlbums.Value = $null
            $CachedArtistId.Value = $null
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $false
            }
        } else {
            Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $false
            }
        }
    }

    if ($inputF -like 'id:*') {
        $id = $inputF.Substring(3)
        $ProviderArtist = @{ id = $id; name = $id }
        return [PSCustomObject]@{
            ProviderArtist = $ProviderArtist
            Stage = 'B'
            Provider = $Provider
            ShouldBreak = $false
        }
    }

    if ($inputF -match '^\d+$') {
        $idx = [int]$inputF
        if ($idx -ge 1 -and $idx -le $candidates.Count) {
            $ProviderArtist = $candidates[$idx - 1]
            return [PSCustomObject]@{
                ProviderArtist = $ProviderArtist
                Stage = 'B'
                Provider = $Provider
                ShouldBreak = $false
            }
        } else {
            Write-Warning "Invalid selection"
            return [PSCustomObject]@{
                ProviderArtist = $null
                Stage = 'A'
                Provider = $Provider
                ShouldBreak = $false
            }
        }
    }

    if ($inputF -eq 'skip') {
        return [PSCustomObject]@{
            ProviderArtist = $null
            Stage = 'A'
            Provider = $Provider
            ShouldBreak = $true
        }
    }

    # User entered new search term
    return [PSCustomObject]@{
        ProviderArtist = $null
        Stage = 'A'
        Provider = $Provider
        ShouldBreak = $false
        NewArtistQuery = $inputF
    }
}