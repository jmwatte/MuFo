Set-StrictMode -Version Latest
Set-Location -Path "$PSScriptRoot\..\Private"

$html = Get-Content 'QTracksForAlbum - Copy.txt' -Raw | ConvertFrom-Html
$tracks = $html.SelectNodes("//*[@data-track]")
Write-Output "Tracks count: $($tracks.Count)"
$t = $tracks[0]
Write-Output '---OUTERHTML START---'
Write-Output ($t.OuterHtml.Substring(0,[math]::Min(800,$t.OuterHtml.Length)))
Write-Output '---OUTERHTML END---'

$n = $t.SelectSingleNode(".//div[contains(@class,'track__item--name')]//span")
if ($n) { Write-Output ('FOUND NAME: ' + $n.InnerText.Trim()) } else { Write-Output 'NAME NODE NOT FOUND' }

$m = $t.SelectSingleNode(".//div[contains(@class,'track__item--number')]//span")
if ($m) { Write-Output ('FOUND NUMBER: ' + $m.InnerText.Trim()) } else { Write-Output 'NUMBER NODE NOT FOUND' }
