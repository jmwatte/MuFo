# Temporary runner: independent implementation of document-order scan to verify parsing
Set-StrictMode -Version Latest
Set-Location -Path "${PSScriptRoot}\..\Private"

$html = Get-Content "QTracksForAlbum - Copy.txt" -Raw | ConvertFrom-Html
$labelNodes = $html.SelectNodes("//p[@data-disk]")
$textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")

$allLabel = @()
if ($labelNodes) { $allLabel += $labelNodes }
if ($textLabelNodes) { $allLabel += $textLabelNodes }

$trackNodes = $html.SelectNodes("//*[@data-track] | //div[contains(@class,'track')]")

Write-Output "Labels: $($allLabel.Count)  Tracks: $($trackNodes.Count)"

$combined = @()
foreach ($ln in $allLabel) { $combined += [pscustomobject]@{ Type='label'; Node=$ln; Line=($ln.Line -as [int]) } }
foreach ($tn in $trackNodes) { $combined += [pscustomobject]@{ Type='track'; Node=$tn; Line=($tn.Line -as [int]) } }
$combined = $combined | Sort-Object Line

$results = @()
$currentDisc = $null
foreach ($entry in $combined) {
    if ($entry.Type -eq 'label') {
        $n = $entry.Node
        $d = $n.GetAttributeValue('data-disk','')
        if (-not $d) { if ($n.InnerText -match '(?i)DISQUE\s*(\d+)') { $d = $Matches[1] } }
        if ($d -match '^\d+$') { $currentDisc = [int]$d }
        continue
    }
    $t = $entry.Node
    $id = $t.SelectSingleNode(".//input[@name='track_id']")
    $name = $t.SelectSingleNode(".//span[contains(@class,'track-name')]")
    $tnn = $t.SelectSingleNode(".//span[contains(@class,'track-number')]")
    if ($id -and $name -and $tnn) {
        $disc = $currentDisc
        if (-not $disc) { $td = $t.GetAttributeValue('data-disk',''); if ($td -match '^\d+$') { $disc = [int]$td } }
        $tn = ($tnn.InnerText -replace '[^0-9]','')
        $results += [pscustomobject]@{ id=$id.GetAttributeValue('value',''); name=$name.InnerText.Trim(); disc_number=$disc; track_number = if ($tn -match '^\d+$') {[int]$tn} else {$null} }
    }
}

$results | Select-Object id,name,disc_number,track_number | Format-Table -AutoSize
Write-Output "Count: $($results.Count)"

# Write to file
$results | ConvertTo-Json -Depth 4 | Out-File -FilePath "${PSScriptRoot}\get-tracks-temp.json" -Encoding utf8
Write-Output "WROTE: ${PSScriptRoot}\get-tracks-temp.json"