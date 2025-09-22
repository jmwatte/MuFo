# MuFo PowerShell Module - AI Coding Agent Instructions

## Development Approach - **ALWAYS REFLECT FIRST**
If I ask you to do something, reflect back in your words what you think I asked and wait for my feedback before carrying out anything. When I state a problem, first restate it in your own words and wait for my confirmation before proceeding.

## Project Overview
**MuFo** is a PowerShell module for music library validation and tagging using Spotify API. It validates folder structures (Artist/Album/Track), corrects naming inconsistencies, and enhances audio file tags with focus on classical music support.

### Target Environment
- PowerShell 7.3+ on Windows, Mac, and Linux
- External dependencies: Spotishell (Spotify API), TagLib-Sharp (.NET audio library)

## Core Architecture

### Main Entry Point
- **`Invoke-MuFo`** in `Public/Invoke-MuFo.ps1` - 700+ line function with extensive parameter validation
- Multiple execution modes: `-DoIt` (Automatic/Manual/Smart), `-Preview`, `-WhatIf`
- Rich parameter system: `-ArtistAt`, `-ExcludeFolders`, `-LogTo`, `-IncludeTracks`, `-FixTags`

### Key Private Functions (Modular Design)
- **Spotify Integration**: `Get-SpotifyAlbumMatches-Fast.ps1` (10-100x optimized), `Connect-Spotify.ps1`
- **Audio Processing**: `Get-AudioFileTags.ps1` (TagLib-Sharp wrapper), `Set-AudioFileTags.ps1`
- **Core Logic Modules**: `Invoke-MuFo-AlbumProcessing.ps1`, `Invoke-MuFo-ArtistSelection.ps1`, `Invoke-MuFo-Exclusions.ps1`
- **Classical Music**: Special composer/conductor handling, album artist optimization

### Performance & Testing Patterns
- **Custom test scripts**: `tests/test-*.ps1` pattern (not Pester framework)
- **Real-world validation**: Tests use actual Spotify API and audio files
- **Performance focus**: Memory optimization, API call minimization, confidence scoring
- **Debug scripts**: `debug/debug-*.ps1` for specific scenarios and issue reproduction

## Testing Requirements - **NEVER ASSUME CODE WORKS**
Always generate comprehensive and reliable tests that:
- Cover **all critical paths**, **edge cases**, and **error conditions**
- Include **positive and negative scenarios** with clear assertions
- Be **self-contained**, **repeatable**, and **free of external dependencies** unless required
- Use **mocking or stubbing** for isolating units (especially Spotify API)
- Validate **performance**, **security**, and **boundary behavior**
- Include brief explanation of test strategy and why cases are sufficient

**Never offer solutions without testing them first.** Set up test fixtures, validate solutions, and refine until the problem is solved.

## Development Workflow

### Planning Documents (Keep Updated)
- **`flow-mufo.md`**: Mermaid flowchart of execution logic
- **`plan-mufo.md`**: Phase-based development roadmap with checkboxes
- **Implementation docs**: `implement*.md` files for specific feature rollouts:
  - `implementexcludefolders.md` (wire exclusions and exclusions store)
  - `implementshowresults.md` (results viewer for -LogTo JSON)
  - `implementartistat.md` (folder level detection)
  - `implementtracktagging.md` (read-only track tagging groundwork)

### Module Structure (Standard PowerShell Pattern)
```
/MuFo
├── Public/           # Public functions exposed to users (Invoke-MuFo)
├── Private/          # Internal helper functions (modular, reusable)
├── MuFo.psm1        # Module loader (dot-sources all functions)
├── MuFo.psd1        # Module manifest (dependencies, exports)
├── lib/             # External libraries (TagLib-Sharp)
└── Exclusions/      # Persistent exclusion storage
```

### Function Organization Rules
- **One function per file** in Private/ and Public/
- **Verb-Noun naming** using approved PowerShell verbs
- **Comment-based help** for all public functions
- **Modular design**: Break complex operations into focused helper functions

### Error Handling & Logging Patterns
- Extensive use of `Write-Verbose`, `Write-Warning`, `Write-Debug`
- JSON logging via `-LogTo` with structured data format
- Color-coded console output with accessibility support (`-NoColor`)
- Memory optimization helpers for large music library processing

## Critical MuFo-Specific Knowledge

### Classical Music Specialization
- **Composer detection**: Advanced parsing in `Get-AudioFileTags` with `IncludeComposer`
- **Conductor recognition**: Album artist optimization for classical releases
- **Complex naming**: Multi-disc sets, box sets (`-BoxMode`), special characters in paths
- **String similarity**: Enhanced algorithms for matching classical album names with conductors

### Spotify Integration Optimizations
- **Fast search strategies**: Multiple query variations in `Get-SpotifyAlbumMatches-Fast.ps1`
- **API efficiency**: Batch operations, confidence thresholds to minimize calls
- **Rate limiting**: Built-in retry logic and error handling
- **Authentication**: Persistent token management via Spotishell

### Performance Patterns
- **Memory management**: Explicit cleanup in long-running operations (`Add-MemoryOptimization.ps1`)
- **Progress reporting**: Built-in progress bars for large collections
- **Exclusion system**: Wildcard pattern support with persistence
- **Confidence scoring**: Advanced similarity algorithms avoiding false positives

## AI Agent Development Guidelines

### Before Any Implementation
1. **Reflect the request** back in your own words
2. **Wait for confirmation** before proceeding
3. **Identify test scenarios** including edge cases
4. **Consider performance impact** on large music libraries

### When Adding Features
1. Update relevant `implement*.md` files
2. Add to `plan-mufo.md` roadmap with checkboxes
3. Create test script following `tests/test-*.ps1` pattern
4. Ensure classical music compatibility
5. Consider API efficiency and rate limiting

### Code Quality Standards
- **Parameter validation**: Use ValidateSet, ValidateScript with clear error messages
- **WhatIf support**: Full `$WhatIfPreference` integration for all destructive operations
- **Verbose output**: Comprehensive logging for troubleshooting
- **Error resilience**: Graceful degradation when external APIs fail

### Testing Commands
```powershell
# Load and test functions directly
.\tests\test-functions-simple.ps1

# Integration testing with real data
.\tests\test-integration.ps1
.\tests\test-performance.ps1

# Specific feature testing
.\tests\test-track-tagging.ps1
.\tests\test-wildcard-exclusions.ps1
```

### Post-Implementation Requirements
After successfully resolving an issue, suggest how the original prompt could be improved to obtain working code directly in the future, minimizing trial and error iterations.