# Private/QGet-AlbumTracks.ps1
function Get-GtmProductField {
    param (
        [Parameter(Mandatory)]
        [string]$GtmRaw,

        [Parameter(Mandatory)]
        [string]$FieldName
    )

    try {
        # Decode HTML entities
        $decoded = [System.Net.WebUtility]::HtmlDecode($GtmRaw)

        # Convert to JSON
        $json = $decoded | ConvertFrom-Json

        # Extract the field from the product object
        if ($json.product.PSObject.Properties.Name -contains $FieldName) {
            return $json.product.$FieldName
        }
        else {
            Write-Warning "Field '$FieldName' not found in product data."
            return $null
        }
    }
    catch {
        Write-Error "Failed to parse data-gtm: $_"
        return $null
    }
}
# filepath: c:\Users\resto\Documents\PowerShell\Modules\MuFo\Private\Get-QAlbumTracks.ps1
function Get-QAlbumTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Live')]
        [string]$Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'Local')]
        [string]$HtmlFile   # optional: path to a saved HTML file for offline testing
    )

    begin {
        if (-not (Get-Module -Name PowerHTML -ListAvailable)) {
            throw "PowerHTML module is required but not installed. Install it with: Install-Module PowerHTML"
        }
        Import-Module PowerHTML -ErrorAction Stop
         # Load System.Web for HTML decoding
        Add-Type -AssemblyName System.Web
    }

    process {
        if ($HtmlFile) {
            if (-not (Test-Path $HtmlFile)) { throw "HtmlFile not found: $HtmlFile" }
            Write-Verbose ("Loaded HTML from file: {0}" -f $HtmlFile)

            # If HTML fixture is provided, prefer the stable helper parser implemented in Public\Get-TracksFromHtml.ps1
            try {
                . "$PSScriptRoot\..\Public\Get-TracksFromHtml.ps1"
                $parsed = Get-TracksFromHtml -Path $HtmlFile
                if ($parsed) {
                    # Ensure provider-canonical shape for downstream consumers
                    $normalized = @()
                    foreach ($p in $parsed) {
                        $id = $p.id
                        $name = $p.name
                        if (-not $name -and $p.Title) { $name = $p.Title }
                        $disc = $null
                        if ($p.PSObject.Properties['DiscNumber']) { $disc = $p.DiscNumber }
                        elseif ($p.PSObject.Properties['disc_number']) { $disc = $p.disc_number }
                        elseif ($p.PSObject.Properties['disc']) { $disc = $p.disc }

                        $track = $null
                        if ($p.PSObject.Properties['TrackNumber']) { $track = $p.TrackNumber }
                        elseif ($p.PSObject.Properties['track_number']) { $track = $p.track_number }
                        elseif ($p.PSObject.Properties['track']) { $track = $p.track }

                        $duration = $null
                        if ($p.PSObject.Properties['duration_ms']) { $duration = $p.duration_ms }
                        elseif ($p.PSObject.Properties['duration']) { $duration = $p.duration }

                        $obj = [PSCustomObject]@{
                            id                 = $id
                            name               = $name
                            Title              = $name
                            disc_number        = $disc
                            DiscNumber         = $disc
                            track_number       = $track
                            TrackNumber        = $track
                            duration_ms        = $duration
                            duration           = if ($duration -and $duration -is [int]) { [math]::Round($duration / 1000) } else { $duration }
                            Artist             = ($(if ($p.PSObject.Properties['Artist']) { $p.Artist } elseif ($p.PSObject.Properties['artist']) { $p.artist } else { '' }))
                            artists            = @()
                            _RawProviderObject = $p
                        }

                        # try to populate artists array if an Artist string exists
                        if ($obj.Artist -and $obj.Artist -ne '') {
                            $obj.artists += [pscustomobject]@{ name = $obj.Artist }
                        }

                        $normalized += $obj
                    }

                    return $normalized
                }
            }
            catch {
                Write-Warning "Get-TracksFromHtml failed, falling back to inline parsing: $($_.Exception.Message)"
                $html = Get-Content -Raw -Path $HtmlFile
            }
        }
        else {
            # Normalize album URL (best-effort)
            if ($Id -match '^https?://') { $url = $Id.TrimEnd('/') }
            elseif ($Id -match '^/be-fr/album/') { $url = "https://www.qobuz.com$($Id.TrimEnd('/'))" }
            else { $url = "https://www.qobuz.com/be-fr/album/$Id"; Write-Verbose "Best-effort album URL built: $url" }

            Write-Verbose ("Fetching Qobuz album page: {0}" -f $url)
            try {
                $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
                $html = $resp.Content
            }
            catch {
                Write-Warning ("Failed to download album page {0}: {1}" -f $url, $_.Exception.Message)
                return @()
            }

            # when verbose, write the HTML to a temp file so you can inspect it
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $tmp = Join-Path $env:TEMP ("qobuz_album_{0}.html" -f ([guid]::NewGuid().ToString()))
                $html | Out-File -FilePath $tmp -Encoding utf8
                Write-Verbose ("Saved fetched HTML to: {0}" -f $tmp)
            }
        }

        try {
            $doc = ConvertFrom-Html -Content $html
        }
        catch {
            Write-Warning ("Failed to parse HTML: {0}" -f $_.Exception.Message)
            return @()
        }

        #     # Primary candidate nodes
        #     $allTrackNodes = $doc.SelectNodes('//*[@data-track]') 
        #     if (-not $allTrackNodes -or $allTrackNodes.Count -eq 0) {
        #         Write-Verbose "Selector //*[@data-track] found 0 nodes; trying fallback selector by class 'track'."
        #         $allTrackNodes = $doc.SelectNodes('//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #     } else {
        #         Write-Verbose ("Found {0} nodes with @data-track" -f $allTrackNodes.Count)
        #     }

        #     if (-not $allTrackNodes -or $allTrackNodes.Count -eq 0) {
        #         Write-Warning "No track nodes matched selectors; either page is client-rendered or markup differs."
        #         return @()
        #     }

        #     # Prepare output and dedupe map
        #    $tracks = @()


        #$trackContainer = $doc.SelectSingleNode("//*[@id='playerTracks']")
        $children = $doc.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' player__item ')]")
        #$trackContainer.ChildNodes
        $tracks = @()
        $currentWorkTitle = ""
        $currentDisc = "01"
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
                Composer   = $roles['Composer']
                Artist     = $roles['Artist']
                MainArtist = $roles['MainArtist']
            }
        }
        foreach ($node in $children) {
            $r = $node.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " player__tracks ")]//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")]')
            if ($r) {
                $currentWorkTitle = [System.Web.HttpUtility]::HtmlDecode($r.InnerText.Split("   ")[0].Trim())
                # $diskAttr = $node.GetAttributeValue("data-disk", $null)
                # if ($diskAttr) {
                #     $currentDisc = "DISQUE $diskAttr"
                # }
            }
            #  $trackNodes = $doc.SelectNodes("//div[contains(@class,'track') and @data-track]")
            $diskP = $node.SelectSingleNode('.//p[contains(concat(" ", normalize-space(@class), " "), " player__work ")][@data-disk]')
            $dataTrack = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-track').value  
            if ($diskP) {
                $currentDisc = "{0:D2}" -f [int]($diskP.InnerText.Split(" ")[1])
            }

            $dataGtm = $node.SelectSingleNode(".//div[contains(@class,'track')and @data-track]").GetAttributes('data-gtm').value  
            $categoryGenre = Get-GtmProductField -GtmRaw $dataGtm  -FieldName 'category'

            if ($node.SelectSingleNode(".//div[contains(@class,'track__items')]")) {
                $trackNode = $node.SelectSingleNode(".//div[contains(@class,'track__items')]")
                $title = [System.Web.HttpUtility]::HtmlDecode($trackNode.GetAttributeValue("title", "Unknown Title"))
                $durationNode = $trackNode.SelectSingleNode(".//span[contains(@class,'track__item--duration')]")
                $duration = if ($durationNode) { $durationNode.InnerText.Trim() } else { "Unknown Duration" }
                $trackNumberNode = $trackNode.SelectSingleNode(".//div[contains(@class,'track__item--number')]/span")
                $trackNumber = if ($trackNumberNode) { "{0:D2}" -f [int]($trackNumberNode.InnerText.Trim()) } else { "Unknown Number" }
                #$trackNumber = if ($trackNumberNode) { $trackNumberNode.InnerText.Trim() } else { "Unknown Number" }
                $infoNode = $node.SelectSingleNode(".//div[@class='track__infos']/p[@class='track__info']")
                $performerInfo = if ($infoNode) { $infoNode.InnerText.Trim() } else { "Unknown Performer" }
                $parsed = ParsePerformer $performerInfo

                $artists = @()
                if ($parsed.Artist) {
                    $artists += [PSCustomObject]@{ name = $parsed.Artist; type = "artist" }
                }
                if ($parsed.MainArtist -and $parsed.MainArtist -ne $parsed.Artist) {
                    $artists += [PSCustomObject]@{ name = $parsed.MainArtist; type = "main" }
                }

                $out = [PSCustomObject]@{
                    id           = ($dataTrack -replace '^id:', '')
                    name         = if ($currentWorkTitle) { $currentWorkTitle + "," + $title } else { $title }
                    Title        = if ($currentWorkTitle) { $currentWorkTitle + " ," + $title } else { $title }
                    disc_number  = $currentDisc
                    DiscNumber   = $currentDisc
                    track_number = $trackNumber
                    TrackNumber  = $trackNumber
                    duration_ms  = $duration
                    duration     = $duration
                    composer     = $parsed.Composer
                    # Provider-normalized artist fields (Qobuz track entries often lack explicit performers)
                    artists      = $artists
                    Artist       = $artists
                    genres       = $categoryGenre
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
        # $processed = @{}
        # $script:anon = 0
        # $script:trackNumberCounter = 1

        #        function New-TrackFromNode($node, [int]$discNumber) {
        #     # determine stable key to avoid duplicates
        #     $tid = $node.GetAttributeValue('data-track','')
        #     if (-not $tid) { $tid = $node.GetAttributeValue('data-track-id','') }
        #     if (-not $tid) { $script:anon++; $tid = "anon-$script:anon"; $key = $tid } else { $key = "id:$tid" }
        
        #     if ($processed.ContainsKey($key)) { return $null }
        
        #     # title
        #     $titleNode = $node.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--name ")]')
        #     if (-not $titleNode) { $titleNode = $node.SelectSingleNode('.//a[contains(@class,"track-title") or contains(@class,"track-name")]') }
        #     $title = if ($titleNode) { $titleNode.InnerText.Trim() } else { $node.InnerText.Trim() }
        
        #     # duration
        #     $dur = $node.GetAttributeValue('data-duration','')
        #     $durationMs = 0
        #     if ($dur -and $dur -match '^\d+$') {
        #         $num = [int]$dur
        #         $durationMs = ($num -lt 10000) ? ($num * 1000) : $num
        #     }

        #     # If duration not present as data-duration, try to parse visible duration text e.g. 00:03:45
        #     if ($durationMs -eq 0) {
        #         try {
        #             $durNode = $node.SelectSingleNode('.//*[contains(concat(" ", normalize-space(@class), " "), " track__item--duration ")]')
        #             if ($durNode -and $durNode.InnerText.Trim() -match '^(\d{1,2}):(\d{2})(?::(\d{2}))?$') {
        #                 $mm = [int]$matches[1]; $ss = [int]$matches[2]; $hh = 0
        #                 if ($matches[3]) { $hh = [int]$matches[3] }
        #                 $durationMs = (($hh * 3600) + ($mm * 60) + $ss) * 1000
        #             }
        #         } catch {
        #             # ignore
        #         }
        #     }
        
        #     # composer extraction: look in the track__infos block for a "Composer" mention
        #     $composer = ''
        #     $infosNode = $node.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]')
        #     if (-not $infosNode) {
        #         # some pages have the infos as siblings of the track node; try parent
        #         $parent = $node.ParentNode
        #         if ($parent) { $infosNode = $parent.SelectSingleNode('.//div[contains(concat(" ", normalize-space(@class), " "), " track__infos ")]') }
        #     }
        #     if ($infosNode) {
        #         $pNodes = $infosNode.SelectNodes('.//p[contains(concat(" ", normalize-space(@class), " "), " track__info ")]')
        #         if ($pNodes) {
        #             foreach ($p in @($pNodes)) {
        #                 $txt = $p.InnerText.Trim()
        #                 if ($txt -match '(?i)\bComposer\b') {
        #                     # prefer "Name, Composer" patterns
        #                     if ($txt -match '^\s*([^,]+)\s*,\s*Composer\b') {
        #                         $composer = $matches[1].Trim()
        #                     } elseif ($txt -match '^(.*?)\s*-\s*.*Composer\b') {
        #                         $composer = $matches[1].Trim()
        #                     } else {
        #                         # fallback: take first name-like token before a dash or comma
        #                         $composer = ($txt -split '[,-]')[0].Trim()
        #                     }
        #                     break
        #                 }
        #                 # If the infos block mentions Artist/Performer roles, try to extract performer names
        #                 elseif ($txt -match '(?i)\b(Artist|Performer|MainArtist|Main Performer)\b') {
        #                     try {
        #                         # Split on dash to separate composer part from performers (common pattern: "Composer - Performer, Artist")
        #                         $parts = $txt -split '\\s-\\s', 2
        #                         $performerPart = if ($parts.Count -gt 1) { $parts[1] } else { $txt }

        #                         # Remove role labels and parenthetical notes
        #                         $clean = $performerPart -replace '(?i)\b(Artist|Performer|MainArtist|Composer|Main Performer)\b', ''
        #                         $clean = $clean -replace '\(.*?\)', ''

        #                         # Split on commas and semicolons and trim; keep tokens that look like person names
        #                         $candidates = @()
        #                         foreach ($tok in ($clean -split '[,;]')) {
        #                             $name = $tok.Trim()
        #                             if ($name -and $name -match '\w') {
        #                                 $candidates += $name
        #                             }
        #                         }
        #                         if ($candidates.Count -gt 0) {
        #                             foreach ($n in $candidates) { $out.artists += [pscustomobject]@{ name = $n } }
        #                             if ($out.Artist -eq '' -and $candidates.Count -gt 0) { $out.Artist = ($candidates -join '; ') }
        #                         }
        #                     } catch {
        #                         Write-Verbose "Artist heuristics failed on infos text: $($_.Exception.Message)"
        #                     }
        #                 }
        #             }
        #         }
        #     }
        
        #     # mark processed
        #     $processed[$key] = $true
        
        #     $out = [PSCustomObject]@{
        #         id = ($key -replace '^id:','')
        #         name = $title
        #         Title = $title
        #         disc_number = $discNumber
        #         DiscNumber = $discNumber
        #         track_number = $script:trackNumberCounter
        #         TrackNumber = $script:trackNumberCounter
        #         duration_ms = $durationMs
        #         duration = if ($durationMs -gt 0) { [math]::Round($durationMs/1000) } else { 0 }
        #         composer = $composer
        #         # Provider-normalized artist fields (Qobuz track entries often lack explicit performers)
        #         artists = @()
        #         Artist = ''
        #         # keep raw node and diagnostic hint
        #         _RawProviderObject = $node
        #     }

        #     # Try to extract performing artist(s) from the node if available
        #     try {
        #         $perfNodes = $node.SelectNodes('.//*[contains(concat(" ", normalize-space(@class), " "), " track__performer ")]')
        #         if (-not $perfNodes -or $perfNodes.Count -eq 0) {
        #             $perfNodes = $node.SelectNodes('.//a[contains(@href, "/artist/") or contains(@class,"artist")]')
        #         }
        #         if ($perfNodes -and $perfNodes.Count -gt 0) {
        #             $names = @()
        #             foreach ($p in @($perfNodes)) {
        #                 $n = $p.InnerText.Trim()
        #                 if ($n) { $names += $n; $out.artists += [pscustomobject]@{ name = $n } }
        #             }
        #             if ($names.Count -gt 0) { $out.Artist = ($names -join '; ') }
        #         }
        #         else {
        #             # fallback: try to extract artist info from the infosNode text if present and we didn't already populate
        #             if ($out.Artist -eq '' -and $infosNode) {
        #                 try {
        #                     $infos = $infosNode.InnerText -replace '\s{2,}',' '
        #                     # look for patterns like "- Name, Artist" or ", Artist - Name"
        #                     if ($infos -match '-\s*([^,\n]+)\s*,\s*Artist') {
        #                         $cand = $matches[1].Trim()
        #                         if ($cand) { $out.artists += [pscustomobject]@{ name = $cand }; $out.Artist = $cand }
        #                     }
        #                     else {
        #                         # attempt simple heuristic: take tokens labelled 'Artist' in the block
        #                         $m = ([regex]::Matches($infos, '([^,\n]+)\s*,\s*(?:Artist|Performer|MainArtist)'))
        #                         if ($m.Count -gt 0) {
        #                             $names = @()
        #                             foreach ($mm in $m) { $n = $mm.Groups[1].Value.Trim(); if ($n) { $names += $n; $out.artists += [pscustomobject]@{ name = $n } } }
        #                             if ($names.Count -gt 0 -and $out.Artist -eq '') { $out.Artist = ($names -join '; ') }
        #                         }
        #                     }
        #                 } catch {
        #                     # ignore
        #                 }
        #             }
        #         }
                
        #         # Another fallback: parse data-track-v2 JSON payload for item_brand or item_artist that may contain artist
        #         if ($out.Artist -eq '') {
        #             try {
        #                 $rawV2 = $node.GetAttributeValue('data-track-v2','')
        #                 if ($rawV2 -and $rawV2 -match '[\{\}\"]') {
        #                     $json = $rawV2 -replace '&quot;','"'
        #                     $json = $json -replace "'", '"'
        #                     $parsedV2 = $null
        #                     try { $parsedV2 = $json | ConvertFrom-Json -ErrorAction Stop } catch { $parsedV2 = $null }
        #                     if ($parsedV2) {
        #                         $maybe = $null
        #                         if ($parsedV2.PSObject.Properties.Match('item_brand')) { $maybe = $parsedV2.item_brand }
        #                         if (-not $maybe -and $parsedV2.PSObject.Properties.Match('item_artist')) { $maybe = $parsedV2.item_artist }
        #                         if ($maybe) { $out.artists += [pscustomobject]@{ name = $maybe }; $out.Artist = $maybe }
        #                     }
        #                 }
        #             } catch {
        #                 # non-fatal
        #             }
        #         }
        #     } catch {
        #         # non-fatal: leave artists empty
        #         Write-Verbose "Artist extraction failed for node: $($_.Exception.Message)"
        #     }
        
        #     $script:trackNumberCounter++
        #     return $out
        # }

        #         # 1) Process explicit disc containers first (elements with data-disk)
        # $discContainers = $doc.SelectNodes('//*[@data-disk]')
        # if ($discContainers) {
        #     foreach ($c in @($discContainers)) {
        #         $diskAttr = $c.GetAttributeValue('data-disk','')
        #         $discNum = 1
        #         if ($diskAttr -and $diskAttr -match '^\d+$') { $discNum = [int]$diskAttr }
        #         else { if ($c.InnerText -match '(\d+)') { $discNum = [int]$matches[1] } }
        
        #         # 1.a) Try tracks inside this element first (descendants)
        #         $nodes = $c.SelectNodes('.//*[@data-track]')
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             $nodes = $c.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #         }
        
        #         # 1.b) If none, walk up ancestors to find a parent container that holds tracks
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             $ancestor = $c.ParentNode
        #             $attempt = 0
        #             while ($ancestor -and $attempt -lt 6) {
        #                 $attempt++
        #                 $nodes = $ancestor.SelectNodes('.//*[@data-track]')
        #                 if ($nodes -and $nodes.Count -gt 0) { break }
        #                 $nodes = $ancestor.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                 if ($nodes -and $nodes.Count -gt 0) { break }
        #                 $ancestor = $ancestor.ParentNode
        #             }
        #         }
        
        #         # 1.c) If still none, check enclosing player__item and subsequent player__item siblings
        #         # Many pages place the disc label inside one player__item and the tracks in that and following player__item blocks.
        #         if (-not $nodes -or $nodes.Count -eq 0) {
        #             # find a containing player__item (or similar container)
        #             $container = $c
        #             while ($container -and -not ($container.GetAttributeValue('class','') -match '\bplayer__item\b')) {
        #                 $container = $container.ParentNode
        #             }
        #             if (-not $container) { $container = $c }

        #             $collected = @()
        #             # collect from this container and following siblings until next disc label
        #             $sibList = $container.SelectNodes('following-sibling::*')
        #             # include the container itself first
        #             $targets = @($container)
        #             if ($sibList) { foreach ($s in @($sibList)) { $targets += $s } }

        #             foreach ($t in @($targets)) {
        #                 if ($t.InnerText -match '(?i)\b(disque|disk|disc|cd)\b') { break }
        #                 $cand = $t.SelectNodes('.//*[@data-track]')
        #                 if (-not $cand -or $cand.Count -eq 0) {
        #                     $cand = $t.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                 }
        #                 if ($cand -and $cand.Count -gt 0) { foreach ($n in @($cand)) { $collected += $n } }
        #             }
        #             if ($collected.Count -gt 0) { $nodes = $collected }
        #         }
        
        #         # 1.d) Process found track nodes (if any)
        #         if ($nodes) {
        #             foreach ($n in @($nodes)) {
        #                 $t = New-TrackFromNode $n $discNum
        #                 if ($t) { $tracks += $t }
        #             }
        #         }
        #     }
        # }

        # # 2) Next: labels like "DISQUE 2" / "DISK 2" — assign disc to tracks near the label
        # $labelNodes = $doc.SelectNodes('//*[contains(translate(normalize-space(.),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "DISQUE") or contains(translate(normalize-space(.),"abcdefghijklmnopqrstuvwxyz","ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "DISK")]')
        # if ($labelNodes) {
        #     foreach ($lbl in @($labelNodes)) {
        #         if ($lbl.InnerText -match '(\d+)') {
        #             $discNum = [int]$matches[1]

        #             # Try multiple strategies in order of reliability:
        #             # A) tracks that are descendants of the label node itself
        #             $nodes = $lbl.SelectNodes('.//*[@data-track]')
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $nodes = $lbl.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #             }

        #             # B) tracks in following siblings of the label node (common pattern: label then track list)
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $following = $lbl.SelectNodes('following-sibling::*')
        #                 if ($following) {
        #                     foreach ($sib in @($following)) {
        #                         # stop scanning when we hit another disc label
        #                         if ($sib.InnerText -match '(?i)\b(disque|disk|disc|cd)\b') { break }
        #                         $nodes = $sib.SelectNodes('.//*[@data-track]')
        #                         if (-not $nodes -or $nodes.Count -eq 0) {
        #                             $nodes = $sib.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                         }
        #                         if ($nodes -and $nodes.Count -gt 0) { break }
        #                     }
        #                 }
        #             }

        #             # C) fallback: tracks in the label's parent container (existing behavior)
        #             if (-not $nodes -or $nodes.Count -eq 0) {
        #                 $parent = $lbl.ParentNode
        #                 if ($parent) {
        #                     $nodes = $parent.SelectNodes('.//*[@data-track]')
        #                     if (-not $nodes -or $nodes.Count -eq 0) {
        #                         $nodes = $parent.SelectNodes('.//div[contains(concat(" ", normalize-space(@class), " "), " track ")]')
        #                     }
        #                 }
        #             }

        #             if ($nodes) {
        #                 foreach ($n in @($nodes)) {
        #                     $t = New-TrackFromNode $n $discNum
        #                     if ($t) { $tracks += $t }
        #                 }
        #             }
        #         }
        #     }
        # }

        # # 3) Finally: any remaining tracks not yet processed — use per-track data-disk or default 1
        # foreach ($node in @($allTrackNodes)) {
        #     # determine key
        #     $idCandidate = $node.GetAttributeValue('data-track','')
        #     if (-not $idCandidate) { $idCandidate = $node.GetAttributeValue('data-track-id','') }
        #     $checkKey = if ($idCandidate) { "id:$idCandidate" } else {
        #         $Script:anon++; "anon-$Script:anon"
        #     }
        #     if ($processed.ContainsKey($checkKey)) { continue }

        #     $discNum = 1
        #     $diskAttr = $node.GetAttributeValue('data-disk','')
        #     if ($diskAttr -and $diskAttr -match '^\d+$') {
        #         $discNum = [int]$diskAttr
        #     }
        #     else {
        #         # try parent/ancestor label (existing behavior)
        #         $parent = $node.ParentNode
        #         while ($parent -and $parent.NodeType -ne 'Document') {
        #             if ($parent.InnerText -match '(DISQUE|DISK)\s*(\d+)' ) { $discNum = [int]$matches[2]; break }
        #             $parent = $parent.ParentNode
        #         }

        #         # If still not found, try scanning preceding siblings of the node and its ancestors
        #         if ($discNum -eq 1) {
        #             $current = $node
        #             $found = $false
        #             $attempt = 0
        #             while (-not $found -and $current -and $attempt -lt 8) {
        #                 $attempt++
        #                 $prevSibs = $current.SelectNodes('preceding-sibling::*')
        #                 if ($prevSibs) {
        #                     # iterate from nearest previous sibling backwards
        #                     foreach ($ps in @($prevSibs)) {
        #                         # check if the sibling itself carries a data-disk attr
        #                         $pDisk = $ps.GetAttributeValue('data-disk','')
        #                         if ($pDisk -and $pDisk -match '^\d+$') { $discNum = [int]$pDisk; $found = $true; break }
        #                         # or contains a visible label like 'DISQUE 2'
        #                         if ($ps.InnerText -match '(?i)\b(DISQUE|DISK)\s*(\d+)') { $discNum = [int]$matches[2]; $found = $true; break }
        #                         # or contains descendants with data-disk
        #                         $inner = $ps.SelectNodes('.//*[@data-disk]')
        #                         if ($inner -and $inner.Count -gt 0) {
        #                             $pDisk = $inner[0].GetAttributeValue('data-disk','')
        #                             if ($pDisk -and $pDisk -match '^\d+$') { $discNum = [int]$pDisk; $found = $true; break }
        #                         }
        #                     }
        #                 }
        #                 if (-not $found) { $current = $current.ParentNode }
        #             }
        #         }
        #     }

        #     $t = New-TrackFromNode $node $discNum
        #     if ($t) { $tracks += $t }
        # }

        return $tracks
    }
}

