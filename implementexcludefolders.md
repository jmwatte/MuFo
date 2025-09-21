# Implement Exclude Folders and Exclusions Store

This step plan describes how to implement folder exclusions in Invoke-MuFo and a small persistence layer to save/load exclusions lists.

## Goals
- Support `-ExcludeFolders` to skip specific subfolders during the local album scan.
- Add persisted exclusions via JSON in an `Exclusions` subfolder of the module path (opt-in):
  - `-ExcludedFoldersSave` — write current effective exclusions to JSON
  - `-ExcludedFoldersLoad` — merge (or replace) saved exclusions into the effective set
  - `-ExcludedFoldersShow` — display effective and persisted exclusions
- Keep behavior safe and explicit; don’t silently hide folders without user intent.

## Acceptance Criteria
- When `-ExcludeFolders 'Foo','Bar'` is provided, subfolders named `Foo` and `Bar` are not scanned for albums.
- If `-ExcludedFoldersLoad` is passed and a JSON file exists, the loaded list is combined with the session `-ExcludeFolders` (deduped), unless `-ExcludedFoldersReplace` is also passed, in which case the saved list replaces it.
- `-ExcludedFoldersSave` writes the effective set to disk as UTF-8 JSON.
- `-ExcludedFoldersShow` prints both the effective set and the saved set (if present).
- WhatIf/Preview behavior is unchanged except that excluded folders are not considered in comparisons or rename maps.
- Unit tests exist for: filter works, save/load roundtrip, show prints, replace vs merge.

## Design
- Parameters (Invoke-MuFo):
  - `[string[]] $ExcludeFolders`
  - `[switch]   $ExcludedFoldersSave`
  - `[switch]   $ExcludedFoldersLoad`
  - `[switch]   $ExcludedFoldersReplace` (optional; default merge)
  - `[switch]   $ExcludedFoldersShow`
- Storage file path:
  - `$storeDir = Join-Path $PSScriptRoot 'Exclusions'`
  - `$storeFile = Join-Path $storeDir 'excluded-folders.json'`
- Effective exclusions:
  - Start with `-ExcludeFolders` (or empty array)
  - If `-ExcludedFoldersLoad` and file exists: merge or replace
  - Deduplicate case-insensitively
- Apply filter at album scan time only (local directories):
  - Before building `$localAlbumDirs`, filter out where `$ExcludeFolders -contains $dir.Name` (case-insensitive)
- Show behavior:
  - If `-ExcludedFoldersShow`: output two lists with colored headers

## Step-by-step Implementation
1) Add new parameters in `Public/Invoke-MuFo.ps1` param block.
2) Create helper functions at top of Invoke-MuFo (begin block):
   - `Get-ExclusionsStorePath` (returns dir and file)
   - `Read-ExcludedFoldersFromDisk`
   - `Write-ExcludedFoldersToDisk`
   - All robust to missing directories; encode UTF-8.
3) In begin/process, compute effective exclusions:
   - `$effectiveEx = @($ExcludeFolders) + (load if requested)`
   - Normalize to case-insensitive HashSet for dedupe.
4) If `-ExcludedFoldersShow`: print lists and continue (don’t exit), using `Write-Host` headers (Cyan) and items (white) for clarity.
5) Apply filter:
   - After `Get-ChildItem -Directory`, add: `Where-Object { $effectiveEx -notcontains $_.Name }` (case-insensitive compare via HashSet)
6) If `-ExcludedFoldersSave`: write effective set to disk at the end of successful processing. (If you prefer, write early too.)
7) Update JSON logs to include `ExcludedFolders` (effective) for traceability.

## Test Plan (Pester)
- Unit: Exclusion filter
  - Create temp artist folder with subfolders A,B,C; run with `-ExcludeFolders B`; assert B is not in output objects and rename map.
- Unit: Save/Load roundtrip
  - Run with `-ExcludeFolders B -ExcludedFoldersSave`, then new run with `-ExcludedFoldersLoad`; assert B is excluded without specifying `-ExcludeFolders`.
- Unit: Replace vs Merge
  - Save `[B]`; then run with `-ExcludeFolders C -ExcludedFoldersLoad -ExcludedFoldersReplace`; assert only C is effective.
- Unit: Show
  - With a saved file and some session exclusions, run with `-ExcludedFoldersShow`; assert the two lists print.

## Notes
- Keep comparisons on folder display names (not full paths).
- Wildcard/glob exclusions are now supported using PowerShell's `-like` operator (* and ?).
  - Examples: 'E_*' excludes folders starting with 'E_', '*_Live' excludes folders ending with '_Live', 'Album?' excludes 'Album1', 'Album2', etc.
- Handle errors (JSON invalid or file locked) with warnings and continue.
