# MuFo.psm1
# Root module file for the MuFo PowerShell module.
# Temporarily add this line in MuFo.psm1 while troubleshooting:
# Replace the loops temporarily while diagnosing


# Load Public functions
Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 | ForEach-Object {
    #Write-host $_.FullName
    try { . $_.FullName } catch { Write-Error "Failed to load Public/$($_.Name): $($_.Exception.Message)" }
}

# Load Private functions
Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 | ForEach-Object {
   try { Write-Verbose $_.FullName; . $_.FullName ;  } catch { Write-Error "Failed to load Private/$($_.Name): $($_.Exception.Message)" }
   # Write-Verbose $_.FullName
}

# Export public functions (if any are defined)
# Functions are exported via the manifest, but you can also export here if needed.
# Export-ModuleMember -Function Invoke-MuFo