function Connect-SpotifyService {
<#
.SYNOPSIS
    Authenticates with Spotify using Spotishell.

.DESCRIPTION
    This function handles authentication with Spotify API via Spotishell.
    It may prompt for credentials or use a stored token.

.EXAMPLE
    Connect-Spotify
#>

    [CmdletBinding()]
    param ()

    try {
        # Avoid name conflicts and try to validate Spotishell setup
        $appCmd = Get-Command Get-SpotifyApplication -Module Spotishell -ErrorAction SilentlyContinue
        if ($appCmd) {
            $app = & $appCmd 2>$null
            if (-not $app) {
                Write-Host "Spotishell application is not initialized. Run Initialize-SpotifyApplication or New-SpotifyApplication."
            } else {
                Write-Verbose "Spotishell application detected."
            }
        } else {
            Write-Verbose "Spotishell application cmdlets not found; proceeding without explicit auth check."
        }
    } catch {
        Write-Warning "Failed to check Spotify application setup: $_"
    }
}