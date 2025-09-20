# MuFo.psm1
# Root module file for the MuFo PowerShell module.

# Load Public functions
Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Load Private functions
Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Export public functions (if any are defined)
# Functions are exported via the manifest, but you can also export here if needed.
# Export-ModuleMember -Function Invoke-MuFo