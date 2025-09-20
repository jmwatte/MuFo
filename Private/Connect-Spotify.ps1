function Connect-Spotify {
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
        # Try to connect using Spotishell's Connect-Spotify if available
        if (Get-Command Connect-Spotify -ErrorAction SilentlyContinue) {
            Connect-Spotify
            Write-Verbose "Connected to Spotify via Spotishell"
        } else {
            Write-Host "Spotishell Connect-Spotify not found. Please authenticate manually."
        }
    } catch {
        Write-Warning "Failed to connect to Spotify: $_"
    }
}