function Get-SpotifyAlbumTracks {
<#
.SYNOPSIS
    Retrieves tracks from a Spotify album.

.DESCRIPTION
    This function fetches the track list for a given Spotify album ID using Spotishell.

.PARAMETER AlbumId
    The Spotify album ID.

.OUTPUTS
    Array of track objects with normalized properties.

.NOTES
    Requires Spotishell module to be loaded.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AlbumId
    )

    begin {
        # Ensure Spotishell is available
        if (-not (Get-Module -Name Spotishell -ErrorAction SilentlyContinue)) {
            Write-Warning "Spotishell module not available. Cannot retrieve Spotify tracks."
            return @()
        }
    }

    process {
        try {
            # Use Spotishell to get album tracks
            # Assuming Get-AlbumTracks or similar exists; fallback to Search-Item if needed
            $album = Get-Album -Id $AlbumId -ErrorAction Stop
            if ($album -and $album.Tracks -and $album.Tracks.Items) {
                $tracks = $album.Tracks.Items | ForEach-Object {
                    [PSCustomObject]@{
                        Id          = $_.Id
                        Name        = $_.Name
                        Artists     = $_.Artists | ForEach-Object { $_.Name }
                        TrackNumber = $_.TrackNumber
                        DiscNumber  = $_.DiscNumber
                        DurationMs  = $_.DurationMs
                        Duration    = [TimeSpan]::FromMilliseconds($_.DurationMs).TotalSeconds
                    }
                }
                return $tracks
            } else {
                Write-Verbose "No tracks found for album ID: $AlbumId"
                return @()
            }
        } catch {
            Write-Warning "Failed to retrieve tracks for album ID '$AlbumId': $($_.Exception.Message)"
            return @()
        }
    }
}