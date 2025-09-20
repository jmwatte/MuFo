# Invoke-MuFo Development Plan

This plan outlines the actionable steps to build the Invoke-MuFo PowerShell cmdlet for music library validation and tagging using Spotify (and potentially MusicBrainz). It reflects our brainstorming discussions, focusing on features like artist/album/track checks, modes (automatic/manual/smart), exclusions, logging, and user-friendly output. Each step includes checkboxes for tracking progress. Update as needed during development.

## Phase 1: Setup and Core Structure
- [ ] Create the MuFo module folder structure (e.g., subfolders for Logs, Exclusions, Providers).
- [ ] Set up the main Invoke-MuFo.psm1 file with basic cmdlet skeleton and parameter definitions (e.g., -Path, -DoIt, -ArtistAt, -ExcludeFolders, -LogTo, -Verbose, -Debug).
- [ ] Implement basic parameter validation (e.g., ValidateSet for -DoIt modes: Automatic, Manual, Smart; dynamic for -ExcludedFoldersLoad).
- [ ] Add module manifest (MuFo.psd1) with dependencies (e.g., TagLib-Sharp, Spotishell).

## Phase 2: Spotify Integration and Providers
- [ ] Integrate Spotishell for Spotify API calls (authentication, search for artists/albums/tracks).
- [ ] Implement artist search and matching logic (exact/fuzzy string matching, album verification for disambiguation).
- [ ] Add support for multiple variations (e.g., prompt user if discographies match exactly).
- [ ] Design provider abstraction layer for extensibility (default to Spotify, prepare for MusicBrainz).
- [ ] Handle API errors (e.g., network issues, rate limits) with retries and logging.

## Phase 3: File System and Tagging Logic
- [ ] Implement folder level assumptions (-ArtistAt for relative paths, with error messages for invalid levels).
- [ ] Add file scanning for audio files (use TagLib-Sharp for reading/writing tags).
- [ ] Implement validation logic: Check artist names, album matches, track tags against Spotify data.
- [ ] Handle special cases: Non-album tracks ([PLAYLIST] tag), box sets ([BOX] with -BoxMode), multiple artists (e.g., "Various Artists").
- [ ] Support -WhatIf for dry-run simulations of changes.

## Phase 4: User Interaction and Modes
- [ ] Implement -DoIt modes:
  - Automatic: Apply top match automatically.
  - Manual: Prompt for each change (Enter=accept, Esc=skip, Ctrl+C=quit).
  - Smart: Auto for high-confidence (exact match + albums), manual for doubts.
- [ ] Add confidence scoring (e.g., 100% for exact + albums, fuzzy matching with thresholds).
- [ ] Ensure prompts are non-blocking with escape options; use color coding (green=ok, red=error, dark yellow=doubt).

## Phase 5: Exclusions and Logging
- [ ] Implement -ExcludeFolders: Skip specified folders during scans.
- [ ] Add -ExcludedFoldersSave/-ExcludedFoldersLoad: Save/load exclusions to/from JSON files in Exclusions folder.
- [ ] Implement logging: Write results to JSON file (-LogTo), include categories (Success, Skipped, NothingFromSpotify, NetworkError, etc.).
- [ ] Add -ShowResults: Display logged results (filtered by category), with path, status, suggestion; use -Verbose for details, -Debug for API dumps.

## Phase 6: Output and Refinements
- [ ] Format output as indented JSON-like structure (avoid tables for screen width).
- [ ] Add progress indicators (Write-Progress) and ensure accessibility (auto-disable colors if unsupported).
- [ ] Implement -NoColor for plain text; separate UI colors from log colors.
- [ ] Add -OutputFormat for flexibility (e.g., List vs. Table).

## Phase 7: Testing and Validation
- [ ] Write unit tests for core functions (e.g., matching logic, API calls).
- [ ] Test on sample music libraries (small/large, with variations like typos, boxes).
- [ ] Validate edge cases: No subfolders, special characters in paths (use LiteralPath), ambiguous matches.
- [ ] Gather feedback on usability (e.g., prompt clarity, output readability).

## Phase 8: Documentation and Deployment
- [ ] Create README.md with usage examples, parameter descriptions, and troubleshooting.
- [ ] Add inline help (Get-Help Invoke-MuFo) with examples.
- [ ] Package for distribution (e.g., via PowerShell Gallery if desired).
- [ ] Plan for future features (e.g., MusicBrainz integration, GUI if complexity grows).