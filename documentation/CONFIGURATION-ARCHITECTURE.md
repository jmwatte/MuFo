# MuFo Configuration Architecture

## Configuration Loading Flow

```mermaid
graph TD
    A[User calls Get-MuFoConfig] --> B{Check MUFO_CONFIG_PATH}
    B -->|Set| C[Load from custom path]
    B -->|Not set| D{Check ~/.mufo/config.json}
    D -->|Exists| E[Load from user config]
    D -->|Not exists| F{Check module/config.json}
    F -->|Exists| G[Load from module dir with warning]
    F -->|Not exists| H[Empty config]
    
    C --> I[Parse JSON]
    E --> I
    G --> I
    H --> I
    
    I --> J{Check Environment Variables}
    J --> K[Override with ENV vars if present]
    K --> L[Return config to caller]
    
    style C fill:#90EE90
    style E fill:#90EE90
    style G fill:#FFD700
    style H fill:#FFB6C1
    style L fill:#87CEEB
```

## Configuration Storage Flow

```mermaid
graph TD
    A[User calls Set-MuFoConfig] --> B{Config directory exists?}
    B -->|No| C[Create ~/.mufo/]
    B -->|Yes| D[Continue]
    C --> D
    
    D --> E{Merge flag set?}
    E -->|Yes| F[Load existing config]
    E -->|No| G[Start with empty config]
    
    F --> H[Merge new values]
    G --> H
    
    H --> I[Convert to JSON]
    I --> J[Write to config.json]
    J --> K{OS Type?}
    K -->|Unix| L[Set permissions 600]
    K -->|Windows| M[Set user-only ACL]
    
    L --> N[Success]
    M --> N
    
    style C fill:#FFD700
    style F fill:#90EE90
    style N fill:#87CEEB
```

## Provider Authentication Flow

```mermaid
graph TD
    A[Provider function called] --> B[Call Get-MuFoConfig -Provider X]
    B --> C{Config exists?}
    C -->|No| D[Throw error with instructions]
    C -->|Yes| E{All required fields present?}
    E -->|No| D
    E -->|Yes| F[Extract credentials]
    
    F --> G{Provider Type?}
    G -->|Spotify| H[Get Spotify Access Token]
    G -->|Qobuz| I[Qobuz API Call]
    G -->|Discogs| J[Add Discogs headers]
    
    H --> K[Make authenticated API request]
    I --> K
    J --> K
    
    K --> L{Success?}
    L -->|Yes| M[Return data]
    L -->|No| N[Throw auth error]
    
    style D fill:#FF6B6B
    style M fill:#90EE90
    style N fill:#FF6B6B
```

## Configuration Priority

```mermaid
graph LR
    A[Lowest Priority] --> B[Module config.json]
    B --> C[~/.mufo/config.json]
    C --> D[MUFO_CONFIG_PATH]
    D --> E[Environment Variables]
    E --> F[Highest Priority]
    
    style A fill:#FFB6C1
    style F fill:#90EE90
```

## File System Layout

```
User Home Directory
├── .mufo/                          # User config directory
│   └── config.json                 # Secure credentials (600 permissions)
│
MuFo Module Directory
├── Public/
│   ├── Get-MuFoConfig.ps1         # Retrieve credentials
│   ├── Set-MuFoConfig.ps1         # Save credentials
│   └── Test-MuFoConfig.ps1        # Validate credentials
├── Private/
│   └── [Provider helpers use Get-MuFoConfig]
├── config.example.json             # Template (safe to commit)
├── .gitignore                      # Excludes config.json
└── documentation/
    ├── CONFIGURATION-GUIDE.md      # Full setup guide
    └── CONFIG-QUICKREF.md          # Quick reference
```

## Security Model

```mermaid
graph TD
    A[Sensitive Credentials] --> B{Storage Method}
    B -->|File| C[~/.mufo/config.json]
    B -->|Environment| D[ENV Variables]
    
    C --> E[Restrictive Permissions]
    E --> F[chmod 600 Unix]
    E --> G[User-only ACL Windows]
    
    C --> H[Excluded from Git]
    H --> I[.gitignore entry]
    
    D --> J[Session-scoped or User-scoped]
    
    F --> K[✓ Secure]
    G --> K
    I --> K
    J --> K
    
    style A fill:#FF6B6B
    style K fill:#90EE90
```

## Usage Pattern for Developers

```powershell
# Pattern 1: Simple retrieval
function MyProviderFunction {
    $config = Get-MuFoConfig -Provider Spotify
    if (-not $config) { throw "Configure with Set-MuFoConfig" }
    
    # Use $config.ClientId, $config.ClientSecret
}

# Pattern 2: With validation
function MyProviderFunction {
    $config = Get-MuFoConfig -Provider Discogs
    
    if (-not $config -or -not $config.Token) {
        throw @"
Discogs not configured.
Run: Set-MuFoConfig -DiscogsToken 'your_token'
See: https://www.discogs.com/settings/developers
"@
    }
    
    # Use $config.Token
}

# Pattern 3: Testing
function Connect-MyProvider {
    # Test config before attempting connection
    $testResult = Test-MuFoConfig -Provider Spotify -SkipValidation
    
    if (-not $testResult.ConfigComplete) {
        throw "Incomplete Spotify configuration"
    }
    
    $config = Get-MuFoConfig -Provider Spotify
    # Proceed with connection...
}
```

## Extension Points

To add a new provider (e.g., "MusicBrainz"):

1. **Add to config structure**:
   ```json
   {
     "MusicBrainz": {
       "ApiKey": "your_key"
     }
   }
   ```

2. **Update `Get-MuFoConfig`** (automatic - uses JSON structure)

3. **Update `Set-MuFoConfig`**:
   ```powershell
   [Parameter(Mandatory = $false)]
   [string]$MusicBrainzApiKey
   ```

4. **Update `Test-MuFoConfig`**:
   ```powershell
   'MusicBrainz' {
       $result.ConfigComplete = ($providerConfig.ApiKey -ne $null)
       # Add validation logic...
   }
   ```

5. **Update ValidateSet** in provider wrappers:
   ```powershell
   [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
   ```
