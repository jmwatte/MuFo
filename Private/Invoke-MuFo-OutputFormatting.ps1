function Write-AlbumComparisonResult {
    <#
.SYNOPSIS
    Writes album comparison results in a consistent multi-line format.

.DESCRIPTION
    Provides consistent formatting for album comparison results across all modes.

.PARAMETER Album
    The local album name.

.PARAMETER LocalArtist
    The local artist name.

.PARAMETER SpotifyArtist
    The Spotify artist name.

.PARAMETER IsAlbumMatch
    Whether the album names match.

.PARAMETER IsArtistMatch
    Whether the artist names match (case-sensitive).
#>
    param(
        [string]$Album,
        [string]$LocalArtist,
        [string]$SpotifyArtist,
        [bool]$IsAlbumMatch = $true,
        [bool]$IsArtistMatch = $true
    )

    if ($IsAlbumMatch -and $IsArtistMatch) {
        Write-Host "Album '$Album': No changes needed" -ForegroundColor Green
    }
    elseif ($IsAlbumMatch -and -not $IsArtistMatch) {
        Write-Host "Album '$Album': No rename needed" -ForegroundColor DarkYellow
        Write-Host "  LocalArtist  : " -ForegroundColor Green -NoNewline; Write-Host $LocalArtist
        Write-Host "  SpotifyArtist: " -ForegroundColor Green -NoNewline; Write-Host $SpotifyArtist
    }
    else {
        Write-Host "Album '$Album': Rename suggested" -ForegroundColor Yellow
        Write-Host "  LocalArtist  : " -ForegroundColor Green -NoNewline; Write-Host $LocalArtist
        Write-Host "  SpotifyArtist: " -ForegroundColor Green -NoNewline; Write-Host $SpotifyArtist
    }
}

function Write-RenameOperation {
    <#
.SYNOPSIS
    Writes rename operations in a consistent multi-line format.

.DESCRIPTION
    Provides consistent formatting for rename operations across all modes.

.PARAMETER RenameMap
    Hashtable of rename operations (source -> target).

.PARAMETER Title
    Title to display for the rename section.
#>
    param(
        [hashtable]$RenameMap,
        [string]$Title = "WhatIf: Performing Rename Operation"
    )

    if ($RenameMap.Count -gt 0) {
        Write-Host $Title -ForegroundColor DarkYellow
        foreach ($kv in $RenameMap.GetEnumerator()) {
            Write-Host "Name  : " -ForegroundColor Green -NoNewline; Write-Host $kv.Key
            Write-Host "Value : " -ForegroundColor Green -NoNewline; Write-Host $kv.Value
            Write-Host "`n"
            Write-Host "`n"
        }
    }
}

function Write-ArtistSelectionPrompt {
    <#
.SYNOPSIS
    Writes artist selection prompts in a consistent format.

.DESCRIPTION
    Provides consistent formatting for artist selection across manual mode.

.PARAMETER TopMatches
    Array of top artist matches with Score property.
#>
    param($TopMatches)

    for ($i = 0; $i -lt $TopMatches.Count; $i++) {
        Write-Host "$($i + 1). $($TopMatches[$i].Artist.Name) (Score: $([math]::Round($TopMatches[$i].Score, 2)))"
    }
}

function Write-ArtistTypoWarning {
    <#
    .SYNOPSIS
    Displays a warning about possible artist name typos.
    
    .DESCRIPTION
    Shows a formatted warning when the folder artist name differs from
    the inferred Spotify artist name, suggesting a possible typo.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FolderArtist,
        
        [Parameter(Mandatory)]
        [string]$SpotifyArtist
    )
    
    Write-Host ("Possible artist typo: folder '{0}' -> Spotify '{1}'" -f $FolderArtist, $SpotifyArtist) -ForegroundColor DarkYellow
}

function Write-ArtistRenameMessage {
    <#
    .SYNOPSIS
    Displays artist rename suggestions in a consistent format.
    
    .DESCRIPTION
    Shows formatted messages about artist folder renaming suggestions
    with consistent styling and multi-line format.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$SpotifyArtist,
        
        [string]$AlbumStatus = "No changes needed (already correctly named)"
    )
    
    Write-Host "Artist Rename Suggested:`n '$LocalArtist' → '$SpotifyArtist'" -ForegroundColor Yellow
    Write-Host "Album Folders: $AlbumStatus" -ForegroundColor DarkYellow
}

function Write-AlbumNoRenameNeeded {
    <#
    .SYNOPSIS
    Displays album no-rename-needed messages in a consistent format.
    
    .DESCRIPTION
    Shows formatted messages when albums don't need renaming, with
    consistent artist information display.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LocalAlbum,
        
        [Parameter(Mandatory)]
        [string]$LocalArtist,
        
        [Parameter(Mandatory)]
        [string]$SpotifyArtist,
        
        [string]$Reason = "No rename needed"
    )
    
    Write-Host "$Reason" -ForegroundColor DarkYellow
    Write-Host "  LocalArtist  : " -ForegroundColor Green -NoNewline; Write-Host $LocalArtist
    Write-Host "  SpotifyArtist: " -ForegroundColor Green -NoNewline; Write-Host $SpotifyArtist
    Write-Host "on Album $LocalAlbum"
    Write-Host "`n"
}

function Write-NothingToRenameMessage {
    <#
    .SYNOPSIS
    Displays a message when no renames are needed.
    
    .DESCRIPTION
    Shows a formatted message indicating that local folder names
    already match the proposed new names.
    #>
    param([string]$Message = "Nothing to Rename: LocalFolder = NewFolderName")
    
    Write-Host $Message -ForegroundColor DarkYellow
    Write-Host "`n"
    Write-Host "`n"
}

function Write-WhatIfMessage {
    <#
    .SYNOPSIS
    Displays WhatIf operation messages in a consistent format.
    
    .DESCRIPTION
    Shows formatted messages for WhatIf scenarios with consistent styling.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    Write-Host "WhatIf: $Message" -ForegroundColor DarkYellow
}

function Write-AlbumAnalysisHeader {
    <#
.SYNOPSIS
    Writes album analysis information in a consistent format.

.DESCRIPTION
    Provides consistent formatting for album analysis across all modes.

.PARAMETER LocalArtist
    The local artist name.

.PARAMETER SpotifyArtist
    The selected Spotify artist name.

.PARAMETER AlbumCount
    Number of albums found.

.PARAMETER ArtistSource
    Source of artist selection (search, inferred, etc.).
#>
    param(
        [string]$LocalArtist,
        [string]$SpotifyArtist,
        [int]$AlbumCount,
        [string]$ArtistSource
    )

    Write-Host "`n=== Album Analysis ===" -ForegroundColor Cyan
    Write-Host "LocalArtist   : " -ForegroundColor Green -NoNewline; Write-Host $LocalArtist
    Write-Host "SpotifyArtist : " -ForegroundColor Green -NoNewline; Write-Host $SpotifyArtist
    Write-Host "Albums Found  : " -ForegroundColor Green -NoNewline; Write-Host $AlbumCount
    Write-Host "ArtistSource  : " -ForegroundColor Green -NoNewline; Write-Host $ArtistSource
}

function Write-ProcessingStatus {
    <#
.SYNOPSIS
    Writes processing status in a consistent format.

.DESCRIPTION
    Provides consistent status messaging across all processing modes.

.PARAMETER Message
    The status message to display.

.PARAMETER Type
    Type of status (Info, Warning, Error, Success).
#>
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Type = 'Info'
    )

    $color = switch ($Type) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }

    Write-Host $Message -ForegroundColor $color
}

function Write-DecisionPrompt {
    <#
.SYNOPSIS
    Writes decision prompts in a consistent format.

.DESCRIPTION
    Provides consistent formatting for user decision prompts.

.PARAMETER LocalName
    The current local name.

.PARAMETER ProposedName
    The proposed new name.

.PARAMETER Type
    Type of rename (Artist, Album).
#>
    param(
        [string]$LocalName,
        [string]$ProposedName,
        [ValidateSet('Artist', 'Album')]
        [string]$Type = 'Album'
    )

    Write-Host "`n$Type Rename Decision:" -ForegroundColor Yellow
    Write-Host "  Current : " -ForegroundColor Green -NoNewline; Write-Host $LocalName
    Write-Host "  Proposed: " -ForegroundColor Green -NoNewline; Write-Host $ProposedName
}

function ConvertTo-SafeFileName {
    <#
.SYNOPSIS
    Converts a string to a safe filename by removing invalid characters.

.PARAMETER InputString
    The string to convert.

.OUTPUTS
    String with invalid filename characters replaced.
#>
    param([string]$InputString)
    
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeString = $InputString
    foreach ($char in $invalidChars) {
        $safeString = $safeString.Replace($char, '_')
    }
    return $safeString
}

function ConvertTo-ComparableName {
    <#
.SYNOPSIS
    Converts a name to a comparable format for matching.

.PARAMETER InputString
    The string to convert.

.OUTPUTS
    String with non-alphanumeric characters removed for robust equality checks.
#>
    param([string]$InputString)
    
    # Strip non-alphanumeric for robust equality checks
    return ($InputString -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}