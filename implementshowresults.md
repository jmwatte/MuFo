# Implement Show Results (-ShowResults)

This step plan describes how to add a lightweight viewer for previous runs that wrote JSON logs via `-LogTo`.

## Goals
- Introduce a `-ShowResults` switch on Invoke-MuFo (or a small separate function) that reads the JSON file specified by `-LogTo` and prints a concise summary.
- Filtering: by Category/Action (rename, skip, error) and by Score threshold.
- Output shape: same concise objects as live Preview runs; `-ShowEverything` to expand.

## Acceptance Criteria
- When `-ShowResults -LogTo <file>` is provided, the cmdlet reads the JSON and outputs items.
- Optional filters: `-Action rename|skip|error`, `-MinScore <double>`.
- If the file doesn’t exist or is invalid JSON, warn and continue.

## Design
- Parameters:
  - `[switch] $ShowResults`
  - `[ValidateSet('rename','skip','error')] [string] $Action`
  - `[double] $MinScore = 0`
- JSON shape:
  - We already write: `{ Timestamp, Path, Mode, ConfidenceThreshold, Items: [...] }`
  - Each item contains: LocalFolder, LocalPath, NewFolderName, Action, Reason, Score, SpotifyAlbum

## Step-by-step Implementation
1) Add parameters to `Invoke-MuFo.ps1`.
2) At start of `process`, if `$ShowResults`:
   - Validate `-LogTo` path
   - Read JSON, parse to PSObject
   - Extract `.Items`
   - Apply filters (Action, MinScore)
   - Output concise or full objects based on `-ShowEverything`
   - `return` early (don’t run live analysis)
3) Add small tests that create a mock JSON file and validate outputs/filters.

## Notes
- Keep this simple; this is a utility viewer, not a TUI.
- If we later split this into a separate Public function (e.g., `Show-MuFoResults`), we can move it then.
