function Get-StringSimilarity-Jaccard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)][object]$String1,
        [Parameter(Mandatory = $false)][object]$String2
    )

    $s1 = if ($null -eq $String1) { '' } else { [string]$String1 }
    $s2 = if ($null -eq $String2) { '' } else { [string]$String2 }

    function _tokenize([string]$in) {
        if ([string]::IsNullOrWhiteSpace($in)) { return @() }
        $in = $in.ToLowerInvariant()
        $matchesb = [regex]::Matches($in, '\p{L}[\p{L}\p{N}\-]*')
        $tokens = @()
        foreach ($m in $matchesb) {
            $t = $m.Value.Trim('-')
            if ($t -and -not ($tokens -contains $t)) { $tokens += $t }
        }
        return $tokens
    }

    $words1 = @(_tokenize $s1)
    $words2 = @(_tokenize $s2)

    if ($words1.Count -eq 0 -and $words2.Count -eq 0) { return 1.0 }
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) { return 0.0 }

    $set1 = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($w in $words1) { $set1.Add($w) | Out-Null }

    $set2 = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($w in $words2) { $set2.Add($w) | Out-Null }

    $intersection = 0
    foreach ($w in $set2) { if ($set1.Contains($w)) { $intersection++ } }

    $union = $set1.Count + $set2.Count - $intersection
    if ($union -eq 0) { return 0.0 }

    return [double]$intersection / $union
}