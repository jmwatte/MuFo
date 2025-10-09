# MuFo Configuration - Quick Reference

## Setup (One-time)

```powershell
# Set Spotify credentials
Set-MuFoConfig -SpotifyClientId "your_id" -SpotifyClientSecret "your_secret"

# Add Qobuz credentials (preserves existing config)
Set-MuFoConfig -QobuzAppId "your_app_id" -QobuzSecret "your_secret" -Merge

# Add Discogs token (recommended)
Set-MuFoConfig -DiscogsToken "your_token" -Merge
```

## Check Configuration

```powershell
# View all credentials (masked)
Get-MuFoConfig

# View specific provider
Get-MuFoConfig -Provider Spotify
Get-MuFoConfig -Provider Qobuz
Get-MuFoConfig -Provider Discogs

# Test and validate credentials
Test-MuFoConfig

# Test specific provider
Test-MuFoConfig -Provider Spotify
```

## File Locations

- **Windows**: `%USERPROFILE%\.mufo\config.json`
- **Linux/Mac**: `~/.mufo/config.json`
- **Example**: `config.example.json` (in module directory)

## Environment Variables (Alternative)

```powershell
$env:SPOTIFY_CLIENT_ID = "your_id"
$env:SPOTIFY_CLIENT_SECRET = "your_secret"
$env:QOBUZ_APP_ID = "your_app_id"
$env:QOBUZ_SECRET = "your_secret"
$env:DISCOGS_TOKEN = "your_token"
```

## Getting API Credentials

- **Spotify**: https://developer.spotify.com/dashboard
- **Qobuz**: Contact Qobuz for API partnership
- **Discogs**: https://www.discogs.com/settings/developers

## Full Documentation

See: `.\documentation\CONFIGURATION-GUIDE.md`
