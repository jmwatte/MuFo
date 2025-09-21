param($String1 = '11cc', $String2 = '10cc')

Write-Host "=== Debugging String Similarity ==="
Write-Host "Input: '$String1' vs '$String2'"

try {
    # Normalize inputs to strings and guard against null/collections
    if ($null -eq $String1) { $String1 = '' }
    if ($null -eq $String2) { $String2 = '' }
    $s1 = [string]$String1
    $s2 = [string]$String2
    Write-Host "Normalized: '$s1' vs '$s2'"

    # Quick outs
    if ([string]::IsNullOrEmpty($s1) -and [string]::IsNullOrEmpty($s2)) { Write-Host "Both empty"; return 1 }
    if ([string]::IsNullOrEmpty($s1) -or [string]::IsNullOrEmpty($s2)) { Write-Host "One empty"; return 0 }

    # Work on explicit char arrays to avoid odd indexing semantics
    $a1 = $s1.ToCharArray()
    $a2 = $s2.ToCharArray()
    [int]$len1 = $a1.Length
    [int]$len2 = $a2.Length
    Write-Host "Lengths: $len1 vs $len2"
    
    if ($len1 -eq 0 -and $len2 -eq 0) { Write-Host "Both zero length"; return 1 }
    if ($len1 -eq 0 -or $len2 -eq 0) { Write-Host "One zero length"; return 0 }

    Write-Host "Creating matrix..."
    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
    
    for ([int]$i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
    for ([int]$j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
    
    Write-Host "Calculating Levenshtein..."
    for ([int]$i = 1; $i -le $len1; $i++) {
        for ([int]$j = 1; $j -le $len2; $j++) {
            $char1 = $a1[$i-1]
            $char2 = $a2[$j-1]
            $cost = if ($char1 -eq $char2) { 0 } else { 1 }
            $matrix[$i, $j] = [Math]::Min(
                [Math]::Min(([int]$matrix[$i-1, $j]) + 1, ([int]$matrix[$i, $j-1]) + 1),
                ([int]$matrix[$i-1, $j-1]) + $cost
            )
        }
    }
    
    $distance = [int]$matrix[$len1, $len2]
    $maxLen = [int][Math]::Max($len1, $len2)
    Write-Host "Distance: $distance, MaxLen: $maxLen"
    
    if ($maxLen -eq 0) { Write-Host "MaxLen is 0"; return 1 }
    $result = [double](1.0 - ([double]$distance / [double]$maxLen))
    Write-Host "Final result: $result"
    return $result
    
} catch {
    Write-Host "ERROR in main calculation: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    return -1
}