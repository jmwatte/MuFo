# MuFo Configuration Setup

## Getting API Credentials

### Spotify
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account
3. Click "Create App"
4. Fill in app name (e.g., "MuFo") and description
5. Copy your **Client ID** and **Client Secret**

### Qobuz
Qobuz API access is more restricted:
1. Contact Qobuz for API partnership: https://www.qobuz.com/us-en/discover
2. You may need to explain your use case
3. Once approved, you'll receive an **App ID** and **Secret**

### Discogs

**Recommended: Personal Access Token (Simplest)**
1. Go to [Discogs Developer Settings](https://www.discogs.com/settings/developers)
2. Log in with your Discogs account
3. Click "Generate new token" under "Personal access tokens"
4. Copy your **Personal Access Token**
5. Set it with: `Set-MuFoConfig -DiscogsToken "your_token"`

**Advanced: OAuth 1.0a (Complex)**
- If you have Consumer Key/Secret from creating an app, note that full OAuth 1.0a requires:
  - HMAC-SHA1 signature generation
  - Timestamp and nonce generation
  - Complex request signing
- For MuFo's purposes, Personal Access Token is simpler and equally functional
- Only needed if building a public app that requires user authorization flow

## Setting Up Configuration

### Option 1: Using PowerShell Commands (Recommended)

```powershell
# Set Spotify credentials
Set-MuFoConfig -SpotifyClientId "your_client_id" -SpotifyClientSecret "your_secret"

# Set Qobuz credentials
Set-MuFoConfig -QobuzAppId "your_app_id" -QobuzSecret "your_secret" -Merge

# Set Discogs credentials (recommended: Personal Access Token)
Set-MuFoConfig -DiscogsToken "your_personal_access_token" -Merge

# Alternative: OAuth credentials (requires OAuth 1.0a implementation)
# Set-MuFoConfig -DiscogsConsumerKey "your_key" -DiscogsConsumerSecret "your_secret" -Merge
```

The `-Merge` switch preserves existing configuration when adding new providers.

### Option 2: Manual Configuration File

1. Copy `config.example.json` to your user config directory:
   - **Windows**: `%USERPROFILE%\.mufo\config.json`
   - **Linux/Mac**: `~/.mufo/config.json`

2. Edit the file and replace placeholder values with your actual credentials:

```json
{
  "Spotify": {
    "ClientId": "abc123xyz789",
    "ClientSecret": "your_secret_here"
  },
  "Qobuz": {
    "AppId": "12345",
    "Secret": "your_qobuz_secret"
  },
  "Discogs": {
    "Token": "your_discogs_token"
  }
}
```

3. Save the file

### Option 3: Environment Variables

Set environment variables (useful for CI/CD or temporary use):

```powershell
# Windows PowerShell
$env:SPOTIFY_CLIENT_ID = "your_client_id"
$env:SPOTIFY_CLIENT_SECRET = "your_secret"
$env:QOBUZ_APP_ID = "your_app_id"
$env:QOBUZ_SECRET = "your_secret"
$env:DISCOGS_TOKEN = "your_personal_access_token"

# Alternative: OAuth (requires full OAuth 1.0a implementation)
# $env:DISCOGS_CONSUMER_KEY = "your_consumer_key"
# $env:DISCOGS_CONSUMER_SECRET = "your_consumer_secret"

# To set permanently (Windows):
[System.Environment]::SetEnvironmentVariable('SPOTIFY_CLIENT_ID', 'your_client_id', 'User')
[System.Environment]::SetEnvironmentVariable('SPOTIFY_CLIENT_SECRET', 'your_secret', 'User')
```

## Verifying Configuration

```powershell
# View all configuration
Get-MuFoConfig

# View specific provider
Get-MuFoConfig -Provider Spotify
Get-MuFoConfig -Provider Qobuz
Get-MuFoConfig -Provider Discogs
```

## Configuration Priority

MuFo loads configuration in the following order (later sources override earlier):

1. **Config file**: `~/.mufo/config.json` (or `%USERPROFILE%\.mufo\config.json`)
2. **Environment variables**: `$env:SPOTIFY_CLIENT_ID`, etc.
3. **Custom path**: Set via `$env:MUFO_CONFIG_PATH`

## Security Notes

- ✅ Config file is automatically set with restrictive permissions (user-only read/write)
- ✅ `config.json` is excluded from git via `.gitignore`
- ✅ Never commit real credentials to version control
- ✅ Use `config.example.json` as a template only

## Troubleshooting

### "No configuration found"
- Ensure you've run `Set-MuFoConfig` or created `~/.mufo/config.json`
- Check that the file contains valid JSON
- Try `Get-MuFoConfig -Verbose` to see where it's looking

### "Failed to authenticate"
- Verify your credentials are correct
- Check that you copied the full token/secret (no extra spaces)
- Ensure your API app is active (Spotify dashboard)
- For Discogs, ensure your token has the required permissions

### Permission Issues
- On Windows: Run as your regular user (not Administrator)
- On Linux/Mac: Check file permissions with `ls -la ~/.mufo/config.json`
- Should be: `-rw------- (600)` - only you can read/write
