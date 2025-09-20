function Get-SpotifyAlbumMatches {
<#
.SYNOPSIS
    Searches Spotify for albums by name and returns top matches with artists and a similarity score.

.PARAMETER AlbumName
    The album name to search for.

.PARAMETER Top
    Number of top matches to return (default 5).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AlbumName,
        [int]$Top = 5
    )

    try {
    Write-Verbose ("Search-Item Album query: '{0}'" -f $AlbumName)
    $result = Search-Item -Type Album -Query $AlbumName -ErrorAction Stop
        $items = @()
        if ($null -eq $result) { return @() }
        if ($result -is [System.Array]) {
            foreach ($page in $result) {
                if ($page.PSObject.Properties.Match('Albums').Count -gt 0 -and $page.Albums -and $page.Albums.Items) { $items += $page.Albums.Items }
                elseif ($page.PSObject.Properties.Match('Items').Count -gt 0 -and $page.Items) { $items += $page.Items }
            }
        } else {
            if ($result.PSObject.Properties.Match('Albums').Count -gt 0 -and $result.Albums -and $result.Albums.Items) { $items = $result.Albums.Items }
            elseif ($result.PSObject.Properties.Match('Items').Count -gt 0 -and $result.Items) { $items = $result.Items }
        }
        $scored = @()
        foreach ($i in $items) {
            try {
                $name = if ($i.PSObject.Properties.Match('Name').Count) { [string]$i.Name } elseif ($i.PSObject.Properties.Match('name').Count) { [string]$i.name } else { $null }
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                $score = Get-StringSimilarity -String1 $AlbumName -String2 $name
                $artists = @()
                if ($i.PSObject.Properties.Match('Artists').Count -gt 0 -and $i.Artists) {
                    foreach ($a in $i.Artists) {
                        $an = if ($a.PSObject.Properties.Match('Name').Count) { [string]$a.Name } elseif ($a.PSObject.Properties.Match('name').Count) { [string]$a.name } else { $null }
                        $aid = if ($a.PSObject.Properties.Match('Id').Count) { [string]$a.Id } elseif ($a.PSObject.Properties.Match('id').Count) { [string]$a.id } else { $null }
                        if ($an) { $artists += [PSCustomObject]@{ Name=$an; Id=$aid } }
                    }
                }
                $scored += [PSCustomObject]@{ AlbumName=$name; Score=[double]$score; Artists=$artists }
            } catch { }
        }
        return ($scored | Sort-Object -Property Score -Descending | Select-Object -First $Top)
    } catch {
        Write-Verbose ("Album search failed for '{0}': {1}" -f $AlbumName, $_.Exception.Message)
        return @()
    }
}
