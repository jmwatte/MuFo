function Install-TagLibLoaded {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ThrowOnMissing
    )

    # Quick check: is TagLib already loaded?
    $loaded = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'TagLib' }
    if ($loaded) { return $true }

    # Compute module root reliably
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

    # Candidate DLL names (in case of different naming)
    $candidates = @(
        Join-Path $moduleRoot 'lib\TagLib.dll',
        Join-Path $moduleRoot 'lib\TagLibSharp.dll'
    ) | Where-Object { Test-Path $_ }

    if ($candidates.Count -gt 0) {
        foreach ($dll in $candidates) {
            try {
                Add-Type -Path $dll -ErrorAction Stop
                # verify
                if ([type]::GetType('TagLib.File, TagLib')) { return $true }
            }
            catch {
                Write-Verbose "Failed to load TagLib from $($dll): $_"
            }
        }
    }

    # Last-ditch: try to resolve the TagLib type (GAC / already installed package)
    if ([type]::GetType('TagLib.File, TagLib')) { return $true }

    if ($ThrowOnMissing) {
        throw "TagLib assembly not found or failed to load. Look for TagLib.dll under the module's lib folder or run Install-TagLibSharp."
    }

    return $false
}