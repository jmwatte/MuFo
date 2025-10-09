function Get-TracksFromHtml {
    param (
        [string]$Path
    )

    $doc = Get-Content $Path -Raw | ConvertFrom-Html
    $items = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' player__item ')]")

    $results = @()
    $currentDisc = 1
    $trackCounter = 1

    foreach ($item in @($items)) {
        # If this player item contains an explicit disc label, update currentDisc
        $discP = $item.SelectSingleNode(".//p[@data-disk]")
        if ($discP) {
            $diskAttr = $discP.GetAttributeValue('data-disk','')
            if ($diskAttr -and $diskAttr -match '^\d+$') { $currentDisc = [int]$diskAttr }
            elseif ($discP.InnerText -match '(\d+)') { $currentDisc = [int]$matches[1] }
            # a player__item that holds the disc label typically doesn't contain tracks itself
            continue
        }

        # Find track nodes inside this player__item
        $trackNodes = $item.SelectNodes(".//div[contains(concat(' ', normalize-space(@class), ' '), ' track ')]")
        if (-not $trackNodes -or $trackNodes.Count -eq 0) { continue }

        foreach ($t in @($trackNodes)) {
            # determine id
            $tid = $t.GetAttributeValue('data-track','')
            if (-not $tid) { $tid = $t.GetAttributeValue('data-track-id','') }
            if (-not $tid) { continue }

            # name
            $titleNode = $t.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--name ")]')
            $title = if ($titleNode) { $titleNode.InnerText.Trim() } else { $t.InnerText.Trim() }

            $results += [pscustomobject]@{
                id = $tid
                name = $title
                disc_number = $currentDisc
                track_number = $trackCounter
            }
            $trackCounter++
        }
    }

    return $results
}

$path = 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html'
Write-Host "Parsing: $path"
$parsed = Get-TracksFromHtml -Path $path
if ($parsed) { $parsed | Format-Table -AutoSize } else { Write-Host 'No tracks parsed' }