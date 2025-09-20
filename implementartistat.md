# Implement -ArtistAt (Folder Level Detection)

This step plan describes adding support for relative folder level selection so users can point at deeper or higher directories and still have MuFo find the artist folder.

## Goals
- Support `-ArtistAt` values like `Here` (default), `1U`, `2U`, `1D`, `2D` to locate the artist folder level relative to `-Path`.
- Validate input and warn clearly when the resolved level doesn’t contain the expected artist folder.

## Acceptance Criteria
- `-ArtistAt Here` (or omitted): behave as today (`-Path` is the artist folder).
- `-ArtistAt 1U/2U`: move up N levels and treat that as the artist folder.
- `-ArtistAt 1D/2D`: when `-Path` points to a parent (e.g., library root), traverse down N levels and iterate artists.
- When traversal doesn’t find directories (e.g., a file or empty), warn and skip.

## Design
- Parameter: `[ValidateSet('Here','1U','2U','1D','2D')] [string] $ArtistAt = 'Here'`
- Resolution:
  - For `U` (up): use `Split-Path -Parent` repeatedly.
  - For `D` (down): list directories and either iterate (for 1D) or two-deep (for 2D). For 1D/2D we likely need to loop Invoke-MuFo per found artist folder.
- Output: when `D` modes are used, preserve the same concise object shape and WhatIf maps per artist.

## Step-by-step Implementation
1) Add parameter and simple resolver that computes a list of artist folder paths:
   - Here: single `-Path`
   - 1U/2U: compute parent(s) and return that one
   - 1D/2D: enumerate children (or grandchildren) folders and return many
2) If many: loop main analysis per artist folder path. Respect `-ExcludeFolders` and other flags in each.
3) Add guardrails/warnings when resolved folders don’t exist or are empty.
4) Pester tests for each mode with temporary directories.

## Notes
- If 1D/2D lists thousands of artists, print a short progress note and consider a `-First/-Skip` pair for paging (future).
