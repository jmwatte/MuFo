# Discogs Authentication Guide

## TL;DR - Recommended Approach

**Use Personal Access Token** - It's simpler and works perfectly for MuFo:

```powershell
# 1. Get token from https://www.discogs.com/settings/developers
# 2. Set it
Set-MuFoConfig -DiscogsToken "YOUR_PERSONAL_ACCESS_TOKEN"

# 3. Test it
Test-MuFoConfig -Provider Discogs
```

## Why Personal Access Token?

Discogs offers two authentication methods:

### 1. Personal Access Token ✅ **RECOMMENDED**
- **Simple**: One token, works immediately
- **Sufficient**: Full API access for reading public data
- **Rate Limit**: 60 requests/minute (authenticated)
- **Perfect for**: Music library management, metadata lookup, personal projects

### 2. OAuth 1.0a ⚠️ **COMPLEX**
- **Requires**: Consumer Key + Consumer Secret + OAuth signature generation
- **Complexity**: HMAC-SHA1 signatures, timestamps, nonces
- **Needed for**: Public apps that require user authorization flow
- **Overkill for**: Personal music library management

## If You Have OAuth Credentials (Consumer Key/Secret)

You mentioned having a Consumer Key and Consumer Secret. Here's what you can do:

### Option A: Get a Personal Access Token Instead (Easiest)

1. Go to https://www.discogs.com/settings/developers
2. Scroll to "Personal access tokens" section
3. Click "Generate new token"
4. Give it a description like "MuFo Music Library"
5. Copy the token
6. Set it in MuFo:
   ```powershell
   Set-MuFoConfig -DiscogsToken "YOUR_TOKEN_HERE"
   ```

### Option B: Implement Full OAuth 1.0a (Advanced)

If you want to use your OAuth credentials, you'll need to:

1. **Generate OAuth 1.0a signatures** for each request:
   - Base string creation
   - HMAC-SHA1 signature
   - Timestamp (Unix epoch)
   - Nonce (random string)
   - Parameter encoding

2. **Example signature generation** (pseudocode):
   ```
   oauth_consumer_key = "your_consumer_key"
   oauth_token = "" # Empty for application-only auth
   oauth_signature_method = "HMAC-SHA1"
   oauth_timestamp = current_unix_timestamp
   oauth_nonce = random_string
   oauth_version = "1.0"
   
   # Create signature base string
   # Create signature
   # Add to Authorization header
   ```

3. **PowerShell implementation would require**:
   - Custom HMAC-SHA1 function
   - URL encoding function
   - OAuth parameter sorting
   - Authorization header construction

## Current MuFo Support

MuFo currently supports:
- ✅ **Personal Access Token** - Fully functional
- ✅ **OAuth credentials storage** - Stores Consumer Key/Secret
- ⚠️ **OAuth signature generation** - Not yet implemented

## Configuration in MuFo

```powershell
# Current config stores both (but only token is used)
{
  "Discogs": {
    "Token": "your_personal_access_token",
    "ConsumerKey": "your_consumer_key",      # Stored but not used yet
    "ConsumerSecret": "your_consumer_secret"  # Stored but not used yet
  }
}
```

## Testing Your Configuration

```powershell
# Test with token
Set-MuFoConfig -DiscogsToken "YOUR_TOKEN"
Test-MuFoConfig -Provider Discogs

# You'll see:
# ✓ Discogs Personal Access Token valid
```

## Using Discogs in Code

Once configured with a token, use the helper function:

```powershell
# Search for artists
$artists = Invoke-DiscogsRequest -Uri '/database/search?q=Pink Floyd&type=artist'

# Get artist releases
$releases = Invoke-DiscogsRequest -Uri '/artists/123456/releases'

# Get release details
$release = Invoke-DiscogsRequest -Uri '/releases/789012'
```

The `Invoke-DiscogsRequest` function:
- Automatically adds your authentication
- Handles rate limiting (60 req/min)
- Provides error handling
- Sets proper headers

## Rate Limits

| Authentication Method | Rate Limit |
|-----------------------|-----------|
| Unauthenticated       | 25/minute |
| Personal Access Token | 60/minute |
| OAuth 1.0a            | 60/minute |

For MuFo's use case, 60 requests/minute is more than sufficient.

## Future OAuth 1.0a Support

If there's demand for full OAuth 1.0a support, it could be added with:
1. PowerShell OAuth 1.0a library/module
2. Custom signature generation functions
3. Updated `Invoke-DiscogsRequest` to generate signatures

However, for 99% of use cases, Personal Access Token is the better choice.

## Summary

**What you should do:**
1. Generate a Personal Access Token at https://www.discogs.com/settings/developers
2. Configure it: `Set-MuFoConfig -DiscogsToken "YOUR_TOKEN"`
3. Test it: `Test-MuFoConfig -Provider Discogs`
4. Use it: `Invoke-DiscogsRequest -Uri '/database/search?q=Beatles&type=artist'`

**Keep your OAuth credentials** for reference, but use the token for actual API access.

---

**Questions?** Check the [CONFIGURATION-GUIDE.md](CONFIGURATION-GUIDE.md) or [DISCOGS-OAUTH-UPDATE.md](DISCOGS-OAUTH-UPDATE.md)
