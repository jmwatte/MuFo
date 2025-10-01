Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\Private"

$Path = 'QTracksForAlbum - Copy.txt'
$html = Get-Content -Path $Path -Raw | ConvertFrom-Html

Write-Output "Inspecting label nodes..."
$labelNodes = $html.SelectNodes("//p[@data-disk]")
$textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")

Write-Output "labelNodes count: $($labelNodes.Count)"
if ($labelNodes) { foreach ($ln in $labelNodes) { Write-Output ("LINE=$($ln.Line) data-disk='" + $ln.GetAttributeValue('data-disk','') + "' text='" + ($ln.InnerText.Trim() -replace '\s+',' ') + "'") } }

Write-Output "textLabelNodes count: $($textLabelNodes.Count)"
if ($textLabelNodes) { foreach ($ln in $textLabelNodes) { Write-Output ("LINE=$($ln.Line) text='" + ($ln.InnerText.Trim() -replace '\s+',' ') + "'") } }

$trackNodes = $html.SelectNodes("//*[@data-track]")
if (-not $trackNodes -or $trackNodes.Count -eq 0) { $trackNodes = $html.SelectNodes("//div[contains(@class,'track')]") }

Write-Output "trackNodes count: $($trackNodes.Count)"

$combined = @()
foreach ($ln in @($labelNodes, $textLabelNodes) | Where-Object { $_ }) { foreach ($n in $ln) { $combined += [pscustomobject]@{ Type='label'; Node=$n; Line=($n.Line -as [int]) } } }
foreach ($tn in $trackNodes) { $combined += [pscustomobject]@{ Type='track'; Node=$tn; Line=($tn.Line -as [int]) } }
$combined = $combined | Sort-Object Line

Write-Output "First 30 combined entries (Type / Line / id or text):"
$i=0
foreach ($e in $combined) {
    if ($i -ge 30) { break }
    if ($e.Type -eq 'label') { $n=$e.Node; Write-Output ("LABEL  Line=$($e.Line) data-disk='" + $n.GetAttributeValue('data-disk','') + "' text='" + ($n.InnerText.Trim() -replace '\s+',' ') + "'") }
    else {
        $n = $e.Node
        $id = $n.GetAttributeValue('data-track','')
        $titleNode = $n.SelectSingleNode('.//div[contains(@class,"track__item--name")]//span')
        if ($titleNode) { $title = ($titleNode.InnerText -replace '\s+',' ') } else { $title = '' }
        Write-Output ("TRACK  Line=$($e.Line) id='$id' title='$title'")
    }
    $i++
}

Write-Output "--- Done ---"
