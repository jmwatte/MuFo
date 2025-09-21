# Test different approaches to parameter mutual exclusivity

Write-Host "=== Testing Parameter Set Approach ===" -ForegroundColor Cyan

function Test-ParameterSets {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(ParameterSetName = 'FixOnly', Mandatory = $true)]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$FixOnly,

        [Parameter(ParameterSetName = 'DontFix', Mandatory = $true)]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$DontFix,
        
        [Parameter()]
        [switch]$WhatIf
    )

    Write-Host "Parameter Set: $($PSCmdlet.ParameterSetName)"
    
    switch ($PSCmdlet.ParameterSetName) {
        'FixOnly' { 
            Write-Host "FixOnly mode: $($FixOnly -join ', ')"
            $tagsToFix = $FixOnly
        }
        'DontFix' { 
            Write-Host "DontFix mode: $($DontFix -join ', ')"
            $tagsToFix = @('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists') | Where-Object { $_ -notin $DontFix }
        }
        'Default' {
            Write-Host "Default mode: Fix everything"
            $tagsToFix = @('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')
        }
    }
    
    Write-Host "Tags to fix: $($tagsToFix -join ', ')"
}

Write-Host "`n=== Testing Manual Validation Approach ===" -ForegroundColor Cyan

function Test-ManualValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$FixOnly = @(),
        
        [Parameter()]
        [ValidateSet('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')]
        [string[]]$DontFix = @(),
        
        [Parameter()]
        [switch]$WhatIf
    )
    
    # Manual validation
    if ($FixOnly.Count -gt 0 -and $DontFix.Count -gt 0) {
        throw "Cannot specify both -FixOnly and -DontFix parameters. Use one or the other."
    }
    
    # Determine which tags to fix
    $tagsToFix = if ($FixOnly.Count -gt 0) {
        Write-Host "FixOnly mode: $($FixOnly -join ', ')"
        $FixOnly
    } elseif ($DontFix.Count -gt 0) {
        Write-Host "DontFix mode: $($DontFix -join ', ')"
        @('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists') | Where-Object { $_ -notin $DontFix }
    } else {
        Write-Host "Default mode: Fix everything"
        @('Titles', 'TrackNumbers', 'Years', 'Genres', 'Artists')
    }
    
    Write-Host "Tags to fix: $($tagsToFix -join ', ')"
}

# Test cases
Write-Host "`n--- Parameter Set Tests ---" -ForegroundColor Yellow

try {
    Write-Host "`n1. FixOnly test:"
    Test-ParameterSets -Path "test" -FixOnly Titles,Genres
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n2. DontFix test:"
    Test-ParameterSets -Path "test" -DontFix Years,Artists
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n3. Default test:"
    Test-ParameterSets -Path "test"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n4. Both parameters test (should fail with parameter sets):"
    Test-ParameterSets -Path "test" -FixOnly Titles -DontFix Years
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n--- Manual Validation Tests ---" -ForegroundColor Yellow

try {
    Write-Host "`n1. FixOnly test:"
    Test-ManualValidation -Path "test" -FixOnly Titles,Genres
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n2. DontFix test:"
    Test-ManualValidation -Path "test" -DontFix Years,Artists
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n3. Default test:"
    Test-ManualValidation -Path "test"
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "`n4. Both parameters test (should fail with manual validation):"
    Test-ManualValidation -Path "test" -FixOnly Titles -DontFix Years
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Analysis ===" -ForegroundColor Cyan
Write-Host "Parameter Sets Pros:" -ForegroundColor Green
Write-Host "  ✓ Built-in PowerShell validation"
Write-Host "  ✓ Prevents invalid combinations at parse time"
Write-Host "  ✓ Better tab completion behavior"
Write-Host "  ✓ More PowerShell-idiomatic"

Write-Host "`nParameter Sets Cons:" -ForegroundColor Red
Write-Host "  ✗ Requires one of FixOnly/DontFix to be mandatory in their sets"
Write-Host "  ✗ Cannot have both optional (loses default behavior)"
Write-Host "  ✗ More complex parameter definitions"

Write-Host "`nManual Validation Pros:" -ForegroundColor Green
Write-Host "  ✓ Both parameters can be optional"
Write-Host "  ✓ Maintains default behavior when neither specified"
Write-Host "  ✓ Simple parameter definitions"
Write-Host "  ✓ Runtime flexibility"

Write-Host "`nManual Validation Cons:" -ForegroundColor Red
Write-Host "  ✗ Runtime validation (error comes later)"
Write-Host "  ✗ Custom validation code required"