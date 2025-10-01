Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\Private"

$Path = 'QTracksForAlbum - Copy.txt'
$html = Get-Content -Path $Path -Raw | ConvertFrom-Html

$labelNodes = $html.SelectNodes("//p[@data-disk]")
$textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")
$allLabelNodes = @{}
foreach ($n in @($labelNodes, $textLabelNodes) | Where-Object { $_ }) { foreach ($ln in $n) { $allLabelNodes[$ln.GetHashCode()] = $ln } }
$allLabelNodes = $allLabelNodes.Values

$trackNodes = $html.SelectNodes("//*[@data-track]")
if (-not $trackNodes -or $trackNodes.Count -eq 0) { $trackNodes = $html.SelectNodes("//div[contains(@class,'track')]") }

$combined = @()
if ($allLabelNodes) { foreach ($ln in $allLabelNodes) { $combined += [pscustomobject]@{ Type='label'; Node=$ln; Line=($ln.Line -as [int]) } } }
foreach ($tn in $trackNodes) { $combined += [pscustomobject]@{ Type='track'; Node=$tn; Line=($tn.Line -as [int]) } }
$combined = $combined | Sort-Object Line

$currentDisc = 1
Write-Output "Starting simulation: default currentDisc=$currentDisc"
foreach ($entry in $combined) {
    if ($entry.Type -eq 'label') {
        $node = $entry.Node
        $discAttr = $node.GetAttributeValue('data-disk','')
        Write-Output "LABEL at Line=$($entry.Line) discAttr='$discAttr'"
        if (-not $discAttr) { $discText = $node.InnerText.Trim(); if ($discText -match '(?i)\\bDISQUE\\b\\s*(\\d+)') { $discAttr = $Matches[1] } }
        if ($discAttr -and $discAttr -match '^\\d+$') { $currentDisc = [int]$discAttr; Write-Output " -> currentDisc set to $currentDisc" }
        continue
    }

    $track = $entry.Node
    $idVal = $track.GetAttributeValue('data-track','')
    $discToUse = $currentDisc
    if (-not $discToUse) { $td = $track.GetAttributeValue('data-disk',''); if ($td -match '^\\d+$') { $discToUse = [int]$td } }
    Write-Output ("TRACK id=$idVal Line=$($entry.Line) discUsed=$discToUse")
}

Write-Output 'Simulation complete.'
