function Get-TracksFromHtml {
    param (
        [string]$Path
    )

    $html = Get-Content $Path -Raw | ConvertFrom-Html
    $nodes = $html.SelectNodes("//div[contains(@class,'track')]")

    $results = @()
    $currentDisc = $null

    foreach ($node in $nodes) {
        # Check if this node is a disc label
        $discLabel = $node.SelectSingleNode(".//span[contains(text(),'Disque')]")
        if ($discLabel) {
            if ($discLabel.InnerText -match 'Disque\s*(\d+)') {
                $currentDisc = [int]$matches[1]
            }
            continue
        }

        # Extract track info
        $idNode = $node.SelectSingleNode(".//input[@name='track_id']")
        $nameNode = $node.SelectSingleNode(".//span[@class='track-name']")
        $trackNumNode = $node.SelectSingleNode(".//span[@class='track-number']")

        if ($idNode -and $nameNode -and $trackNumNode -and $currentDisc) {
            $results += [pscustomobject]@{
                id           = $idNode.GetAttribute("value")
                name         = $nameNode.InnerText.Trim()
                disc_number  = $currentDisc
                track_number = [int]$trackNumNode.InnerText.Trim()
            }
        }
    }

    return $results
}

# Run it against the saved HTML
$path = 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html'
Write-Host "Parsing: $path"
$parsed = Get-TracksFromHtml -Path $path
if ($parsed) { $parsed | Format-Table -AutoSize } else { Write-Host 'No tracks parsed' }
