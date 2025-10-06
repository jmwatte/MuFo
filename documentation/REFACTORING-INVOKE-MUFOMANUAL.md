# Refactoring Plan: Invoke-MuFoManual

## Current State
- **1147 lines** in a single function
- **3 complex stages** (A: Artist Selection, B: Album Selection, C: Track Tagging)
- **Deep nesting**: switch → stage → while → switch → regex patterns
- **Mixed concerns**: UI, business logic, file I/O, API calls all in one place

## Refactoring Goals
1. **Modularity**: Break into focused, testable functions
2. **Maintainability**: Reduce cognitive load, improve readability
3. **Reusability**: Enable code reuse across Invoke-MuFo and Invoke-MuFoManual
4. **Testability**: Enable unit testing of individual components

---

## Proposed Refactoring Structure

### Phase 1: Extract Stage A - Artist Selection ✅ PARTIALLY DONE
**Target File**: `Private/manual/Invoke-MuFoManual-StageA.ps1`

**Function**: `Invoke-MuFoManual-ArtistSelection`

**Responsibilities**:
- Search for artist candidates
- Display artist list
- Handle user input (selection, new search, skip, id:)
- Return selected artist or exit signal

**Parameters**:
```powershell
param(
    [string]$ArtistQuery,
    [string]$Provider,
    [string]$ArtistId,      # For direct selection
    [switch]$AutoSelect,
    [switch]$NonInteractive,
    [switch]$goA
)

# Returns:
# @{
#     Action = 'Selected' | 'Skip' | 'NewSearch'
#     Artist = [PSCustomObject] (if Selected)
#     Query = [string] (if NewSearch)
# }
```

**Existing Helper**: `Invoke-MuFo-ArtistSelection.ps1` already exists but needs alignment

---

### Phase 2: Extract Stage B - Album Selection ⚠️ HIGH PRIORITY
**Target File**: `Private/manual/Invoke-MuFoManual-StageB.ps1`

**Function**: `Invoke-MuFoManual-AlbumSelection`

**Responsibilities**:
- Smart album search vs fetch all albums
- Display paginated album list with filter state indicator
- Handle user input:
  - Number selection (single or range)
  - Navigation (next, prev, back)
  - Toggle (* for masters/all releases)
  - Text search
  - Skip, id: selection
- Return selected album(s) or navigation signal

**Parameters**:
```powershell
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$ProviderArtist,
    
    [Parameter(Mandatory)]
    [string]$AlbumName,
    
    [string]$Provider,
    [string]$AlbumId,        # For direct selection
    [int]$Year,
    [switch]$AutoSelect,
    [switch]$NonInteractive,
    [switch]$goB,
    
    # State management
    [array]$CachedAlbums,
    [bool]$MastersOnlyMode = $true
)

# Returns:
# @{
#     Action = 'Selected' | 'Back' | 'Skip'
#     Album = [PSCustomObject] (if Selected, can be combined album)
#     CachedAlbums = [array] (updated cache)
#     MastersOnlyMode = [bool] (updated toggle state)
# }
```

**Current Issues**:
- Lines 128-401 (~270 lines) in main function
- Complex nested logic for smart search → fallback → display → input handling
- Toggle state tracking just added, needs to be properly managed
- Multi-album selection logic (lines 288-374)

**Existing Helpers**:
- `Invoke-MuFo-AlbumProcessing.ps1` exists but serves different purpose
- Consider reusing parts of it

---

### Phase 3: Extract Stage C - Track Tagging ⚠️ HIGHEST COMPLEXITY
**Target File**: `Private/manual/Invoke-MuFoManual-StageC.ps1`

**Function**: `Invoke-MuFoManual-TrackTagging`

**Responsibilities**:
- Load audio files and tags
- Fetch provider tracks
- Pair local files with provider tracks (multiple sort methods)
- Display track pairing UI
- Handle commands:
  - Sort method changes (d, t, n, l, h, m)
  - Reverse source (r)
  - WhatIf toggle (w)
  - Save operations (st, sf, sa)
  - Range-based tag editing (1..8 +composer Bach)
  - Back, Skip
- Execute save operations (tags and/or folder)

**Parameters**:
```powershell
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$ProviderArtist,
    
    [Parameter(Mandatory)]
    [PSCustomObject]$ProviderAlbum,
    
    [Parameter(Mandatory)]
    [System.IO.DirectoryInfo]$AlbumFolder,
    
    [string]$Provider,
    [string]$AlbumName,
    [int]$Year,
    
    [switch]$NonInteractive,
    [switch]$goC,
    [switch]$ReverseSource,
    [bool]$UseWhatIf
)

# Returns:
# @{
#     Action = 'Completed' | 'Back' | 'Skip'
#     AlbumFolder = [DirectoryInfo] (updated if moved)
#     WhatIf = [bool] (current state)
# }
```

**Current Issues**:
- Lines 402-1125 (~720 lines) in main function
- Massive switch statement with 12+ command handlers
- TagLib file handle management complexity
- Folder move + audio file reload logic
- Range-based tag editing (lines 996-1125)

**Sub-extraction Opportunities**:
1. **Audio File Loading** → `Get-AudioFilesWithTags.ps1` (already exists?)
2. **Track Pairing** → `Set-Tracks.ps1` (already exists)
3. **Save Tags** → `Save-AudioFileTags.ps1` (combine logic from st/sa commands)
4. **Move Folder** → `Move-AlbumFolder.ps1` (already exists)
5. **Range Tag Editing** → `Set-AudioFileTagRange.ps1` (new helper)

---

## Phase 4: Extract Common UI Functions

### 4.1 Paginated List Display
**Target File**: `Private/manual/Show-PaginatedList.ps1`

**Function**: `Show-PaginatedList`
```powershell
param(
    [array]$Items,
    [int]$Page,
    [int]$PageSize,
    [string]$Title,
    [scriptblock]$FormatItem,  # How to display each item
    [string]$StatusLine = ''   # e.g., "[Filter: MASTERS ONLY]"
)
```

Used by both Stage A (artist list) and Stage B (album list).

### 4.2 Input Parser
**Target File**: `Private/manual/Parse-UserInput.ps1`

**Function**: `Parse-UserInput`
```powershell
param(
    [string]$Input,
    [array]$ValidCommands,
    [int]$MaxIndex
)

# Returns:
# @{
#     Type = 'Command' | 'Index' | 'Range' | 'Text' | 'IdSelection'
#     Value = [object] (depends on Type)
# }
```

Handles parsing of:
- Commands (b, n, p, s, *, etc.)
- Single numbers (1)
- Ranges (1,3,5-8)
- ID selections (id:12345)
- Text searches

### 4.3 Multi-Selection Handler
**Target File**: `Private/manual/Expand-SelectionRange.ps1`

**Function**: `Expand-SelectionRange`
```powershell
param(
    [string]$Input,       # e.g., "1,3,5-8,12"
    [int]$MaxIndex
)

# Returns: @(1, 3, 5, 6, 7, 8, 12)
```

Currently duplicated in Stage B (album selection) and used in Stage C (range tag editing).

---

## Phase 5: Refactor Main Loop

After extracting stages, the main function becomes:

```powershell
function Invoke-MuFoManual {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # ... existing parameters ...
    )

    begin {
        # Initialize TagLib, validate path, etc.
        # (Keep this minimal)
    }

    process {
        $artist = Split-Path -Leaf $Path
        $albums = Get-ChildItem -LiteralPath $Path -Directory
        
        foreach ($album in $albums) {
            # Parse album name and year
            $albumInfo = Get-AlbumInfoFromFolder -Folder $album
            
            # Initialize state
            $state = @{
                Stage = 'A'
                ArtistQuery = $artist
                ProviderArtist = $null
                ProviderAlbum = $null
                CachedAlbums = $null
                MastersOnlyMode = $true
                UseWhatIf = $isWhatIf
            }
            
            # State machine: A → B → C
            $albumDone = $false
            while (-not $albumDone) {
                switch ($state.Stage) {
                    'A' {
                        $result = Invoke-MuFoManual-ArtistSelection `
                            -ArtistQuery $state.ArtistQuery `
                            -Provider $Provider `
                            -ArtistId $ArtistId `
                            -AutoSelect:$AutoSelect `
                            -NonInteractive:$NonInteractive `
                            -goA:$goA
                        
                        switch ($result.Action) {
                            'Selected' {
                                $state.ProviderArtist = $result.Artist
                                $state.Stage = 'B'
                            }
                            'NewSearch' {
                                $state.ArtistQuery = $result.Query
                            }
                            'Skip' {
                                $albumDone = $true
                            }
                        }
                    }
                    
                    'B' {
                        $result = Invoke-MuFoManual-AlbumSelection `
                            -ProviderArtist $state.ProviderArtist `
                            -AlbumName $albumInfo.Name `
                            -Year $albumInfo.Year `
                            -Provider $Provider `
                            -AlbumId $AlbumId `
                            -CachedAlbums $state.CachedAlbums `
                            -MastersOnlyMode $state.MastersOnlyMode `
                            -AutoSelect:$AutoSelect `
                            -NonInteractive:$NonInteractive `
                            -goB:$goB
                        
                        switch ($result.Action) {
                            'Selected' {
                                $state.ProviderAlbum = $result.Album
                                $state.CachedAlbums = $result.CachedAlbums
                                $state.MastersOnlyMode = $result.MastersOnlyMode
                                $state.Stage = 'C'
                            }
                            'Back' {
                                $state.Stage = 'A'
                            }
                            'Skip' {
                                $albumDone = $true
                            }
                        }
                    }
                    
                    'C' {
                        $result = Invoke-MuFoManual-TrackTagging `
                            -ProviderArtist $state.ProviderArtist `
                            -ProviderAlbum $state.ProviderAlbum `
                            -AlbumFolder $album `
                            -Provider $Provider `
                            -AlbumName $albumInfo.Name `
                            -Year $albumInfo.Year `
                            -ReverseSource:$ReverseSource `
                            -UseWhatIf $state.UseWhatIf `
                            -NonInteractive:$NonInteractive `
                            -goC:$goC
                        
                        switch ($result.Action) {
                            'Completed' {
                                $albumDone = $true
                                # Update album folder if moved
                                if ($result.AlbumFolder) {
                                    $album = $result.AlbumFolder
                                }
                            }
                            'Back' {
                                $state.Stage = 'B'
                            }
                            'Skip' {
                                $albumDone = $true
                            }
                        }
                    }
                }
            }
        }
    }

    end {
        return [PSCustomObject]@{
            Path      = $Path
            Completed = $true
            WhatIf    = $isWhatIf
        }
    }
}
```

**Result**: Main function reduces from 1147 lines → ~150 lines

---

## Implementation Priority

### Immediate (This Session)
1. ✅ **Implement toggle state tracking** (DONE)
2. 📝 **Create this refactoring plan** (IN PROGRESS)

### Next Session
3. **Phase 2: Extract Stage B** (highest priority)
   - Most complex state management (cache, toggle, pagination)
   - Just added new feature (toggle), good time to refactor
   - ~270 lines → separate function

### Follow-up Sessions
4. **Phase 4.3: Extract multi-selection logic**
   - Reusable across Stage B and Stage C
   - ~80 lines → separate function

5. **Phase 3: Extract Stage C** (largest refactor)
   - Break into sub-functions first (save tags, range edit)
   - ~720 lines → separate function + helpers

6. **Phase 1: Extract Stage A**
   - Simplest stage, do last
   - Align with existing `Invoke-MuFo-ArtistSelection.ps1`

7. **Phase 4: Extract common UI functions**
   - After stage extraction complete
   - Identify duplication and create shared helpers

8. **Phase 5: Refactor main loop**
   - Final step: clean up main function
   - Should be straightforward after stage extraction

---

## Testing Strategy

### For Each Extracted Function
1. **Create test file**: `tests/test-mufomanual-stageX.ps1`
2. **Mock dependencies**: Provider API calls, user input
3. **Test all paths**: 
   - Happy path (successful selection)
   - Edge cases (no results, invalid input)
   - Navigation (back, skip, next/prev)
   - Special commands (*, id:, search text)

### Integration Testing
- Test state transitions: A → B → C
- Test state persistence (cache, toggle mode)
- Test with real music folders and provider APIs

### Regression Testing
- Keep existing `launch-invoke-mufo.ps1` working
- Verify all commands still work (d, t, n, l, h, m, r, st, sf, sa)
- Test range-based tag editing (1..8 +composer Bach)

---

## Benefits After Refactoring

### Code Quality
- **1147 lines → ~150 lines** in main function
- **Single Responsibility**: Each function has one clear purpose
- **Testability**: Can unit test stages independently
- **Reduced nesting**: Max 3 levels instead of 6+

### Maintainability
- **Easier debugging**: Smaller functions, clearer scope
- **Easier to extend**: Add new commands without modifying 700+ line switch
- **Easier to understand**: Each stage self-contained

### Reusability
- Stage functions can be used by other tools
- UI helpers (pagination, input parsing) reusable across project
- Multi-selection logic available for other features

### Performance
- No performance impact (same logic, better organized)
- Potential for future optimization (parallel API calls, caching)

---

## Notes

### Existing Helpers to Leverage
- `Invoke-MuFo-ArtistSelection.ps1` - Align Stage A with this
- `Invoke-MuFo-AlbumProcessing.ps1` - Review for Stage B reuse
- `Set-Tracks.ps1` - Already used in Stage C
- `Move-AlbumFolder.ps1` - Already used in Stage C
- `Show-Tracks.ps1` - Already used in Stage C

### Compatibility Considerations
- Maintain **backward compatibility** with existing parameters
- Keep **NonInteractive mode** working for automation
- Preserve **WhatIf support** throughout all stages
- Maintain **provider abstraction** (Spotify, Discogs, Qobuz)

### Documentation Updates Needed
- Update `MANUAL-WORKFLOW-GUIDE.md` with new architecture
- Create architectural diagram showing stage flow
- Update `IMPLEMENTATION-STATUS.md` with refactoring progress
- Document new helper functions in `PARAMETER-REFERENCE.md`

---

## Decision Log

### Why Extract by Stage Instead of by Concern?
**Decision**: Extract by workflow stage (A, B, C) rather than by technical concern (UI, API, I/O).

**Rationale**:
- Stages have natural boundaries (user transitions A → B → C)
- Each stage has cohesive responsibility (artist selection, album selection, tagging)
- Easier to test complete workflows
- Matches user's mental model

**Alternative Considered**: Extract all UI code, all API code, all file I/O
- **Rejected**: Would split stage logic across multiple files, harder to follow workflow

### Why State Machine Pattern?
**Decision**: Use explicit state machine with state transitions in main loop.

**Rationale**:
- Makes workflow explicit and visible
- Easy to add new stages or modify transitions
- State is managed in one place (no hidden globals)
- Easier to test state transitions

**Alternative Considered**: Keep nested while loops and switches
- **Rejected**: Current nesting is too deep, hard to follow control flow
