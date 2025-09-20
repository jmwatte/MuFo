# Invoke-MuFo Flow Diagram

This Mermaid diagram represents the high-level flow and logic for executing Invoke-MuFo, based on our discussions. It shows the main paths, decisions, and dependencies. Nodes represent steps, and arrows indicate transitions. Use this to visualize the process and identify bottlenecks.

```mermaid
flowchart TD
    A[Start: Invoke-MuFo] --> B[Parse Parameters<br>-Path, -DoIt, -ArtistAt, etc.]
    B --> C[Validate Inputs<br>e.g., Check -ArtistAt level exists]
    C --> D{Provider Setup<br>Default: Spotify<br>Optional: MusicBrainz}
    D --> E[Authenticate API<br>Handle tokens/errors]
    E --> F[Scan Folder Structure<br>Use LiteralPath for special chars]
    F --> G{Artist Folder Found?}
    G -->|No| H[Log Error: No folder at level<br>Exit]
    G -->|Yes| I[Search Spotify for Artist<br>Fuzzy/exact matching]
    I --> J{Matches Found?}
    J -->|No| K[Log: NothingFromSpotify<br>Skip or Manual Input]
    J -->|Yes| L{Exact Match + Albums Verify?}
    L -->|Yes| M[High Confidence<br>Proceed to Albums]
    L -->|No| N{Mode: Automatic/Manual/Smart}
    N -->|Automatic| O[Apply Top Match<br>Log Success]
    N -->|Manual/Smart| P[Prompt User<br>Enter=Accept, Esc=Skip]
    P --> Q{User Choice}
    Q -->|Accept| O
    Q -->|Skip| R[Log Skipped<br>Continue to Next]
    M --> S[Scan Albums<br>Check for [BOX] or Discs]
    S --> T{Box Set?}
    T -->|Yes| U[Apply -BoxMode<br>Validate as One or Split]
    T -->|No| V[Validate Album Names<br>Against Artist Discography]
    V --> W{Tracks Match?}
    W -->|No| X[Log Mismatch<br>Suggest Rename]
    W -->|Yes| Y[Read/Write Tags<br>Using TagLib-Sharp]
    Y --> Z{Tag Issues?}
    Z -->|Yes| AA[Log: Wrong/Missing Tags<br>Suggest Corrections]
    Z -->|No| BB[Log Success<br>Update Files if -DoIt]
    AA --> N
    X --> N
    BB --> CC[Handle Exclusions<br>-ExcludeFolders Applied]
    CC --> DD[Write to Log File<br>-LogTo with JSON]
    DD --> EE{End of Scan?}
    EE -->|No| FF[Next Item<br>Show Progress]
    EE -->|Yes| GG[Display Summary<br>Color-coded Output]
    GG --> HH[Optional: -ShowResults<br>Review Logged Data]
    HH --> II[End]
    K --> FF
    R --> FF
```