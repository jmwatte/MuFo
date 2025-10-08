function Show-PaginatedList {
    <#
    .SYNOPSIS
        Displays a paginated list of items with navigation information.

    .DESCRIPTION
        Shows a paginated view of items with customizable formatting and status information.
        Used for displaying artist candidates, album lists, etc.

    .PARAMETER Items
        Array of items to display.

    .PARAMETER Page
        Current page number (1-based).

    .PARAMETER PageSize
        Number of items to display per page.

    .PARAMETER Title
        Title to display above the list.

    .PARAMETER StatusLine
        Optional status line to display (e.g., filter mode indicators).

    .PARAMETER FormatItem
        Script block that formats each item for display. Receives the item and 1-based index.
        Should return a string in the format: "[$index] Item details"

    .EXAMPLE
        Show-PaginatedList -Items $albums -Page 1 -PageSize 10 -Title "Albums for Artist" -StatusLine "[Filter: MASTERS ONLY]" -FormatItem {
            param($item, $index)
            $name = Get-IfExists $item 'name'
            $id = Get-IfExists $item 'id'
            $year = Get-IfExists $item 'release_date'
            "[$index] $name (id: $id) (year: $year)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Items,

        [Parameter(Mandatory)]
        [int]$Page,

        [Parameter(Mandatory)]
        [int]$PageSize,

        [Parameter(Mandatory)]
        [string]$Title,

        [string]$StatusLine,

        [Parameter(Mandatory)]
        [scriptblock]$FormatItem
    )

    # Show status line if provided
    if ($StatusLine) {
        Write-Host $StatusLine -ForegroundColor Yellow
    }

    Write-Host $Title

    $totalPages = [math]::Ceiling($Items.Count / $PageSize)
    $startIdx = ($Page - 1) * $PageSize
    $endIdx = [math]::Min($startIdx + $PageSize - 1, $Items.Count - 1)

    for ($i = $startIdx; $i -le $endIdx; $i++) {
        $item = $Items[$i]
        $displayIndex = $i + 1  # 1-based display index
        $formattedItem = & $FormatItem $item $displayIndex
        Write-Host $formattedItem
    }

    # Return pagination info for caller
    return @{
        TotalPages = $totalPages
        StartIndex = $startIdx
        EndIndex = $endIdx
        HasNextPage = $Page -lt $totalPages
        HasPrevPage = $Page -gt 1
    }
}