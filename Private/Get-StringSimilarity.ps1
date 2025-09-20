function Get-StringSimilarity {
<#
.SYNOPSIS
    Calculates the similarity between two strings using Levenshtein distance.

.DESCRIPTION
    This function computes the Levenshtein distance between two strings and returns a similarity score between 0 and 1.

.PARAMETER String1
    The first string.

.PARAMETER String2
    The second string.

.EXAMPLE
    Get-StringSimilarity -String1 "The Beatles" -String2 "Beatles"
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $String1,

        [Parameter(Mandatory = $true)]
        $String2
    )

    # Normalize inputs to strings and guard against null/arrays
    if ($null -eq $String1) { $String1 = '' }
    if ($null -eq $String2) { $String2 = '' }
    if ($String1 -is [array]) { $String1 = ($String1 -join ' ') }
    if ($String2 -is [array]) { $String2 = ($String2 -join ' ') }
    $String1 = [string]$String1
    $String2 = [string]$String2

    # Simple implementation of Levenshtein distance
    [int]$len1 = $String1.Length
    [int]$len2 = $String2.Length

    if ($len1 -eq 0) {
        if ($len2 -eq 0) { return 1 } else { return 0 }
    }
    if ($len2 -eq 0) { return 0 }

    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)

    for ([int]$i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
    for ([int]$j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }

    for ([int]$i = 1; $i -le $len1; $i++) {
        for ([int]$j = 1; $j -le $len2; $j++) {
            $cost = if ($String1[$i-1] -eq $String2[$j-1]) { 0 } else { 1 }
            $matrix[$i, $j] = [Math]::Min(
                [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                $matrix[$i-1, $j-1] + $cost
            )
        }
    }

    $distance = $matrix[$len1, $len2]
    $maxLen = [Math]::Max($len1, $len2)
    if ($maxLen -eq 0) { return 1 }
    return 1 - ($distance / $maxLen)
}