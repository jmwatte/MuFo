# Detailed per-track diagnostic
Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\Private"

$html = Get-Content 'QTracksForAlbum - Copy.txt' -Raw | ConvertFrom-Html

# Labels
$labelNodes = $html.SelectNodes("//p[@data-disk]")
$textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")
$lnCount = 0; if ($labelNodes) { $lnCount = $labelNodes.Count }
$tlnCount = 0; if ($textLabelNodes) { $tlnCount = $textLabelNodes.Count }
Write-Output "Label nodes: $lnCount  TextLabel nodes: $tlnCount"
if ($labelNodes) { foreach ($ln in $labelNodes) { Write-Output ("Label Line=$($ln.Line) data-disk='" + $ln.GetAttributeValue('data-disk','') + "' text='" + ($ln.InnerText.Trim() -replace '\s+',' ') + "'") } }

# Tracks
$trackNodes = $html.SelectNodes("//*[@data-track]")
if (-not $trackNodes -or $trackNodes.Count -eq 0) { $trackNodes = $html.SelectNodes("//div[contains(@class,'track')]") }
$tnCount = 0; if ($trackNodes) { $tnCount = $trackNodes.Count }
Write-Output "Track nodes: $tnCount"

if (-not $trackNodes -or $trackNodes.Count -eq 0) { Write-Output 'No track nodes found'; exit 0 }

$max = [Math]::Min(50, ($trackNodes.Count -as [int]))
for ($i = 0; $i -lt $max; $i++) {
    $t = $trackNodes[$i]
    $line = $t.Line -as [int]
    $dataTrack = $t.GetAttributeValue('data-track','')
    $dataTrackV2 = $t.GetAttributeValue('data-track-v2','')
    $dataIndex = $t.GetAttributeValue('data-index','')
    Write-Output "--- Track #$i (Line=$line) data-track='$dataTrack' data-index='$dataIndex'"
    if ($dataTrackV2) { Write-Output "data-track-v2 present (len=$($dataTrackV2.Length))" }

    $nameNode = $t.SelectSingleNode(".//div[contains(@class,'track__item--name')]//span")
    $numberNode = $t.SelectSingleNode(".//div[contains(@class,'track__item--number')]//span")
    $altNameNode = $t.SelectSingleNode(".//div[contains(@class,'track__items')]//div[contains(@class,'track__item--name')]//span")

    # Safely compute text for each candidate
    if ($nameNode) { $nameText = "FOUND -> '" + ($nameNode.InnerText.Trim() -replace '\s+',' ') + "'" } else { $nameText = 'MISSING' }
    if ($altNameNode) { $altNameText = "FOUND -> '" + ($altNameNode.InnerText.Trim() -replace '\s+',' ') + "'" } else { $altNameText = 'MISSING' }
    if ($numberNode) { $numberText = "FOUND -> '" + ($numberNode.InnerText.Trim() -replace '\s+',' ') + "'" } else { $numberText = 'MISSING' }

    Write-Output ("nameNode: " + $nameText)
    Write-Output ("altNameNode: " + $altNameText)
    Write-Output ("numberNode: " + $numberText)

    # Check descendants that might contain title text (some pages put <span> directly)
    $spanTitle = $t.SelectSingleNode(".//span[normalize-space(text()) and string-length(normalize-space(text())) > 0]")
    if ($spanTitle) { Write-Output ("first span text: '" + ($spanTitle.InnerText.Trim() -replace '\s+',' ') + "'") }
}

Write-Output 'DIAG COMPLETE'