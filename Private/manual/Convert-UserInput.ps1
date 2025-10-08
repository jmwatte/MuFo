function Convert-UserInput {
    <#
    .SYNOPSIS
        Parses user input into different types for UI handling.

    .DESCRIPTION
        Analyzes user input and categorizes it into commands, selections, ranges, IDs, or text.
        Used by interactive stages to determine how to handle user input.

    .PARAMETER UserInput
        The raw user input string to parse.

    .PARAMETER ValidCommands
        Array of valid command strings (e.g., @('b', 'n', 'p', 's', 'cp', '*')).

    .PARAMETER MaxIndex
        Maximum valid index for numeric selections (used for validation).

    .OUTPUTS
        PSCustomObject with properties:
        - Type: 'Command' | 'Index' | 'Range' | 'IdSelection' | 'Text' | 'Empty'
        - Value: The parsed value (depends on Type)
        - RawInput: The original input string

    .EXAMPLE
        $result = Convert-UserInput -UserInput "1,3,5-8" -ValidCommands @('b', 'n', 'p') -MaxIndex 20
        # Returns: @{ Type = 'Range'; Value = @(1,3,5,6,7,8); RawInput = '1,3,5-8' }

    .EXAMPLE
        $result = Convert-UserInput -UserInput "b" -ValidCommands @('b', 'n', 'p') -MaxIndex 20
        # Returns: @{ Type = 'Command'; Value = 'b'; RawInput = 'b' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$UserInput,

        [Parameter(Mandatory)]
        [string[]]$ValidCommands,

        [Parameter(Mandatory)]
        [int]$MaxIndex
    )

    $trimmedInput = $UserInput.Trim()

    # Empty input
    if ([string]::IsNullOrEmpty($trimmedInput)) {
        return [PSCustomObject]@{
            Type = 'Empty'
            Value = $null
            RawInput = $UserInput
        }
    }

    # Check for valid commands first
    if ($trimmedInput -in $ValidCommands) {
        return [PSCustomObject]@{
            Type = 'Command'
            Value = $trimmedInput
            RawInput = $UserInput
        }
    }

    # Check for ID selection (id:12345)
    if ($trimmedInput -match '^id:(.+)$') {
        return [PSCustomObject]@{
            Type = 'IdSelection'
            Value = $matches[1]
            RawInput = $UserInput
        }
    }

    # Check for numeric ranges/selections (1,3,5-8,12)
    if ($trimmedInput -match '^[\d,\-\s\.]+$') {
        try {
            $indices = Expand-SelectionRange -RangeText $trimmedInput -MaxIndex $MaxIndex
            if ($indices.Count -gt 0) {
                return [PSCustomObject]@{
                    Type = 'Range'
                    Value = $indices
                    RawInput = $UserInput
                }
            }
        }
        catch {
            # If range parsing fails, fall through to text
        }
    }

    # Check for single number
    if ($trimmedInput -match '^\d+$') {
        $index = [int]$trimmedInput
        if ($index -ge 1 -and $index -le $MaxIndex) {
            return [PSCustomObject]@{
                Type = 'Index'
                Value = $index
                RawInput = $UserInput
            }
        }
    }

    # Default to text input
    return [PSCustomObject]@{
        Type = 'Text'
        Value = $trimmedInput
        RawInput = $UserInput
    }
}