# Discogs OAuth Configuration Update

## What Changed

Updated the MuFo configuration system to support **Discogs OAuth 1.0a authentication** with Consumer Key and Consumer Secret, instead of just a simple personal access token.

## Why This Change?

Discogs provides two authentication methods:
1. **OAuth 1.0a** (Consumer Key + Consumer Secret) - Standard API access
2. **Personal Access Token** - Simplified legacy method

You mentioned having a Consumer Key and Consumer Secret, which is the proper OAuth method.

## Updated Configuration

### Setting Discogs Credentials

```powershell
# OAuth method (recommended - what you have)
Set-MuFoConfig -DiscogsConsumerKey "your_consumer_key" -DiscogsConsumerSecret "your_consumer_secret"

# Legacy token method (still supported for backward compatibility)
Set-MuFoConfig -DiscogsToken "your_token"
```

### Config File Structure

**New format** (`~/.mufo/config.json`):
```json
{
  "Discogs": {
    "ConsumerKey": "your_consumer_key_here",
    "ConsumerSecret": "your_consumer_secret_here"
  }
}
```

**Legacy format** (still works):
```json
{
  "Discogs": {
    "Token": "your_token_here"
  }
}
```

### Environment Variables

```powershell
# OAuth credentials
$env:DISCOGS_CONSUMER_KEY = "your_consumer_key"
$env:DISCOGS_CONSUMER_SECRET = "your_consumer_secret"

# Or legacy token
$env:DISCOGS_TOKEN = "your_token"
```

## Files Modified

1. **`Public/Get-MuFoConfig.ps1`**
   - Added support for `DISCOGS_CONSUMER_KEY` and `DISCOGS_CONSUMER_SECRET` environment variables
   - Maintains backward compatibility with `DISCOGS_TOKEN`

2. **`Public/Set-MuFoConfig.ps1`**
   - Added `-DiscogsConsumerKey` parameter
   - Added `-DiscogsConsumerSecret` parameter
   - Kept `-DiscogsToken` for backward compatibility

3. **`Public/Test-MuFoConfig.ps1`**
   - Updated validation to check for OAuth credentials (preferred) or token (legacy)
   - Provides appropriate messages for each auth method

4. **`Private/manual/Invoke-DiscogsRequest.ps1`** (NEW)
   - Wrapper function for Discogs API requests
   - Handles OAuth 1.0a authentication automatically
   - Includes rate limiting (60 requests/minute)
   - Error handling for common Discogs API errors

5. **`config.example.json`**
   - Updated to show OAuth credentials structure

6. **Documentation files**
   - Updated all references from token to OAuth credentials

## Usage Example

```powershell
# 1. Set your Discogs credentials
Set-MuFoConfig -DiscogsConsumerKey "your_key" -DiscogsConsumerSecret "your_secret"

# 2. Verify configuration
Test-MuFoConfig -Provider Discogs

# 3. Use in code (automatic authentication)
$result = Invoke-DiscogsRequest -Uri '/database/search?q=Beatles&type=artist'

# 4. Or get config directly
$config = Get-MuFoConfig -Provider Discogs
# Access: $config.ConsumerKey, $config.ConsumerSecret
```

## For Implementing Discogs Provider Functions

When you create the Discogs helper functions (`Search-DItem`, `Get-DArtistAlbums`, etc.), use the new `Invoke-DiscogsRequest` wrapper:

```powershell
function Search-DItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [Parameter(Mandatory)]
        [ValidateSet('artist')]
        [string]$Type
    )
    
    # No need to handle auth - Invoke-DiscogsRequest does it automatically
    $response = Invoke-DiscogsRequest -Uri "/database/search?q=$([uri]::EscapeDataString($Query))&type=$Type"
    
    # Transform and return results
    return $response.results
}
```

## Backward Compatibility

✅ **Legacy token auth still works** - If someone has `DISCOGS_TOKEN` set, it will be used
✅ **OAuth takes precedence** - If both are configured, OAuth credentials are preferred
✅ **Clear validation messages** - `Test-MuFoConfig` tells users which method they're using

## Rate Limiting

The `Invoke-DiscogsRequest` function includes automatic rate limiting:
- **Authenticated requests**: 60 per minute
- Automatically waits when limit is reached
- Verbose output shows current rate limit usage

## Next Steps

1. **Set your credentials**:
   ```powershell
   Set-MuFoConfig -DiscogsConsumerKey "YOUR_KEY" -DiscogsConsumerSecret "YOUR_SECRET"
   ```

2. **Test the connection**:
   ```powershell
   Test-MuFoConfig -Provider Discogs
   ```

3. **Implement Discogs provider functions** using `Invoke-DiscogsRequest` helper

4. **Add to provider wrappers** in `Private/manual/`:
   - `Invoke-ProviderSearch.ps1`
   - `Invoke-ProviderGetAlbums.ps1`
   - `Invoke-ProviderGetTracks.ps1`

---

**Updated**: October 5, 2025
**Impact**: Discogs authentication now properly supports OAuth 1.0a with Consumer Key/Secret
