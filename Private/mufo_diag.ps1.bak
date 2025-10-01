Import-Module PowerHTML -ErrorAction Stop
$htmlPath = 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html'
$html = Get-Content -Raw -Path $htmlPath
$doc = ConvertFrom-Html -Content $html
$discContainers = $doc.SelectNodes('//*[@data-disk]')
Write-Host "Disc containers found: $([int]($discContainers.Count))"
$idx = 0
foreach ($c in @($discContainers)) {
    $idx++
    $diskAttr = $c.GetAttributeValue('data-disk','')
    $discNum = 1
    if ($diskAttr -and $diskAttr -match '^\d+$') { $discNum = [int]$diskAttr } else { if ($c.InnerText -match '(\d+)') { $discNum = [int]$matches[1] } }
    Write-Host ("--- Container {0}: discNum={1} tag={2} class={3} ---" -f $idx, $discNum, $c.Name, ($c.GetAttributeValue('class','')))
    $nodesA = $c.SelectNodes('.//*[@data-track]')
    Write-Host ('  descendants[@data-track]: ' + ([int]($nodesA.Count)))
    $nodesB = $c.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
    Write-Host ('  descendants[.//div.track]: ' + ([int]($nodesB.Count)))

    $ancestor = $c.ParentNode
    $attempt = 0
    $nodesC = @()
    while ($ancestor -and $attempt -lt 6) {
        $attempt++
        $nodesC = $ancestor.SelectNodes('.//*[@data-track]')
        if ($nodesC -and $nodesC.Count -gt 0) { break }
        $nodesC = $ancestor.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        if ($nodesC -and $nodesC.Count -gt 0) { break }
        $ancestor = $ancestor.ParentNode
    }
    Write-Host ('  ancestor search found: ' + ([int]($nodesC.Count)))

    $following = $c.SelectNodes('following-sibling::*')
    Write-Host ('  following siblings count: ' + ([int]($following.Count)))
    $found = $null
    foreach ($sib in @($following)) {
        if ($sib.InnerText -match '(?i)\b(disque|disk|disc|cd)\b') { Write-Host '   encountered another disc label, stopping'; break }
        $cand = $sib.SelectNodes('.//*[@data-track]')
        if (-not $cand -or $cand.Count -eq 0) { $cand = $sib.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]') }
        Write-Host ('   sibling tag=' + $sib.Name + ' class=' + ($sib.GetAttributeValue('class','')) + ' matching count: ' + ([int]($cand.Count)))
        if ($cand -and $cand.Count -gt 0) { $found = $cand; break }
    }
    if ($found) { Write-Host ('  following-sibling matched nodes: ' + $found.Count) } else { Write-Host '  following-sibling found none' }
}

# print sample around the first DISQUE 2 occurrence
$pos = 2440
$lines = Get-Content -Path $htmlPath
$start = [Math]::Max(0, $pos-10)
$end = [Math]::Min($lines.Count-1, $pos+30)
Write-Host "\n--- Raw HTML snippet around line $pos ---"
for ($i=$start; $i -le $end; $i++) { Write-Host ("{0,5}: {1}" -f ($i+1), $lines[$i]) }
