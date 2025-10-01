Import-Module PowerHTML

# Load the HTML content from disk
$html = Get-Content "C:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html" -Raw

# Parse it into a DOM object
$doc = ConvertFrom-Html $html

#$trackContainer = $doc.SelectSingleNode("//*[@id='playerTracks']")
$children = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' player__item ')]")
#$trackContainer.ChildNodes
 $tracks = @()
$currentWorkTitle = "Unknown Work"
$currentDisc = "1"
function ParsePerformer($inputb) {
    if (-not $inputb -or $inputb -eq "Unknown Performer") {
        return @{ Composer = $null; Artist = $null; MainArtist = $null }
    }
    $entries = $inputb -split " - "
    $roles = @{}
    foreach ($entry in $entries) {
        $parts = $entry -split ", "
        if ($parts.Length -lt 2) { continue }
        $name = $parts[0].Trim()
        for ($i = 1; $i -lt $parts.Length; $i++) {
            $role = $parts[$i].Trim()
            $roles[$role] = $name
        }
    }
    return @{
        Composer = $roles['Composer']
        Artist = $roles['Artist']
        MainArtist = $roles['MainArtist']
    }
}
foreach ($node in $children) {
    $r = $node.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " player__tracks ")]//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")]')
    if ($r) {
        $currentWorkTitle = $r.InnerText.Split("   ")[0].Trim() 
        # $diskAttr = $node.GetAttributeValue("data-disk", $null)
        # if ($diskAttr) {
        #     $currentDisc = "DISQUE $diskAttr"
        # }
    }
  #  $trackNodes = $doc.SelectNodes("//div[contains(@class,'track') and @data-track]")
    $diskP = $node.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")][@data-disk]')
    $dataTrack = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-track').value  
    if ($diskP) {
        $currentDisc = " $($diskP.InnerText.Split(" ")[1])"}

    if ($node.SelectSingleNode(".//div[contains(@class,'track__items')]")) {
        $trackNode = $node.SelectSingleNode(".//div[contains(@class,'track__items')]")
        $title = $trackNode.GetAttributeValue("title", "Unknown Title")
        $durationNode = $trackNode.SelectSingleNode(".//span[contains(@class,'track__item--duration')]")
        $duration = if ($durationNode) { $durationNode.InnerText.Trim() } else { "Unknown Duration" }
        $trackNumberNode = $trackNode.SelectSingleNode(".//div[contains(@class,'track__item--number')]/span")
        $trackNumber = if ($trackNumberNode) { $trackNumberNode.InnerText.Trim() } else { "Unknown Number" }
        $infoNode = $node.SelectSingleNode(".//div[@class='track__infos']/p[@class='track__info']")
        $performerInfo = if ($infoNode) { $infoNode.InnerText.Trim() } else { "Unknown Performer" }
$parsed = ParsePerformer $performerInfo


 $out = [PSCustomObject]@{
                id = ($dataTrack -replace '^id:','')
                name = $currentWorkTitle + "," + $title
                Title = $currentWorkTitle + " ," + $title
                disc_number = $currentDisc
                DiscNumber = $currentDisc
                track_number = $trackNumber
                TrackNumber = $trackNumber
                duration_ms = $duration
                duration = $duration
                composer =  $parsed.Composer
                # Provider-normalized artist fields (Qobuz track entries often lack explicit performers)
                artists = $parsed.Artist
                Artist = $parsed.MainArtist
                        }


       <#  [PSCustomObject]@{
            Work      = $currentWorkTitle
            Disc      = $currentDisc
            Number    = $trackNumber
            Title     = $title
            Duration  = $duration
            Performer = $performerInfo
             Composer  = $parsed.Composer
            Artist    = $parsed.Artist
            MainArtist = $parsed.MainArtist
        } #>
    }
    $tracks += $out
}
return $tracks
