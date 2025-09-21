function Get-AudioFileTags {
<#
.SYNOPSIS
    Reads audio file tags using TagLib-Sharp and returns normalized tag information.

.DESCRIPTION
    This function scans a folder or processes individual audio files to extract metadata
    using TagLib-Sharp. It returns a normalized object with common tag fields.

.PARAMETER Path
    The path to a folder containing audio files or a single audio file.

.OUTPUTS
    Array of PSCustomObject with fields: Path, FileName, Artist, Album, Title, Track, Disc, Year, Duration

.NOTES
    Requires TagLib-Sharp assembly to be loaded.
    Supported formats: .mp3, .flac, .m4a, .ogg, .wav (where supported by TagLib)
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    begin {
        # Supported audio file extensions
        $supportedExtensions = @('.mp3', '.flac', '.m4a', '.ogg', '.wav')

        # Load TagLib-Sharp if not already loaded
        if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like '*TagLib*' })) {
            try {
                # Assume TagLib-Sharp.dll is in the module root or a standard location
                $tagLibPath = Join-Path $PSScriptRoot '..\TagLib-Sharp.dll'
                if (-not (Test-Path $tagLibPath)) {
                    # Try to find it in common locations or throw
                    throw "TagLib-Sharp.dll not found at $tagLibPath. Please install TagLib-Sharp and ensure the DLL is available."
                }
                Add-Type -Path $tagLibPath
                Write-Verbose "Loaded TagLib-Sharp from $tagLibPath"
            } catch {
                Write-Warning "Failed to load TagLib-Sharp: $($_.Exception.Message)"
                return @()
            }
        }
    }

    process {
        $results = @()

        # Determine if Path is a file or folder
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $files = @($Path)
        } elseif (Test-Path -LiteralPath $Path -PathType Container) {
            $files = Get-ChildItem -LiteralPath $Path -File | Where-Object { $_.Extension -in $supportedExtensions } | Select-Object -ExpandProperty FullName
        } else {
            Write-Warning "Path '$Path' does not exist or is not accessible."
            return @()
        }

        foreach ($file in $files) {
            try {
                $fileObj = [TagLib.File]::Create($file)
                $tag = $fileObj.Tag
                $properties = $fileObj.Properties

                # Normalize the tag data
                $normalizedTag = [PSCustomObject]@{
                    Path     = $file
                    FileName = [System.IO.Path]::GetFileName($file)
                    Artist   = if ($tag -and $tag.Performers -and $tag.Performers.Length -gt 0) { $tag.Performers[0] } else { $null }
                    Album    = if ($tag -and $tag.Album) { $tag.Album } else { $null }
                    Title    = if ($tag -and $tag.Title) { $tag.Title } else { $null }
                    Track    = if ($tag -and $tag.Track) { $tag.Track } else { $null }
                    Disc     = if ($tag -and $tag.Disc) { $tag.Disc } else { $null }
                    Year     = if ($tag -and $tag.Year) { $tag.Year } else { $null }
                    Duration = if ($properties -and $properties.Duration) { $properties.Duration.TotalSeconds } else { $null }
                }

                $results += $normalizedTag
            } catch {
                Write-Warning "Failed to read tags from '$file': $($_.Exception.Message)"
            }
        }

        return $results
    }
}