function Test-TagLibLoaded {
    <#
    .SYNOPSIS
        Ensure TagLib-Sharp is loaded into the current session.

    .DESCRIPTION
        Checks whether TagLib is already available. If not, searches several sensible
        locations (module lib folder relative to this file, installed module base,
        PSModulePath, and the NuGet cache) for TagLib.dll and tries to load it.
        Returns $true when TagLib is available, $false otherwise (or throws when -ThrowOnError).
    .PARAMETER ThrowOnError
        Throw a terminating error if TagLib cannot be found or loaded.
    #>
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )

    begin {
        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }

    process {
        try {
            # Quick type check
            try {
                if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                    Write-Verbose "TagLib.File type already available in session."
                    return $true
                }
            } catch {
                # ignore and continue
                Write-Verbose "Type-level check threw: $($_.Exception.Message)"
            }

            # 1) Try to determine module root from the script file that defines this function
            $invPath = $MyInvocation.MyCommand.Path
            if (-not $invPath) {
                # fallback to PSScriptRoot if available
                $invPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot '' } else { $null }
            }

            if ($invPath) {
                # If script is in ...\Private\<file>, go up one level to module root
                $privateDir = Split-Path -Parent $invPath
                if ($privateDir) {
                    $moduleRootFromScript = Split-Path -Parent $privateDir
                    if ($moduleRootFromScript) {
                        $libPath = Join-Path $moduleRootFromScript 'lib\TagLib.dll'
                        if (Test-Path -LiteralPath $libPath) {
                            Write-Verbose "Found TagLib at module lib: $libPath"
                            try {
                                Add-Type -Path $libPath -ErrorAction Stop
                                if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                                    Write-Verbose "TagLib loaded successfully from module lib"
                                    return $true
                                }
                            } catch {
                                Write-Verbose "Failed to load from module lib: $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }

            # 2) Try Get-Module to find installed module base
            Write-Verbose "Trying Get-Module fallback..."
            try {
                $mod = Get-Module -Name MuFo -ListAvailable | Select-Object -First 1
                if ($mod) {
                    $modLib = Join-Path $mod.ModuleBase 'lib\TagLib.dll'
                    if (Test-Path -LiteralPath $modLib) {
                        Write-Verbose "Found TagLib at installed module: $modLib"
                        try {
                            Add-Type -Path $modLib -ErrorAction Stop
                            if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                                Write-Verbose "TagLib loaded successfully from installed module"
                                return $true
                            }
                        } catch {
                            Write-Verbose "Failed to load from installed module: $($_.Exception.Message)"
                        }
                    }
                }
            } catch {
                Write-Verbose "Get-Module check failed: $($_.Exception.Message)"
            }

            # 3) Try PSModulePath (common locations)
            Write-Verbose "Trying PSModulePath fallback..."
            foreach ($p in ($env:PSModulePath -split ';' | Where-Object { $_ -and (Test-Path $_) })) {
                $maybe = Join-Path $p 'MuFo\lib\TagLib.dll'
                if (Test-Path -LiteralPath $maybe) {
                    Write-Verbose "Found TagLib in PSModulePath: $maybe"
                    try {
                        Add-Type -Path $maybe -ErrorAction Stop
                        if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                            Write-Verbose "TagLib loaded successfully from PSModulePath"
                            return $true
                        }
                    } catch {
                        Write-Verbose "Failed to load from PSModulePath: $($_.Exception.Message)"
                    }
                }
            }

            # 4) NuGet packages cache fallback
            Write-Verbose "Trying NuGet cache fallback..."
            try {
                $nugetRoot = Join-Path $env:USERPROFILE '.nuget\packages'
                if (Test-Path -LiteralPath $nugetRoot) {
                    $found = Get-ChildItem -Path $nugetRoot -Filter 'TagLib.dll' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        Write-Verbose "Found TagLib in NuGet cache: $($found.FullName)"
                        try {
                            Add-Type -Path $found.FullName -ErrorAction Stop
                            if ([System.Type]::GetType('TagLib.File, TagLib', $false, $false)) {
                                Write-Verbose "TagLib loaded successfully from NuGet cache"
                                return $true
                            }
                        } catch {
                            Write-Verbose "Failed to load from NuGet cache: $($_.Exception.Message)"
                        }
                    }
                }
            } catch {
                Write-Verbose "NuGet search failed: $($_.Exception.Message)"
            }

            $finalMsg = "Failed to load TagLib.dll from any location (module lib, installed module, PSModulePath, NuGet cache)."
            Write-Verbose $finalMsg
            if ($ThrowOnError) { throw $finalMsg } else { return $false }
        } finally {
            $ErrorActionPreference = $savedEAP
        }
    } # process
}