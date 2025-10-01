# Diagnostic script to inspect label and track nodes
Set-StrictMode -Version Latest
Set-Location -Path "${PSScriptRoot}\..\Private"

$html = Get-Content "QTracksForAlbum - Copy.txt" -Raw | ConvertFrom-Html
Write-Output "Html object type: $($html.GetType().FullName)"

$labelNodes = $html.SelectNodes("//p[@data-disk]")
$textLabelNodes = $html.SelectNodes("//p[contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISQUE') or contains(translate(normalize-space(.), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),'DISK')]")
$trackNodes = $html.SelectNodes("//*[@data-track] | //div[contains(@class,'track')]")

Write-Output "labelNodes: $([int]($labelNodes.Count))"
Write-Output "textLabelNodes: $([int]($textLabelNodes.Count))"
Write-Output "trackNodes: $([int]($trackNodes.Count))"

if ($labelNodes -and $labelNodes.Count -gt 0) {
    Write-Output "First label OuterHtml:"
    Write-Output ($labelNodes[0].OuterHtml.Substring(0, [Math]::Min(300, $labelNodes[0].OuterHtml.Length)))
}
if ($trackNodes -and $trackNodes.Count -gt 0) {
    Write-Output "First track OuterHtml:"
    Write-Output ($trackNodes[0].OuterHtml.Substring(0, [Math]::Min(300, $trackNodes[0].OuterHtml.Length)))
}
