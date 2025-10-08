function Get-AlbumInfoFromFolder {
    <#
    .SYNOPSIS
        Parses album information from a folder name.

    .DESCRIPTION
        Extracts album name and year from a folder name, handling various formats
        like "2023 - Album Name" or just "Album Name".

    .PARAMETER Folder
        The folder object to parse.

    .OUTPUTS
        PSCustomObject with Name and Year properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]$Folder
    )

    # Try to extract year from the start of the folder name (e.g., "2023 - Album Name")
    if ($Folder.Name -match '^(\d{4})\s*[-]?\s*(.+)') {
        $year = $matches[1]
        $albumName = $matches[2].Trim()
    } else {
        $year = $null
        $albumName = $Folder.Name.Trim()
    }

    return [PSCustomObject]@{
        Name = $albumName
        Year = $year
    }
}