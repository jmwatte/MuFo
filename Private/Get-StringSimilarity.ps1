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
        [string]$String1,

        [Parameter(Mandatory = $true)]
        [string]$String2
    )

    # Simple implementation of Levenshtein distance
    $len1 = $String1.Length
    $len2 = $String2.Length

    if ($len1 -eq 0) { return if ($len2 -eq 0) { 1 } else { 0 } }
    if ($len2 -eq 0) { return 0 }

    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)

    for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
    for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }

    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
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