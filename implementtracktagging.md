# Implement Track Tagging (Read-Only Groundwork)

This step plan sets up safe, read-only track tag inspection using TagLib-Sharp, so we can validate tracks against the inferred artist/album before enabling writes later.

## Goals
- Add a helper to read basic tags (Artist, Album, Title, TrackNumber, Year, DiscNumber, MusicBrainzIds if present).
- Emit a concise per-track object, and integrate a summary into the album comparison results (counts/flags: missing tags, mismatched titles, etc.).
- Keep this read-only; no writes yet.

## Acceptance Criteria
- New Private function: `Get-AudioFileTags` that returns a normalized object for supported file types (.mp3, .flac, .m4a, .ogg, .wav where possible).
- Invoke-MuFo (optional gated by `-IncludeTracks`) collects tracks per album folder and aggregates simple validation metrics:
  - e.g., `TrackCountLocal`, `TracksWithMissingTitle`, `TracksMismatchedToSpotify` (placeholder until we wire Spotify tracks).
- Unit tests: mock TagLib-Sharp responses and validate our shapes and aggregation.

## Design
- Dependency: TagLib-Sharp (documented in the manifest/readme; tests can mock).
- Private function signature:
  - `Get-AudioFileTags -Path <folder or file>` returns a list of tag objects.
- Normalized tag shape fields: `Path, FileName, Artist, Album, Title, Track, Disc, Year, Duration`

## Step-by-step Implementation
1) Create Private/Get-AudioFileTags.ps1 with the function skeleton and basic file type filtering.
2) Load TagLib-Sharp via Add-Type or module requirement (document in README).
3) For each supported file, read tags and map to our normalized object; handle errors with warnings and skip the file.
4) In Invoke-MuFo, behind `-IncludeTracks`, scan album folders and compute simple aggregates; include in output when `-ShowEverything`.
5) Pester tests using mocks/fakes (don’t require real audio files).

## Notes
- Keep this safe and fast; skip large media beyond a set size threshold for now if needed.
- Later we can implement writes, but only after we’ve validated the inference end-to-end on more data.
