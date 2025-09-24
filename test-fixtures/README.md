# MuFo Album Matching Regression Test Suite

This test suite validates the album matching algorithm in MuFo to ensure consistent behavior and catch regressions when changes are made.

## Overview

The test suite uses a fixture-based approach with known artist/album combinations to test various matching scenarios:

- **Exact matches**: Perfect artist and album matches
- **Year mismatches**: Albums that exist but with different release years
- **Similar names**: Albums with similar but not identical names
- **Wrong artist scenarios**: Same album title by different artists (regression test for the Abdullah Ibrahim bug)
- **Classical music**: Composer name variations
- **Box sets**: Compilation and box set albums

## Test Structure

```
test-fixtures/
├── album-matching-tests.json    # Test case definitions with expected scores
├── test-album-matching-regression.ps1  # Main test script
└── [test scenario directories]
    ├── exact-match/             # Perfect matches
    ├── year-mismatch/           # Year differences
    ├── similar-names/           # Similar album names
    ├── wrong-artist-same-album/ # Same title, wrong artist
    ├── classical/               # Classical music
    └── box-set/                 # Box sets/compilations
```

## Running the Tests

From the `test-fixtures` directory:

```powershell
# Run all tests
.\test-album-matching-regression.ps1

# Run with verbose output
.\test-album-matching-regression.ps1 -Verbose

# Run with detailed match information
.\test-album-matching-regression.ps1 -Detailed
```

## Test Cases

### Exact Match - Miles Davis "Kind of Blue" (1959)
- **Expected**: Perfect match with year bonus (Score: 2.0)
- **Validates**: Correct artist + album + year matching

### Exact Match - The Beatles "Abbey Road" (1969)
- **Expected**: Perfect match with year bonus (Score: 2.0)
- **Validates**: Popular artist/album combinations

### Year Mismatch - Miles Davis "Kind of Blue" (1960)
- **Expected**: Good match without year bonus (Score: 1.0)
- **Validates**: Year bonus logic and fallback matching

### Similar Names - Bob Dylan "Like a Rolling Stone" (1965)
- **Expected**: Moderate match (Score: 0.34)
- **Validates**: Handling of album names that match song titles

### Wrong Artist Same Album - "Water From an Ancient Well" (1986)
- **Expected**: Low score due to artist penalty (Score: 0.2)
- **Validates**: Prevention of wrong-artist matches (regression test)

### Classical - Beethoven "Symphony No. 5" (1808)
- **Expected**: Moderate match (Score: 0.25)
- **Validates**: Classical music and composer name variations

### Box Set - The Beatles "The Beatles Stereo Box Set" (2009)
- **Expected**: Good match (Score: 0.88)
- **Validates**: Box set and compilation album matching

## Expected Scores

The test suite validates that:

1. **Perfect matches** score highest (2.0 with year bonus)
2. **Year mismatches** score well but lower (1.0 without bonus)
3. **Wrong artist matches** are heavily penalized (< 0.3)
4. **Similar names** get moderate scores based on similarity
5. **Classical music** handles name variations appropriately

## Maintenance

When making changes to the album matching algorithm:

1. Run the test suite to ensure no regressions
2. If expected behavior changes, update the `album-matching-tests.json` with new expected scores
3. Add new test cases for new scenarios or edge cases
4. The tolerance is set to ±0.3 to allow for minor scoring variations

## Integration with CI/CD

This test suite can be integrated into automated testing pipelines:

```powershell
# Example CI/CD integration
cd test-fixtures
.\test-album-matching-regression.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Album matching regression tests failed!"
    exit 1
}
```