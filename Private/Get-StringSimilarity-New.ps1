function Get-StringSimilarity {
<#
.SYNOPSIS
    Calculates the similarity between two strings using Levenshtein distance.

.DESCRIPTION
    This function computes the Levenshtein distance between two strings and returns a similarity score between 0 and 1.
    Uses a robust implementation that avoids PowerShell's multi-dimensional array indexing quirks.

.PARAMETER String1
    The first string.

.PARAMETER String2
    The second string.

.EXAMPLE
    Get-StringSimilarity -String1 "The Beatles" -String2 "Beatles"
    Returns: 0.6

.EXAMPLE
    Get-StringSimilarity -String1 "11cc" -String2 "10cc"
    Returns: 0.75
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $String1,

        [Parameter(Mandatory = $true)]
        $String2
    )

    # Normalize inputs to strings and guard against null/collections
    if ($null -eq $String1) { $String1 = '' }
    if ($null -eq $String2) { $String2 = '' }
    
    if ($String1 -is [System.Collections.IEnumerable] -and -not ($String1 -is [string])) {
        $String1 = -join ($String1 | ForEach-Object { $_ })
    }
    if ($String2 -is [System.Collections.IEnumerable] -and -not ($String2 -is [string])) {
        $String2 = -join ($String2 | ForEach-Object { $_ })
    }
    
    $s1 = [string]$String1
    $s2 = [string]$String2

    # Quick outs for edge cases
    if ([string]::IsNullOrEmpty($s1) -and [string]::IsNullOrEmpty($s2)) { return 1.0 }
    if ([string]::IsNullOrEmpty($s1) -or [string]::IsNullOrEmpty($s2)) { return 0.0 }
    if ($s1 -eq $s2) { return 1.0 }

    $len1 = $s1.Length
    $len2 = $s2.Length
    
    # Use single-dimensional arrays to avoid PowerShell's multi-dimensional indexing issues
    # We'll simulate a 2D matrix using the formula: index = row * (len2 + 1) + col
    $matrixSize = ($len1 + 1) * ($len2 + 1)
    $matrix = New-Object int[] $matrixSize
    
    # Helper function to get/set matrix values safely
    function Get-MatrixValue($row, $col) {
        return $matrix[$row * ($len2 + 1) + $col]
    }
    
    function Set-MatrixValue($row, $col, $value) {
        $matrix[$row * ($len2 + 1) + $col] = $value
    }
    
    # Initialize first row and column
    for ($i = 0; $i -le $len1; $i++) {
        Set-MatrixValue $i 0 $i
    }
    for ($j = 0; $j -le $len2; $j++) {
        Set-MatrixValue 0 $j $j
    }
    
    # Fill the matrix
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            # Get characters safely
            $char1 = $s1[$i - 1]
            $char2 = $s2[$j - 1]
            
            # Calculate cost (0 if characters match, 1 if they don't)
            $cost = if ($char1 -eq $char2) { 0 } else { 1 }
            
            # Get values from matrix safely
            $deletion = (Get-MatrixValue ($i - 1) $j) + 1
            $insertion = (Get-MatrixValue $i ($j - 1)) + 1
            $substitution = (Get-MatrixValue ($i - 1) ($j - 1)) + $cost
            
            # Find minimum and set value
            $min = [Math]::Min($deletion, [Math]::Min($insertion, $substitution))
            Set-MatrixValue $i $j $min
        }
    }
    
    # Get the final distance
    $distance = Get-MatrixValue $len1 $len2
    $maxLen = [Math]::Max($len1, $len2)
    
    # Calculate similarity as 1 - (distance / maxLength)
    if ($maxLen -eq 0) { return 1.0 }
    
    $similarity = 1.0 - ([double]$distance / [double]$maxLen)
    return [Math]::Max(0.0, $similarity)  # Ensure we don't return negative values
}