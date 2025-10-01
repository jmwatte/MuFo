Import-Module PowerHTML -ErrorAction Stop
$htmlPath = 'c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\QTracksForAlbum.html'
$html = Get-Content -Raw -Path $htmlPath
$doc = ConvertFrom-Html -Content $html
$discContainers = $doc.SelectNodes('//*[@data-disk]')
$i=0
foreach ($c in @($discContainers)) {
    $i++
    Write-Host "=== Disc container #$i ==="
    $container = $c
    while ($container -and -not ($container.GetAttributeValue('class','') -match '\bplayer__item\b')) { $container = $container.ParentNode }
    if (-not $container) { Write-Host 'No enclosing player__item, using c'; $container = $c }
    Write-Host ('Container tag=' + $container.Name + ' class=' + $container.GetAttributeValue('class',''))
    $targets = @($container)
    $sibList = $container.SelectNodes('following-sibling::*')
    if ($sibList) { foreach ($s in @($sibList)) { $targets += $s } }

    $j=0
    foreach ($t in @($targets)) {
        $j++
        $class = $t.GetAttributeValue('class','')
        $nodes = $t.SelectNodes('.//*[@data-track]')
        if (-not $nodes -or $nodes.Count -eq 0) { $nodes = $t.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]') }
        $count = 0
        if ($nodes) { $count = $nodes.Count }
        Write-Host (" target $j tag=" + $t.Name + " class=" + $class + " tracks=" + $count)
    }
}
