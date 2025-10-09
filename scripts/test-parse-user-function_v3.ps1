function Get-TracksFromHtml {
    param (
        [string]$Path
    )

    $doc = Get-Content $Path -Raw | ConvertFrom-Html

    # select label nodes (p with data-disk or text containing 'DISQUE') and track nodes, in document order
    $nodes = @()
    $labelNodes = $doc.SelectNodes("//p[@data-disk] | //p[contains(translate(normalize-space(.),'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'disque')]")
    $trackNodes = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '),' track ')]")

    if ($labelNodes) { $nodes += $labelNodes }
    if ($trackNodes) { $nodes += $trackNodes }

    # sort nodes by their line position (HtmlNode has Line property)
    $nodes = $nodes | Sort-Object { $_.Line }

    $results = @()
    $currentDisc = 1
    $trackCounter = 1

    foreach ($n in @($nodes)) {
        # label node?
        if ($n.Name -eq 'p' -and ($n.GetAttributeValue('data-disk','') -or ($n.InnerText -match '(?i)disque'))) {
            $diskAttr = $n.GetAttributeValue('data-disk','')
            if ($diskAttr -and $diskAttr -match '^\d+$') { $currentDisc = [int]$diskAttr }
            elseif ($n.InnerText -match '(\d+)') { $currentDisc = [int]$matches[1] }
            continue
        }

        # otherwise assume it's a track node
        $t = $n
        # determine id
        $tid = $t.GetAttributeValue('data-track','')
        if (-not $tid) { $tid = $t.GetAttributeValue('data-track-id','') }
        if (-not $tid) { continue }

        # title
        $titleNode = $t.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--name ")]')
        if (-not $titleNode) { $titleNode = $t.SelectSingleNode('.//a[contains(@class,"track-title") or contains(@class,"track-name")]') }
        $title = if ($titleNode) { $titleNode.InnerText.Trim() } else { $t.InnerText.Trim() }

        $results += [pscustomobject]@{
            id = $tid
            name = $title
            disc_number = $currentDisc
            track_number = $trackCounter
        }
        $trackCounter++
    }

    return $results
}

$path = 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html'
Write-Host "Parsing: $path"
$parsed = Get-TracksFromHtml -Path $path
if ($parsed) { $parsed | Format-Table -AutoSize } else { Write-Host 'No tracks parsed' }