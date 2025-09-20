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

    try {
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

        # Quick outs
        if ([string]::IsNullOrEmpty($s1) -and [string]::IsNullOrEmpty($s2)) { return 1 }
        if ([string]::IsNullOrEmpty($s1) -or [string]::IsNullOrEmpty($s2)) { return 0 }

        # Work on explicit char arrays to avoid odd indexing semantics
        $a1 = $s1.ToCharArray()
        $a2 = $s2.ToCharArray()
        [int]$len1 = $a1.Length
        [int]$len2 = $a2.Length
        if ($len1 -eq 0 -and $len2 -eq 0) { return 1 }
        if ($len1 -eq 0 -or $len2 -eq 0) { return 0 }

        $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
        for ([int]$i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
        for ([int]$j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
        for ([int]$i = 1; $i -le $len1; $i++) {
            for ([int]$j = 1; $j -le $len2; $j++) {
                $cost = if ($a1[$i-1] -eq $a2[$j-1]) { 0 } else { 1 }
                $matrix[$i, $j] = [Math]::Min(
                    [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                    $matrix[$i-1, $j-1] + $cost
                )
            }
        }
        $distance = [int]$matrix[$len1, $len2]
        $maxLen = [int][Math]::Max($len1, $len2)
        if ($maxLen -eq 0) { return 1 }
        return [double](1.0 - ([double]$distance / [double]$maxLen))
    } catch {
        # Fallback: token overlap score (robust to unexpected shapes)
        try {
            $t1 = ([string]$String1).ToLowerInvariant() -split "[^a-z0-9]+" | Where-Object { $_.Length -ge 2 }
            $t2 = ([string]$String2).ToLowerInvariant() -split "[^a-z0-9]+" | Where-Object { $_.Length -ge 2 }
            if (-not $t1 -and -not $t2) { return 1 }
            if (-not $t1 -or -not $t2) { return 0 }
            $set1 = [System.Collections.Generic.HashSet[string]]::new()
            $set2 = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($x in $t1) { [void]$set1.Add($x) }
            foreach ($y in $t2) { [void]$set2.Add($y) }
            $inter = ($set1 | Where-Object { $set2.Contains($_) })
            $unionCount = ($set1.Count + $set2.Count - ($inter | Measure-Object).Count)
            if ($unionCount -le 0) { return 1 }
            return [double](($inter | Measure-Object).Count / $unionCount)
        } catch {
            # Last resort: relative length ratio
            try {
                $ls1 = ([string]$String1).Length
                $ls2 = ([string]$String2).Length
                $mx = [Math]::Max($ls1, $ls2)
                if ($mx -eq 0) { return 1 } else { return [double]([Math]::Min($ls1,$ls2) / $mx) }
            } catch { return 0 }
        }
    }
}