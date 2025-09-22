# Advanced Tag Enhancement Workflow
## Comprehensive Music Metadata Correction System

### 📋 **Overview**
This document outlines the complete workflow for handling music collections with varying degrees of metadata corruption, from simple gaps to completely "fucked up" collections requiring forensic analysis and human verification.

---

## 🎯 **Goals & Objectives**

### Primary Goals
1. **Automated Tag Enhancement** - Fix 80% of common metadata issues automatically
2. **Forensic Analysis** - Deep inspection using file properties when tags are unreliable
3. **Human-in-the-Loop Verification** - Fallback to manual verification for unsolvable cases
4. **Confidence-Based Processing** - Apply changes based on evidence strength
5. **Scalable Workflow** - Handle single albums to massive collections

### Success Metrics
- ✅ **90%+ accuracy** on well-formed collections
- ✅ **Detect and flag** problematic collections requiring deeper analysis
- ✅ **Provide actionable feedback** for manual intervention
- ✅ **Maintain audit trail** of all changes made

---

## 🔄 **Workflow Stages**

### **Stage 1: Standard Enhancement**
**Scope**: Collections with mostly correct metadata, minor gaps
**Logic**: Fix missing/obvious problems, preserve existing good data

```powershell
# Current Implementation
Invoke-MuFo -Path $albumPath -FixTags -FillMissingTitles -FillMissingYears
```

**Handles**:
- Missing titles, track numbers, years, genres
- Obvious placeholders ("test-missing-tags")
- Basic consistency issues

---

### **Stage 2: Logic Inversion (NEXT IMPLEMENTATION)**
**Scope**: Fix everything by default, exclude specific fields
**Problem**: Current logic requires specifying what TO fix
**Solution**: Specify what NOT to fix

```powershell
# Proposed New Logic
Invoke-MuFo -Path $albumPath -FixTags                    # Fix everything
Invoke-MuFo -Path $albumPath -FixTags -DontFix @('Genres', 'Years')  # Exclude specific fields
```

**Parameters**:
- `-FixTags` = Fix ALL metadata by default
- `-DontFix @('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')` = Exclude specific fields
- More intuitive for users wanting comprehensive fixes

---

### **Stage 3: Deep Forensic Analysis (FUTURE)**
**Scope**: Collections where existing tags are completely unreliable
**Triggers**: 
- High conflict detection
- Multiple duration matches
- Inconsistent album/artist data across tracks
- User explicitly requests deep analysis

```powershell
# Forensic Mode
Invoke-MuFo -Path $albumPath -FixTags -DeepAnalysis -ConfidenceThreshold 0.8
```

**Analysis Methods**:
1. **File Property Analysis**
   - Duration matching with Spotify
   - File size patterns
   - Filename pattern recognition
   - Directory order analysis

2. **Cross-Reference Validation**
   - Spotify track count vs file count
   - Total album duration validation
   - Track sequence pattern detection

3. **Confidence Scoring**
   - Duration match: 0.9 confidence
   - Filename pattern: 0.7 confidence
   - Position in directory: 0.5 confidence
   - Existing tag consistency: 0.3 confidence

**Outputs**:
- Confidence scores for each proposed change
- Conflict detection report
- Recommended actions

---

### **Stage 4: Human Verification Workflow (FUTURE)**
**Scope**: Cases where forensic analysis cannot reach high confidence
**Triggers**:
- Confidence scores below threshold
- Multiple files with identical durations
- Conflicting evidence from different sources

```powershell
# Generate Human Verification Assets
Invoke-MuFo -Path $albumPath -FixTags -HumanVerification -GeneratePlaylist
```

**Generated Assets**:

#### **1. Analysis Report** (`analysis-report.txt`)
```
ALBUM: Sheet Music by 10cc
STATUS: Requires Human Verification

CONFLICTS DETECTED:
- Track 3: Multiple candidates with 298s duration
- Track 7: Filename suggests "Hollywood" but duration matches "Baron Samedi"

CONFIDENCE SUMMARY:
- High confidence (>0.8): 6 tracks
- Medium confidence (0.5-0.8): 2 tracks  
- Low confidence (<0.5): 2 tracks
```

#### **2. Verification Playlist** (`verification-playlist.m3u`)
```
#EXTM3U
#EXTINF:298,VERIFY: Hotel vs Unknown Track (98% duration match)
C:\Music\10cc\test-missing-tags.mp3
#EXTINF:235,VERIFY: Wall Street Shuffle (95% confidence)
C:\Music\10cc\track01.mp3
```

#### **3. Editable Mapping File** (`track-mapping.txt`)
```
# HUMAN VERIFICATION REQUIRED
# Instructions: Play each track, verify title, reorder lines as needed
# Format: TrackNumber|FileName|ProposedTitle|Confidence|Notes

1|01-wallstreet.mp3|The Wall Street Shuffle|0.95|Duration+filename match
2|track02.mp3|The Worst Band in the World|0.88|Duration match only
3|test-missing-tags.mp3|Hotel|0.98|PERFECT duration match (298s)
4|old-wild-men.mp3|Old Wild Men|0.92|Filename+duration match
# ... continue for all tracks
```

#### **4. Verification Instructions** (`VERIFICATION-GUIDE.md`)
```markdown
# Human Verification Guide

## Steps:
1. Open `verification-playlist.m3u` in your media player
2. Play each track and verify the proposed title
3. Edit `track-mapping.txt` to correct any mistakes:
   - Move lines up/down to reorder tracks
   - Edit the ProposedTitle column for wrong titles
   - Add notes in the Notes column
4. Save the file and run: `Import-VerifiedMapping -Path track-mapping.txt`

## Tips:
- Focus on low-confidence tracks first
- Use duration as a guide - exact matches are usually correct
- Trust your ears over algorithms
```

#### **5. Import Corrected Mapping**
```powershell
# Apply Human-Verified Changes
Import-VerifiedMapping -Path "track-mapping.txt" -ApplyChanges -WhatIf
Import-VerifiedMapping -Path "track-mapping.txt" -ApplyChanges  # Execute
```

---

## 🧪 **Testing Strategy**

### **Test Collections**

#### **Level 1: Standard Collection**
- **Source**: Well-tagged album with 1-2 missing fields
- **Expected**: 100% automated success
- **Test**: `Invoke-MuFo -FixTags` should handle completely

#### **Level 2: Problematic Collection** 
- **Source**: 10cc album with "test-missing-tags.mp3"
- **Expected**: Detect issues, apply forensic analysis
- **Test**: Duration-based matching should identify Track 3

#### **Level 3: Chaos Collection**
- **Source**: Completely messed up album (wrong track numbers, titles, order)
- **Expected**: Flag for human verification
- **Test**: Generate verification workflow assets

#### **Level 4: Edge Cases**
- **Multiple albums in one folder**
- **Classical music with movements**
- **Compilation albums**
- **Live recordings with crowd noise**

### **Test Commands**
```powershell
# Test Suite
Test-TagEnhancement -Level Standard -Path "C:\TestMusic\GoodAlbum"
Test-TagEnhancement -Level Problematic -Path "C:\TestMusic\10cc"  
Test-TagEnhancement -Level Chaos -Path "C:\TestMusic\MessedUpAlbum"
Test-TagEnhancement -Level EdgeCases -Path "C:\TestMusic\ClassicalBoxSet"
```

---

## 📊 **Implementation Roadmap**

### **Phase 1: Logic Inversion** ⏳ NEXT
**Timeline**: 1-2 days
**Scope**: Reverse parameter logic to be more intuitive

**Tasks**:
- [ ] Add `-DontFix` parameter accepting string array
- [ ] Default `-FixTags` to fix ALL tag types
- [ ] Update parameter validation logic
- [ ] Update help documentation
- [ ] Test with existing collections

**Validation**:
```powershell
# These should be equivalent
Invoke-MuFo -FixTags -FillMissingTitles -FillMissingYears  # OLD
Invoke-MuFo -FixTags -DontFix @('Genres', 'Artists')      # NEW
```

### **Phase 2: Forensic Analysis** 🔮 FUTURE
**Timeline**: 1-2 weeks
**Scope**: Deep analysis using file properties

**Tasks**:
- [ ] Implement confidence scoring system
- [ ] Add duration-based track matching
- [ ] Create conflict detection algorithms
- [ ] Build comprehensive analysis reporting
- [ ] Add threshold-based decision making

### **Phase 3: Human Verification** 🔮 FUTURE  
**Timeline**: 2-3 weeks
**Scope**: Complete human-in-the-loop workflow

**Tasks**:
- [ ] Playlist generation (M3U, PLS formats)
- [ ] Editable mapping file creation
- [ ] Verification guide generation
- [ ] Import/apply corrected mappings
- [ ] Integration with popular media players

### **Phase 4: Advanced Features** 🔮 FUTURE
**Timeline**: 1-2 months
**Scope**: Enterprise-level features

**Tasks**:
- [ ] Batch processing for large collections
- [ ] Progress saving/resuming
- [ ] Multiple Spotify source comparison
- [ ] Machine learning confidence improvement
- [ ] GUI for verification workflow

---

## 🎛️ **Parameter Design**

### **Current Parameters** (Phase 1 Target)
```powershell
[Parameter()] [switch]$FixTags                    # Fix all tags by default
[Parameter()] [string[]]$DontFix                 # Exclude specific tag types
[Parameter()] [switch]$DeepAnalysis              # Use forensic analysis
[Parameter()] [switch]$HumanVerification         # Generate verification workflow
[Parameter()] [double]$ConfidenceThreshold = 0.8 # Minimum confidence for changes
```

### **Valid DontFix Values**
- `'Titles'` - Don't modify track titles
- `'TrackNumbers'` - Don't modify track numbers  
- `'Years'` - Don't modify release years
- `'Genres'` - Don't modify genre information
- `'Artists'` - Don't modify artist/album artist
- `'Albums'` - Don't modify album names

### **Usage Examples**
```powershell
# Fix everything (most common use case)
Invoke-MuFo -Path $album -FixTags

# Fix everything except genres (user has custom genre scheme)
Invoke-MuFo -Path $album -FixTags -DontFix @('Genres')

# Conservative approach - only fix obvious missing data
Invoke-MuFo -Path $album -FixTags -DontFix @('Years', 'Genres', 'Artists')

# Forensic analysis for problematic collection
Invoke-MuFo -Path $album -FixTags -DeepAnalysis -ConfidenceThreshold 0.9

# Generate human verification for unsolvable cases
Invoke-MuFo -Path $album -FixTags -HumanVerification -DeepAnalysis
```

---

## ✅ **Success Criteria**

### **Phase 1 (Logic Inversion)**
- [ ] All existing functionality preserved
- [ ] New parameter logic works intuitively
- [ ] Backward compatibility maintained
- [ ] Documentation updated
- [ ] Test cases pass

### **Phase 2 (Forensic Analysis)**
- [ ] Confidence scoring implemented
- [ ] Duration-based matching works
- [ ] Conflict detection accurate
- [ ] Performance acceptable (<30s per album)
- [ ] Analysis reports helpful

### **Phase 3 (Human Verification)**
- [ ] Playlist generation works in major players
- [ ] Mapping file format is user-friendly
- [ ] Import process is reliable
- [ ] Verification guide is clear
- [ ] Workflow saves significant time vs manual tagging

---

## 🔗 **Related Documentation**
- `implementtracktagging.md` - Original track tagging implementation
- `flow-mufo.md` - Overall MuFo workflow
- `PARAMETER-REFERENCE.md` - Complete parameter documentation
- `TRACK-TAGGING-DOCS.md` - Technical tagging details

---

*This document serves as the master plan for evolving MuFo from a basic tag fixer to a comprehensive music metadata management system capable of handling real-world chaos.*